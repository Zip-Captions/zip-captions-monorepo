import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/stt_engine_factory_provider.dart';
import 'package:zip_core/zip_core.dart'
    hide AudioInputConfig, AudioInputVisualStyle;

import '../helpers/fake_services.dart';
import '../helpers/mock_caption_bus.dart';
import '../helpers/mock_stt_engine.dart';
import '../helpers/pbt.dart';

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

class _DynamicInputConfigNotifier extends AudioInputConfigNotifier {
  _DynamicInputConfigNotifier(this.deviceIds);
  final List<String> deviceIds;

  @override
  List<AudioInputConfig> build() =>
      deviceIds.map((id) => AudioInputConfig(deviceId: id, name: id)).toList();
}

ProviderContainer _buildContainer({
  required List<MockSttEngine> engines,
  required List<String> deviceIds,
  MockCaptionBus? bus,
}) {
  final mockBus = bus ?? MockCaptionBus();
  final container = ProviderContainer(
    overrides: [
      captionBusProvider.overrideWithValue(mockBus),
      wakeLockServiceProvider.overrideWithValue(FakeWakeLockService()),
      resolvedLocaleIdProvider.overrideWithValue('en-US'),
      audioInputConfigNotifierProvider.overrideWith(
        () => _DynamicInputConfigNotifier(deviceIds),
      ),
      for (var i = 0; i < engines.length; i++)
        sttEngineFactoryProvider(deviceIds[i]).overrideWith((_) => engines[i]),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

ProviderContainer _buildTwoEngineContainer({
  required MockSttEngine engine0,
  required MockSttEngine engine1,
  MockCaptionBus? bus,
}) {
  return _buildContainer(
    engines: [engine0, engine1],
    deviceIds: ['mic-0', 'mic-1'],
    bus: bus,
  );
}

void main() {
  group('BroadcastRecordingNotifier', () {
    // -----------------------------------------------------------------------
    // TEST-U6.2 — coverage map rows 1–7
    // -----------------------------------------------------------------------

    test('row 1: all engines init → isRecording', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final container = _buildTwoEngineContainer(engine0: e0, engine1: e1);

      await container
          .read(broadcastRecordingNotifierProvider.notifier)
          .start();

      final state = container.read(broadcastRecordingNotifierProvider);
      expect(state.isRecording, isTrue);
    });

    test('row 2: one engine fails init → remaining continue, isRecording',
        () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine()..shouldFailInit = true;
      final container = _buildTwoEngineContainer(engine0: e0, engine1: e1);

      await container
          .read(broadcastRecordingNotifierProvider.notifier)
          .start();

      final state = container.read(broadcastRecordingNotifierProvider);
      expect(state.isRecording, isTrue);
      final activeState = state as BroadcastActiveState;
      expect(
        activeState.perEngineStates['mic-1'],
        isA<EngineErrorState>(),
      );
    });

    test('row 3: all engines fail → IdleState with lastError', () async {
      final e0 = MockSttEngine()..shouldFailInit = true;
      final e1 = MockSttEngine()..shouldFailInit = true;
      final container = _buildTwoEngineContainer(engine0: e0, engine1: e1);

      await container
          .read(broadcastRecordingNotifierProvider.notifier)
          .start();

      final state = container.read(broadcastRecordingNotifierProvider);
      expect(state, isA<BroadcastIdleState>());
      expect((state as BroadcastIdleState).lastError, isNotNull);
    });

    test('row 4: stop → all engines receive stopListening()', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final container = _buildTwoEngineContainer(engine0: e0, engine1: e1);

      final notifier =
          container.read(broadcastRecordingNotifierProvider.notifier);
      await notifier.start();
      await notifier.stop();

      expect(e0.stopCount, equals(1));
      expect(e1.stopCount, equals(1));
    });

    test('row 5: pause → all engines pause()', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final container = _buildTwoEngineContainer(engine0: e0, engine1: e1);

      final notifier =
          container.read(broadcastRecordingNotifierProvider.notifier);
      await notifier.start();
      await notifier.pause();

      expect(e0.pauseCount, equals(1));
      expect(e1.pauseCount, equals(1));
    });

    test('row 6: resume → all engines resume()', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final container = _buildTwoEngineContainer(engine0: e0, engine1: e1);

      final notifier =
          container.read(broadcastRecordingNotifierProvider.notifier);
      await notifier.start();
      await notifier.pause();
      await notifier.resume();

      expect(e0.resumeCount, equals(1));
      expect(e1.resumeCount, equals(1));
    });

    test('row 7: SttResult tagged with sourceId before publication', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final bus = MockCaptionBus();
      final container =
          _buildTwoEngineContainer(engine0: e0, engine1: e1, bus: bus);

      await container
          .read(broadcastRecordingNotifierProvider.notifier)
          .start();

      e0.emit(
        SttResult(
          text: 'hello',
          isFinal: true,
          confidence: 1.0,
          timestamp: DateTime.utc(2025),
          sourceId: 'raw', // overwritten by _handleResult to config.deviceId
        ),
      );

      final events = bus.published.whereType<SttResultEvent>().toList();
      expect(events, isNotEmpty);
      expect(events.first.result.sourceId, equals('mic-0'));
    });
  });

  // -------------------------------------------------------------------------
  // PBT-1 — multi-engine partial failure invariants
  // -------------------------------------------------------------------------

  group('PBT-1', () {
    final initOutcomesGen = any.listWithLengthInRange(
      1,
      4,
      any.boolGen,
    );

    Glados(initOutcomesGen).test(
      'P1+P2: partial failure isolation',
      (List<bool> outcomes) async {
        final deviceIds =
            List.generate(outcomes.length, (i) => 'pbt-mic-$i');
        final engines = List.generate(
          outcomes.length,
          (i) => MockSttEngine()..shouldFailInit = !outcomes[i],
        );
        final container =
            _buildContainer(engines: engines, deviceIds: deviceIds);

        await container
            .read(broadcastRecordingNotifierProvider.notifier)
            .start();

        final state = container.read(broadcastRecordingNotifierProvider);
        if (outcomes.any((ok) => ok)) {
          expect(
            state.isRecording,
            isTrue,
            reason: 'At least one engine succeeded — should be recording',
          );
        } else {
          expect(state, isA<BroadcastIdleState>());
          expect(
            (state as BroadcastIdleState).lastError,
            isNotNull,
            reason: 'All engines failed — lastError must be set',
          );
        }
      },
    );

    Glados(initOutcomesGen).test(
      'P3: perEngineStates count matches configured inputs',
      (List<bool> outcomes) async {
        final deviceIds =
            List.generate(outcomes.length, (i) => 'pbt-mic-$i');
        final engines = List.generate(
          outcomes.length,
          (i) => MockSttEngine()..shouldFailInit = !outcomes[i],
        );
        final container =
            _buildContainer(engines: engines, deviceIds: deviceIds);

        await container
            .read(broadcastRecordingNotifierProvider.notifier)
            .start();

        final state = container.read(broadcastRecordingNotifierProvider);
        if (state is BroadcastActiveState) {
          expect(
            state.perEngineStates.length,
            equals(outcomes.length),
          );
        }
      },
    );
  });
}
