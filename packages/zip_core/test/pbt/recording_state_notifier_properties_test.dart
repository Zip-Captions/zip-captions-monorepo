import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';
import 'package:zip_core/src/services/stt/stt_session_manager.dart';
import 'package:zip_core/src/stt/stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_stt_session_manager.dart';
import '../helpers/mock_wake_lock_service.dart';
import '../helpers/pbt.dart' as pbt;

// TP-2c (Stop must win against the REL-U2.1 recovery) and TP-9 (lastError
// after failing and succeeding starts). The shim runs fixed seeds 0 to 99,
// has no shrinking and prints no seed; a failure message carries the
// scenario so it can be reproduced.

/// An engine whose operations take scripted time, so a user stop can land
/// before, during or after each await of the recovery.
class _ProbeEngine implements SttEngine, SttErrorSource {
  final calls = <String>[];
  bool listening = false;

  /// Outcomes and delays apply only once armed (after the first start).
  bool armed = false;
  int initDelayMs = 0;
  int listenDelayMs = 0;
  int stopDelayMs = 0;
  String initOutcome = 'ok';
  String listenOutcome = 'ok';

  void Function(SttEngineError)? _listener;

  @override
  String get engineId => 'probe';
  @override
  String get displayName => 'Probe';
  @override
  bool get requiresNetwork => false;
  @override
  bool get requiresDownload => false;
  @override
  bool get requiresMicrophone => false;

  @override
  void setErrorListener(void Function(SttEngineError error)? listener) {
    _listener = listener;
  }

  void emitError(SttEngineErrorKind kind) =>
      _listener?.call(SttEngineError(kind));

  Future<void> _wait(int ms) => ms == 0
      ? Future<void>.value()
      : Future<void>.delayed(Duration(milliseconds: ms));

  @override
  Future<bool> initialize() async {
    calls.add('initialize');
    if (armed) await _wait(initDelayMs);
    if (armed && initOutcome == 'throws') throw Exception('init threw');
    return !armed || initOutcome == 'ok';
  }

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    calls.add('startListening');
    if (armed) await _wait(listenDelayMs);
    if (armed && listenOutcome == 'throws') throw Exception('listen threw');
    final ok = !armed || listenOutcome == 'ok';
    if (ok) listening = true;
    return ok;
  }

  @override
  Future<void> stopListening() async {
    calls.add('stopListening');
    if (armed) await _wait(stopDelayMs);
    listening = false;
  }

  @override
  Future<bool> isAvailable() async => true;
  @override
  Future<List<SpeechLocale>> supportedLocales() async => const [];
  @override
  Future<bool> pause() async => true;
  @override
  Future<bool> resume() async => true;
  @override
  void dispose() {}
}

class _Scenario {
  _Scenario(Random r)
      : initDelay = r.nextInt(61),
        listenDelay = r.nextInt(61),
        stopDelay = r.nextInt(41),
        stopAt = const [0, 1, 5, 10, 20, 40, 80, 150, 300][r.nextInt(9)],
        initOutcome = const ['ok', 'false', 'throws'][r.nextInt(3)],
        listenOutcome = const ['ok', 'false', 'throws'][r.nextInt(3)],
        kind = SttEngineErrorKind.values[r.nextInt(5)];

  final int initDelay;
  final int listenDelay;
  final int stopDelay;
  final int stopAt;
  final String initOutcome;
  final String listenOutcome;
  final SttEngineErrorKind kind;

  @override
  String toString() => 'scenario(initDelay: $initDelay, listenDelay: '
      '$listenDelay, stopDelay: $stopDelay, stopAt: $stopAt, initOutcome: '
      '$initOutcome, listenOutcome: $listenOutcome, kind: ${kind.name})';
}

