import 'dart:async';

import 'package:logging/logging.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/stt/stt_session_manager.dart';
import 'package:zip_core/src/services/wake_lock/wake_lock_service.dart';

part 'recording_state_notifier.g.dart';

const _uuid = Uuid();

/// Recording state machine (BR-01, BR-02, BR-03).
///
/// Integrates [SttSessionManager] for engine lifecycle and [WakeLockService]
/// to keep the screen on during captioning. Handles the one-attempt
/// auto-restart recovery flow (REL-U2.1) via the `reconnecting` state.
///
/// Invalid transitions are silently ignored (no exception, no error).
/// This prevents UI race conditions (e.g., user double-taps a button).
///
/// **Security (SR-01)**: No method may log, emit, or surface any text
/// content from speech recognition results. State transitions may be
/// logged at debug level; segment text may not appear in any log output.
@Riverpod(keepAlive: true)
class RecordingStateNotifier extends _$RecordingStateNotifier {
  static final _log = Logger('zip_core.RecordingStateNotifier');

  late final CaptionBus _captionBus;
  late final SttSessionManager _sessionManager;
  late final WakeLockService _wakeLockService;
  RecordingError? _lastError;
  bool _hasAttemptedRestart = false;

  /// The most recent error, if any.
  ///
  /// Cleared on successful [start] or [clearSession].
  RecordingError? get lastError => _lastError;

  @override
  RecordingState build() {
    _captionBus = ref.read(captionBusProvider);
    _sessionManager = ref.read(sttSessionManagerProvider);
    _wakeLockService = ref.read(wakeLockServiceProvider);
    return const RecordingState.idle();
  }

  /// Transitions idle -> recording.
  ///
  /// Resolves the engine, checks microphone permission, initializes STT,
  /// starts listening, and acquires the wake lock.
  Future<void> start({String? localeId}) async {
    if (state is! IdleState) return;
    _lastError = null;
    _hasAttemptedRestart = false;

    final engine = ref.read(sttEngineProvider);
    if (engine == null) {
      _log.warning('No STT engine available');
      _lastError = RecordingErrorFactories.engineInitFailed();
      return;
    }

    // Explicit type required: inference widens to String? because localeId is
    // String?, even though the ?? rhs is non-nullable String.
    // ignore: omit_local_variable_types
    final String resolvedLocale =
        localeId ?? ref.read(resolvedLocaleIdProvider);
    final sessionId = _uuid.v4();

    final initOk = await _sessionManager.initialize(
      engineId: engine.engineId,
      localeId: resolvedLocale,
      onResult: _handleSttResult,
      onError: _handleEngineError,
    );

    if (!initOk) {
      _log.warning('Session initialization failed');
      return;
    }

    final listenOk = await _sessionManager.startListening();
    if (!listenOk) {
      _log.warning('Engine failed to start listening');
      return;
    }

    _log.info('Session started: $sessionId');
    state = RecordingState.recording(sessionId: sessionId);
    _captionBus.publish(SessionStateEvent(state));
    await _wakeLockService.acquire();
  }

  /// Transitions recording -> paused (BR-02).
  ///
  /// Pauses the STT engine and conditionally releases the wake lock.
  Future<void> pause() async {
    final current = state;
    if (current is! RecordingActiveState) return;
    await _sessionManager.pause();
    _log.info('Session paused');
    state = RecordingState.paused(
      sessionId: current.sessionId,
      currentSegment: current.currentSegment,
    );
    _captionBus.publish(SessionStateEvent(state));
    await _wakeLockService.onPause();
  }

  /// Transitions paused -> recording (BR-02).
  ///
  /// Resumes the STT engine and re-acquires the wake lock.
  Future<void> resume() async {
    final current = state;
    if (current is! PausedState) return;
    final ok = await _sessionManager.resume();
    if (!ok) {
      _log.warning('Engine failed to resume');
      return;
    }
    _log.info('Session resumed');
    state = RecordingState.recording(
      sessionId: current.sessionId,
    );
    _captionBus.publish(SessionStateEvent(state));
    await _wakeLockService.acquire();
  }

  /// Transitions recording|paused -> stopped.
  ///
  /// Stops the STT engine and releases the wake lock.
  Future<void> stop() async {
    final current = state;
    final String sessionId;
    if (current is RecordingActiveState) {
      sessionId = current.sessionId;
    } else if (current is PausedState) {
      sessionId = current.sessionId;
    } else {
      return;
    }
    await _sessionManager.stop();
    _log.info('Session stopped');
    state = RecordingState.stopped(
      sessionId: sessionId,
    );
    _captionBus.publish(SessionStateEvent(state));
    await _wakeLockService.release();
  }

  /// Transitions stopped -> idle; clears accumulated data.
  void clearSession() {
    if (state is! StoppedState) return;
    _lastError = null;
    _log.info('Session cleared');
    state = const RecordingState.idle();
  }

  /// Opens the platform microphone settings page.
  ///
  /// Useful when microphone permission is permanently denied.
  Future<void> openMicrophoneSettings() async {
    await openAppSettings();
  }

  /// Handle an STT result from the active engine.
  ///
  /// Updates `currentSegment` on the current state and publishes
  /// an `SttResultEvent` to the bus.
  ///
  /// **Security (SECURITY-03)**: Must never log result.text.
  void _handleSttResult(SttResult result) {
    final current = state;
    if (current is! RecordingActiveState) return;

    if (result.isFinal) {
      state = RecordingActiveState(
        sessionId: current.sessionId,
      );
    } else {
      state = RecordingActiveState(
        sessionId: current.sessionId,
        currentSegment: result.text,
      );
    }

    _captionBus.publish(SttResultEvent(result));
  }

  /// One-attempt auto-restart on engine error (REL-U2.1).
  ///
  /// Transitions to `reconnecting`, attempts restart, then either resumes
  /// `recording` or transitions to `stopped` on failure.
  void _handleEngineError(RecordingError error) {
    final current = state;
    final active =
        current is ActiveSessionState ? current as ActiveSessionState : null;
    if (active == null) return;

    _lastError = error;

    if (_hasAttemptedRestart) {
      _log.warning('Engine error after restart attempt — stopping');
      state = RecordingState.stopped(sessionId: active.sessionId);
      _captionBus.publish(SessionStateEvent(state));
      unawaited(_wakeLockService.release());
      return;
    }

    _hasAttemptedRestart = true;
    _log.info('Engine error — attempting restart');
    state = RecordingState.reconnecting(
      sessionId: active.sessionId,
      currentSegment: active.currentSegment,
    );
    _captionBus.publish(SessionStateEvent(state));

    unawaited(
      _sessionManager.handleEngineError(error).then((recovered) {
        if (recovered) {
          _log.info('Engine restart succeeded');
          _lastError = null;
          state = RecordingState.recording(
            sessionId: active.sessionId,
          );
          _captionBus.publish(SessionStateEvent(state));
        } else {
          _log.warning('Engine restart failed — stopping');
          state = RecordingState.stopped(sessionId: active.sessionId);
          _captionBus.publish(SessionStateEvent(state));
          unawaited(_wakeLockService.release());
        }
      }),
    );
  }
}
