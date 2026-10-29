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
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/session_stop_reason_provider.dart';
import 'package:zip_core/src/providers/speech_inactivity_timeout_provider.dart';
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

  /// While `start()` or `resume()` is running: the first error the session
  /// manager reported meanwhile (first error wins, BR-U10-28 and BR-U10-36).
  RecordingError? _captured;
  bool _capturing = false;

  /// Set synchronously by the first call to [_finishSession]; every later
  /// caller shares it, so a session is finalised and stopped exactly once
  /// (BR-U10-35). Reset by `start()` and `clearSession()`.
  Future<void>? _finishing;

  /// Set synchronously by the first `start()` that gets past the idle guard;
  /// every later caller shares it, so two starts cannot overlap (Q-1). Cleared
  /// when the run completes, whichever way it ends.
  Future<void>? _starting;

  /// The same single-flight window for `resume()` (Q-1): two taps on the same
  /// frame must not resume the engine twice.
  Future<void>? _resuming;

  /// The inactivity timer (BR-U10-51): non-null exactly while it is armed, that
  /// is, from entering recording until a pause or the session finishing. Every
  /// recognition result re-arms it.
  Timer? _inactivityTimer;

  /// The most recent error, if any.
  ///
  /// Cleared on successful [start] or [clearSession].
  RecordingError? get lastError => _lastError;

  @override
  RecordingState build() {
    _captionBus = ref.read(captionBusProvider);
    _sessionManager = ref.read(sttSessionManagerProvider);
    _wakeLockService = ref.read(wakeLockServiceProvider);
    ref.onDispose(_cancelInactivityTimer);
    return const RecordingState.idle();
  }

  /// Arms (or re-arms) the inactivity timer for [sessionId] with the timeout
  /// in force (BR-U10-51, BR-U10-52).
  void _armInactivityTimer(String sessionId) {
    _inactivityTimer?.cancel();
    final timeout = ref.read(speechInactivityTimeoutProvider);
    _inactivityTimer = Timer(timeout, () => _onInactivity(sessionId, timeout));
  }

  void _cancelInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// The timer fired: stop exactly as the user's Stop does, through the
  /// single-flight [_finishSession], unless a stop already began (BR-U10-35).
  ///
  /// Logs the reason and the timeout in seconds only (SECURITY-03).
  void _onInactivity(String sessionId, Duration timeout) {
    _inactivityTimer = null;
    if (_finishing != null) return;
    final current = state;
    if (current is! RecordingActiveState && current is! ReconnectingState) {
      return;
    }
    _log.info(
      'Session stopping: ${SessionStopReason.inactivity.name} '
      'after ${timeout.inSeconds}s without speech',
    );
    // Not an error (BR-U10-51): a reconnecting session's engine error is spent.
    _lastError = null;
    ref.read(sessionStopReasonNotifierProvider.notifier).reason =
        SessionStopReason.inactivity;
    unawaited(_finishSession(sessionId));
  }

  /// Transitions idle -> recording.
  ///
  /// Resolves the engine, checks microphone permission, initializes STT,
  /// starts listening, and acquires the wake lock.
  ///
  /// **Single-flight (Q-1):** a call made while another is still running
  /// returns that run's future and does nothing of its own. The `IdleState`
  /// guard alone is not enough: the state stays idle until the run succeeds,
  /// so two calls in one frame (the screen and the explainer gate, or a second
  /// tap) would both run, share `_captured`/`_capturing`, and the losing call's
  /// failure path would stop the winning session.
  ///
  /// Every failure leaves the state at [IdleState] with its error in
  /// [lastError] (Unit 10, TP-1): the first error reported while this method
  /// runs wins (BR-U10-28), and a failure that cannot be attributed falls
  /// back to the generic error for its stage. An engine error captured after
  /// `startListening` returned `true` stops the session manager and also
  /// leaves the state at [IdleState] (BR-U10-25), because the engine has
  /// already given up.
  Future<void> start({String? localeId}) {
    if (state is! IdleState) return Future<void>.value();
    final inFlight = _starting;
    if (inFlight != null) return inFlight;

    final run = _runStart(localeId);
    _starting = run;
    return run;
  }

  /// The body of `start()`, run once per single-flight window.
  Future<void> _runStart(String? localeId) async {
    try {
      await _startSession(localeId);
    } finally {
      _starting = null;
    }
  }

  Future<void> _startSession(String? localeId) async {
    _lastError = null;
    _hasAttemptedRestart = false;
    _finishing = null;
    _cancelInactivityTimer();
    ref.read(sessionStopReasonNotifierProvider.notifier).clear();

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

    _captured = null;
    _capturing = true;
    var initialized = false;
    try {
      final initOk = await _sessionManager.initialize(
        engineId: engine.engineId,
        localeId: resolvedLocale,
        onResult: _handleSttResult,
        onError: _onSessionError,
      );

      if (!initOk) {
        _log.warning('Session initialization failed');
        _lastError = _captured ?? RecordingErrorFactories.engineInitFailed();
        return;
      }
      initialized = true;

      final listenOk = await _sessionManager.startListening();
      if (!listenOk) {
        _lastError = _captured ?? RecordingErrorFactories.engineStartFailed();
        await _stopManagerQuietly();
        _log.warning('Engine failed to start listening');
        return;
      }

      if (_captured != null) {
        // BR-U10-25: the engine reported a lasting error while start() was
        // still running. It is spent, so do not enter Recording.
        _lastError = _captured;
        await _stopManagerQuietly();
        _log.warning('Engine reported an error during start');
        return;
      }

      // From here a reported error is an ordinary mid-session engine error.
      _capturing = false;
      _log.info('Session started: $sessionId');
      state = RecordingState.recording(sessionId: sessionId);
      _armInactivityTimer(sessionId);
      _captionBus.publish(SessionStateEvent(state));
      await _wakeLockService.acquire();
    } on Object catch (e) {
      // SECURITY-15: fail closed. Never log the exception itself.
      _log.severe('Start failed: ${e.runtimeType}');
      if (state is IdleState) {
        _lastError =
            _captured ??
            (initialized
                ? RecordingErrorFactories.engineStartFailed()
                : RecordingErrorFactories.engineInitFailed());
        await _stopManagerQuietly();
      }
    } finally {
      _capturing = false;
    }
  }

  /// The `onError` handed to the session manager. While `start()` or
  /// `resume()` is running it keeps the first error; otherwise it is an
  /// ordinary mid-session engine error.
  void _onSessionError(RecordingError error) {
    if (_capturing) {
      _captured ??= error;
      return;
    }
    _handleEngineError(error);
  }

  Future<void> _stopManagerQuietly() async {
    try {
      await _sessionManager.stop();
    } on Object catch (e) {
      _log.warning('Error stopping the session manager: ${e.runtimeType}');
    }
  }

  /// Transitions recording -> paused (BR-02).
  ///
  /// Pauses the STT engine and conditionally releases the wake lock.
  Future<void> pause() async {
    final current = state;
    if (current is! RecordingActiveState) return;
    // Paused time does not count (BR-U10-51); cancelled again below, because a
    // result may land while the engine pauses.
    _cancelInactivityTimer();
    await _sessionManager.pause();
    _log.info('Session paused');
    state = RecordingState.paused(
      sessionId: current.sessionId,
      currentSegment: current.currentSegment,
    );
    _cancelInactivityTimer();
    _captionBus.publish(SessionStateEvent(state));
    await _wakeLockService.onPause();
  }

  /// Transitions paused -> recording (BR-02).
  ///
  /// Resumes the STT engine and re-acquires the wake lock.
  ///
  /// A resume the engine refuses with an error (for example the on-device
  /// check) stops the session, finalised once, and leaves the error in
  /// [lastError] (BR-U10-36); otherwise the user would stay in [PausedState]
  /// with the same silent result on every tap. A resume that fails without an
  /// error behaves as before: it is logged and the session stays paused.
  ///
  /// **Single-flight (Q-1):** like `start()`, a call made while another is
  /// still running returns that run's future, so two taps resume once.
  Future<void> resume() {
    final current = state;
    if (current is! PausedState) return Future<void>.value();
    final inFlight = _resuming;
    if (inFlight != null) return inFlight;

    final run = _runResume(current);
    _resuming = run;
    return run;
  }

  Future<void> _runResume(PausedState current) async {
    try {
      await _resumeSession(current);
    } finally {
      _resuming = null;
    }
  }

  Future<void> _resumeSession(PausedState current) async {
    _captured = null;
    _capturing = true;
    try {
      final ok = await _sessionManager.resume();
      // BR-U10-35, TP-2c: a stop that landed while the engine was resuming
      // has already finalised the session. The resume then started the engine
      // again, so stop it once more and change nothing else.
      if (_finishing != null) {
        await _stopManagerQuietly();
        return;
      }
      if (!ok || _captured != null) {
        final reported = _captured;
        _capturing = false;
        if (reported != null) {
          _log.warning('Engine refused to resume; stopping the session');
          _lastError = reported;
          await _finishSession(current.sessionId);
        } else {
          _log.warning('Engine failed to resume');
        }
        return;
      }
      _capturing = false;
      _log.info('Session resumed');
      state = RecordingState.recording(
        sessionId: current.sessionId,
        currentSegment: current.currentSegment,
      );
      _armInactivityTimer(current.sessionId);
      _captionBus.publish(SessionStateEvent(state));
      await _wakeLockService.acquire();
    } finally {
      _capturing = false;
    }
  }

  /// Transitions recording|paused|reconnecting -> stopped.
  ///
  /// Stops the STT engine, awaits transcript finalization, then releases
  /// the wake lock. Finalization is awaited before [StoppedState] is
  /// published so that the History screen sees correct counts on navigation.
  Future<void> stop() async {
    final current = state;
    final String sessionId;
    if (current is RecordingActiveState) {
      sessionId = current.sessionId;
    } else if (current is PausedState) {
      sessionId = current.sessionId;
    } else if (current is ReconnectingState) {
      sessionId = current.sessionId;
    } else {
      return;
    }
    // Called synchronously, before any await, so `_finishing` is set before
    // the REL-U2.1 recovery can look at it (BR-U10-35, TP-2c).
    await _finishSession(sessionId);
  }

  /// Finalises the transcript, moves to [StoppedState], publishes the
  /// event and releases the wake lock, **once per session** (BR-U10-35).
  ///
  /// The first caller starts the routine and every later caller (engine
  /// error, recovery failure or exception, a refused resume, the user's
  /// stop) shares its future, so a Stop tap during an in-flight finalise
  /// awaits it instead of racing it. The first step, for every caller, is to
  /// stop the session manager, so the engine is never left listening.
  Future<void> _finishSession(String sessionId) {
    final existing = _finishing;
    if (existing != null) return existing;

    final done = Completer<void>();
    _finishing = done.future;
    _cancelInactivityTimer();
    unawaited(
      _runFinish(sessionId).then(
        (_) => done.complete(),
        onError: done.completeError,
      ),
    );
    return done.future;
  }

  Future<void> _runFinish(String sessionId) async {
    await _sessionManager.stop();
    _log.info('Session stopped');
    try {
      await _finalizeTranscript();
    } on Object catch (e) {
      // A failing transcript finaliser must not strand the session: the user
      // sees Stopped, the event is published, the wake lock is released.
      // Only the exception's type is logged (SECURITY-03).
      _log.severe('Transcript finalisation failed: ${e.runtimeType}');
    } finally {
      state = RecordingState.stopped(
        sessionId: sessionId,
      );
      _captionBus.publish(SessionStateEvent(state));
      await _wakeLockService.release();
    }
  }

  /// Transitions stopped -> idle; clears accumulated data.
  void clearSession() {
    if (state is! StoppedState) return;
    _lastError = null;
    _finishing = null;
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
    // BR-U10-51: every result, interim or final, restarts the timer, while it
    // is armed (not paused, not finishing).
    final current = state;
    if (_inactivityTimer != null && _finishing == null) {
      if (current is RecordingActiveState) {
        _armInactivityTimer(current.sessionId);
      } else if (current is ReconnectingState) {
        _armInactivityTimer(current.sessionId);
      }
    }
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
  ///
  /// Only acts when in [RecordingActiveState] or [ReconnectingState].
  /// Engine errors during pause or after a user-initiated stop are ignored,
  /// and so is every error once the session is being finished (BR-U10-35).
  void _handleEngineError(RecordingError error) {
    if (_finishing != null) return;

    final current = state;
    final ActiveSessionState active;
    if (current is RecordingActiveState) {
      active = current;
    } else if (current is ReconnectingState) {
      active = current;
    } else {
      return;
    }

    _lastError = error;

    if (_hasAttemptedRestart) {
      _log.warning('Engine error after restart attempt — stopping');
      unawaited(_finishSession(active.sessionId));
      return;
    }

    _hasAttemptedRestart = true;
    _log.info('Engine error — attempting restart');
    state = RecordingState.reconnecting(
      sessionId: active.sessionId,
      currentSegment: active.currentSegment,
    );
    _captionBus.publish(SessionStateEvent(state));

    unawaited(() async {
      try {
        final recovered = await _sessionManager.handleEngineError(error);
        // Stop wins (BR-U10-35, TP-2c): if the session is already being
        // finished, the restart above may have started the engine after the
        // user's stop, so stop it again and change nothing else.
        if (_finishing != null) {
          await _stopManagerQuietly();
          return;
        }
        // Guard: if the user stopped or cleared the session while recovery
        // was in progress, do not overwrite the new state.
        if (state is! ReconnectingState) return;
        if (recovered) {
          _log.info('Engine restart succeeded');
          _lastError = null;
          state = RecordingState.recording(
            sessionId: active.sessionId,
          );
          _armInactivityTimer(active.sessionId);
          _captionBus.publish(SessionStateEvent(state));
        } else {
          _log.warning('Engine restart failed — stopping');
          await _finishSession(active.sessionId);
        }
      } on Object catch (e) {
        _log.severe('Unexpected error during recovery: ${e.runtimeType}');
        if (_finishing != null) {
          await _stopManagerQuietly();
          return;
        }
        if (state is! ReconnectingState) return;
        await _finishSession(active.sessionId);
      }
    }());
  }

  /// Calls the registered stop callback (transcript finalization) if present.
  ///
  /// Must be awaited before publishing [StoppedState] so the History screen
  /// sees accurate segment counts and duration on navigation.
  Future<void> _finalizeTranscript() async {
    final callback = ref.read(sessionStopCallbackProvider).callback;
    if (callback != null) await callback();
  }
}