void main() {
  group('TP-2c: a user stop wins against the REL-U2.1 recovery', () {
    const pbt.Glados<_Scenario>(_scenarioGenerator).test(
      'for any interleaving: no engine listen after stop begins, the last '
      'engine call is stopListening, the state never re-enters recording, '
      'and the session is finalised once',
      (scenario) {
        fakeAsync((async) {
          final captionBus = CaptionBus();
          final registry = SttEngineRegistry();
          final engine = _ProbeEngine();
          registry.register(engine);
          final manager = SttSessionManager(registry: registry);
          final wakeLock = MockWakeLockService();
          when(wakeLock.acquire).thenAnswer((_) async {});
          when(wakeLock.release).thenAnswer((_) async {});
          when(wakeLock.onPause).thenAnswer((_) async {});
          when(() => wakeLock.settings).thenReturn(const WakeLockSettings());

          final container = ProviderContainer(
            overrides: [
              captionBusProvider.overrideWithValue(captionBus),
              sttSessionManagerProvider.overrideWithValue(manager),
              wakeLockServiceProvider.overrideWithValue(wakeLock),
              sttEngineProvider.overrideWithValue(engine),
              resolvedLocaleIdProvider.overrideWithValue('en-US'),
            ],
          );
          var finalizeCalls = 0;
          container.read(sessionStopCallbackProvider).callback = () async {
            finalizeCalls++;
            await Future<void>.delayed(const Duration(milliseconds: 20));
          };
          final states = <RecordingState>[];
          container.listen(
            recordingStateNotifierProvider,
            (_, next) => states.add(next),
          );
          final notifier =
              container.read(recordingStateNotifierProvider.notifier);
          RecordingState current() =>
              container.read(recordingStateNotifierProvider);

          unawaited(notifier.start());
          async
            ..flushMicrotasks()
            ..elapse(const Duration(milliseconds: 1));
          expect(current(), isA<RecordingActiveState>(), reason: '$scenario');

          // Arm the engine's scripted timing, then break the session.
          engine
            ..armed = true
            ..initDelayMs = scenario.initDelay
            ..listenDelayMs = scenario.listenDelay
            ..stopDelayMs = scenario.stopDelay
            ..initOutcome = scenario.initOutcome
            ..listenOutcome = scenario.listenOutcome
            ..emitError(scenario.kind);
          async
            ..flushMicrotasks()
            ..elapse(Duration(milliseconds: scenario.stopAt));

          final cur = current();
          final active = cur is RecordingActiveState ||
              cur is PausedState ||
              cur is ReconnectingState;
          final callMarker = engine.calls.length;
          final stateMarker = states.length;
          if (active) unawaited(notifier.stop());

          async
            ..flushMicrotasks()
            ..elapse(const Duration(seconds: 3))
            ..flushMicrotasks();

          final why = '$scenario, calls: ${engine.calls}, '
              'states after stop: ${states.skip(stateMarker).toList()}';
          if (active) {
            // (1) No engine listen() call began after stop() began.
            expect(
              engine.calls.skip(callMarker).where((c) => c == 'startListening'),
              isEmpty,
              reason: 'listen after stop began: $why',
            );
            // (2) The last engine call is stopListening.
            expect(engine.calls.last, 'stopListening', reason: why);
            // (3) The state never re-enters recording after stop began.
            expect(
              states.skip(stateMarker).where(
                    (s) => s is RecordingActiveState || s is ReconnectingState,
                  ),
              isEmpty,
              reason: why,
            );
            // And the engine is not left listening.
            expect(engine.listening, isFalse, reason: why);
          }
          expect(current(), isA<StoppedState>(), reason: why);
          // (4) Finalised exactly once.
          expect(finalizeCalls, 1, reason: why);

          container.dispose();
          captionBus.dispose();
        });
      },
    );
  });

  group('TP-9: lastError after failing and succeeding starts (no engine '
      'errors injected)', () {
    pbt.Glados<List<String>>(
      pbt.any.listWithLengthInRange(
        0,
        30,
        pbt.any.choose(['failStart', 'okStart', 'stop', 'clear']),
      ),
    ).test(
      'lastError is non-null only when the last start() failed and the state '
      'is idle; a later success clears it; a later failure replaces it',
      (commands) async {
        final captionBus = CaptionBus();
        final manager = MockSttSessionManager();
        final wakeLock = MockWakeLockService();
        var failNext = false;
        when(
          () => manager.initialize(
            engineId: any(named: 'engineId'),
            localeId: any(named: 'localeId'),
            onResult: any(named: 'onResult'),
            onError: any(named: 'onError'),
          ),
        ).thenAnswer((inv) async {
          if (failNext) {
            (inv.namedArguments[#onError] as void Function(RecordingError))(
              RecordingErrorFactories.permissionDenied(),
            );
            return false;
          }
          return true;
        });
        when(manager.startListening).thenAnswer((_) async => true);
        when(manager.stop).thenAnswer((_) async {});
        when(wakeLock.acquire).thenAnswer((_) async {});
        when(wakeLock.release).thenAnswer((_) async {});
        when(() => wakeLock.settings).thenReturn(const WakeLockSettings());

        final container = ProviderContainer(
          overrides: [
            captionBusProvider.overrideWithValue(captionBus),
            sttSessionManagerProvider.overrideWithValue(manager),
            wakeLockServiceProvider.overrideWithValue(wakeLock),
            sttEngineProvider.overrideWithValue(MockSttEngine()),
            resolvedLocaleIdProvider.overrideWithValue('en-US'),
          ],
        );
        final notifier =
            container.read(recordingStateNotifierProvider.notifier);
        RecordingState current() =>
            container.read(recordingStateNotifierProvider);

        // The model: idle, recording or stopped; whether lastError is set.
        var modelState = 'idle';
        var modelHasError = false;
        final executed = <String>[];

        for (final command in commands) {
          executed.add(command);
          switch (command) {
            case 'failStart':
              failNext = true;
              await notifier.start();
              if (modelState == 'idle') modelHasError = true;
            case 'okStart':
              failNext = false;
              await notifier.start();
              if (modelState == 'idle') {
                modelState = 'recording';
                modelHasError = false;
              }
            case 'stop':
              await notifier.stop();
              if (modelState == 'recording') modelState = 'stopped';
            case 'clear':
              notifier.clearSession();
              if (modelState == 'stopped') {
                modelState = 'idle';
                modelHasError = false;
              }
          }

          final why = 'after $executed';
          expect(
            current(),
            switch (modelState) {
              'idle' => isA<IdleState>(),
              'recording' => isA<RecordingActiveState>(),
              _ => isA<StoppedState>(),
            },
            reason: why,
          );
          expect(notifier.lastError != null, modelHasError, reason: why);
          if (modelHasError) {
            expect(
              notifier.lastError!.message,
              RecordingErrorFactories.permissionDenied().message,
              reason: why,
            );
          }
        }

        container.dispose();
        captionBus.dispose();
      },
    );
  });
}

_Scenario _scenarioGenerator(Random r) => _Scenario(r);
