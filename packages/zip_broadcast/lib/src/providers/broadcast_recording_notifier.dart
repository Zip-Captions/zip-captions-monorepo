import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/stt_engine_factory_provider.dart';
import 'package:zip_core/zip_core.dart' hide AudioInputConfig, AudioInputVisualStyle;

part 'broadcast_recording_notifier.g.dart';

const _uuid = Uuid();

class _EngineSession {
  _EngineSession({required this.deviceId, required this.engine});
  final String deviceId;
  final SttEngine engine;
}

/// Multi-engine recording state machine for Zip Broadcast (Q1=A, FD B2).
///
/// Starts one [SttEngine] per configured [AudioInputConfig]. Tags each
/// [SttResult] with the config's [AudioInputConfig.deviceId] before
/// publishing to [CaptionBus] (sourceId tagging).
///
/// Partial failure: if some engines fail to initialise, recording continues
/// with the engines that succeeded (REL-U6.1, P1–P3). If all fail, transitions
/// to [BroadcastIdleState] with a non-null [BroadcastIdleState.lastError].
@Riverpod(keepAlive: true)
class BroadcastRecordingNotifier extends _$BroadcastRecordingNotifier {
  static final _log = Logger('zip_broadcast.BroadcastRecordingNotifier');

  final List<_EngineSession> _sessions = [];
  CaptionBus? _captionBus;
  WakeLockService? _wakeLockService;
  bool _starting = false;

  @override
  BroadcastSessionState build() {
    _captionBus = ref.read(captionBusProvider);
    _wakeLockService = ref.read(wakeLockServiceProvider);
    ref.onDispose(_cleanup);
    return const BroadcastIdleState();
  }

  /// Starts one engine per configured [AudioInputConfig].
  ///
  /// Uses [resolvedLocaleIdProvider] for the recognition locale.
  /// Invalid to call when not in [BroadcastIdleState].
  Future<void> start() async {
    if (state is! BroadcastIdleState || _starting) return;
    _starting = true;
    try {
      final configs = ref.read(audioInputConfigNotifierProvider);
      if (configs.isEmpty) {
        state = const BroadcastIdleState(
          lastError: 'No audio inputs configured',
        );
        return;
      }

      final localeId = ref.read(resolvedLocaleIdProvider);
      final sessionId = _uuid.v4();

      final perEngineStates = <String, EngineSessionState>{};

      await Future.wait(
        configs.map((config) async {
          final engine = ref.read(sttEngineFactoryProvider(config.deviceId));
          final session =
              _EngineSession(deviceId: config.deviceId, engine: engine);
          _sessions.add(session);

          final initOk = await engine.initialize();
          if (!initOk) {
            _log.warning('Engine init failed for ${config.deviceId}');
            perEngineStates[config.deviceId] =
                const EngineErrorState('Initialisation failed');
            _sessions.remove(session);
            session.engine.dispose();
            return;
          }

          final listenOk = await engine.startListening(
            localeId: localeId,
            onResult: (result) => _handleResult(result, config),
          );

          perEngineStates[config.deviceId] = listenOk
              ? const EngineActiveState()
              : const EngineErrorState('Failed to start listening');
          if (!listenOk) {
            _log.warning(
              'Engine startListening failed for ${config.deviceId}',
            );
            _sessions.remove(session);
            session.engine.dispose();
          }
        }),
      );

      final anyActive = perEngineStates.values.any((s) => s.isActive);
      if (!anyActive) {
        _log.warning('All engines failed — staying idle');
        state = const BroadcastIdleState(lastError: 'All engines failed');
        _disposeEngines();
        return;
      }

      _log.info('Session started: $sessionId');
      state = BroadcastActiveState(
        sessionId: sessionId,
        perEngineStates: Map.unmodifiable(perEngineStates),
      );
      _captionBus!.publish(
        SessionStateEvent(RecordingState.recording(sessionId: sessionId)),
      );
      await _wakeLockService!.acquire();
    } finally {
      _starting = false;
    }
  }

  /// Transitions active → paused.
  Future<void> pause() async {
    final current = state;
    if (current is! BroadcastActiveState) return;
    for (final s in _sessions) {
      await s.engine.pause();
    }
    _log.info('Session paused');
    state = BroadcastPausedState(
      sessionId: current.sessionId,
      perEngineStates: current.perEngineStates,
    );
    _captionBus!.publish(
      SessionStateEvent(
        RecordingState.paused(sessionId: current.sessionId),
      ),
    );
    await _wakeLockService!.onPause();
  }

  /// Transitions paused → active.
  Future<void> resume() async {
    final current = state;
    if (current is! BroadcastPausedState) return;

    final localeId = ref.read(resolvedLocaleIdProvider);
    final configs = ref.read(audioInputConfigNotifierProvider);
    final configMap = {for (final c in configs) c.deviceId: c};

    final perEngineStates = <String, EngineSessionState>{
      ...current.perEngineStates,
    };

    final orphaned = <_EngineSession>[];
    for (final s in _sessions) {
      final config = configMap[s.deviceId];
      if (config == null) {
        orphaned.add(s);
        perEngineStates.remove(s.deviceId);
        continue;
      }
      final ok = await s.engine.resume();
      if (!ok) {
        // Fall back to a fresh startListening.
        final restarted = await s.engine.startListening(
          localeId: localeId,
          onResult: (r) => _handleResult(r, config),
        );
        perEngineStates[s.deviceId] = restarted
            ? const EngineActiveState()
            : const EngineErrorState('Resume failed');
      } else {
        perEngineStates[s.deviceId] = const EngineActiveState();
      }
    }

    for (final s in orphaned) {
      s.engine.dispose();
      _sessions.remove(s);
    }

    _log.info('Session resumed');
    state = BroadcastActiveState(
      sessionId: current.sessionId,
      perEngineStates: Map.unmodifiable(perEngineStates),
    );
    _captionBus!.publish(
      SessionStateEvent(
        RecordingState.recording(sessionId: current.sessionId),
      ),
    );
    await _wakeLockService!.acquire();
  }

  /// Transitions any active state → stopped.
  Future<void> stop() async {
    final sessionId = switch (state) {
      BroadcastActiveState(:final sessionId) => sessionId,
      BroadcastPausedState(:final sessionId) => sessionId,
      BroadcastReconnectingState(:final sessionId) => sessionId,
      _ => null,
    };
    if (sessionId == null) return;

    await _stopEngines();
    _log.info('Session stopped: $sessionId');
    state = BroadcastStoppedState(sessionId: sessionId);
    _captionBus!.publish(
      SessionStateEvent(RecordingState.stopped(sessionId: sessionId)),
    );
    await _wakeLockService!.release();
  }

  /// Transitions stopped → idle; clears session data.
  void clearSession() {
    if (state is! BroadcastStoppedState) return;
    state = const BroadcastIdleState();
    _log.info('Session cleared');
  }

  // ---------------------------------------------------------------------------
  // Private
  // ---------------------------------------------------------------------------

  void _handleResult(SttResult raw, AudioInputConfig config) {
    if (state is! BroadcastActiveState) return;
    final tagged = raw.copyWith(sourceId: config.deviceId);
    _captionBus!.publish(SttResultEvent(tagged));
  }

  Future<void> _stopEngines() async {
    for (final s in _sessions) {
      try {
        await s.engine.stopListening();
      } on Object catch (e) {
        _log.warning(
          'stopListening error for ${s.deviceId}: ${e.runtimeType}',
        );
      }
    }
    _disposeEngines();
  }

  void _disposeEngines() {
    for (final s in _sessions) {
      s.engine.dispose();
    }
    _sessions.clear();
  }

  void _cleanup() => _disposeEngines();
}
