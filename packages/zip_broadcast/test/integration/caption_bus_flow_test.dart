import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/stt_engine_factory_provider.dart';
import 'package:zip_core/zip_core.dart'
    hide AudioInputConfig, AudioInputVisualStyle;

import '../helpers/fake_services.dart';
import '../helpers/mock_caption_bus.dart';
import '../helpers/mock_stt_engine.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

class _FixedInputConfigNotifier extends AudioInputConfigNotifier {
  _FixedInputConfigNotifier(this._configs);
  final List<AudioInputConfig> _configs;

  @override
  List<AudioInputConfig> build() => _configs;
}

ProviderContainer _buildContainer({
  required MockSttEngine engine0,
  required MockSttEngine engine1,
  required MockCaptionBus bus,
  required SharedPreferences prefs,
}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      captionBusProvider.overrideWithValue(bus),
      wakeLockServiceProvider.overrideWithValue(FakeWakeLockService()),
      resolvedLocaleIdProvider.overrideWithValue('en-US'),
      audioInputConfigNotifierProvider.overrideWith(
        () => _FixedInputConfigNotifier([
          const AudioInputConfig(deviceId: 'mic-0', name: 'Mic 0'),
          const AudioInputConfig(deviceId: 'mic-1', name: 'Mic 1'),
        ]),
      ),
      sttEngineFactoryProvider('mic-0').overrideWith((_) => engine0),
      sttEngineFactoryProvider('mic-1').overrideWith((_) => engine1),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests — INT-ZB-01: CaptionBus flow and pause gating
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('INT-ZB-01: BroadcastRecordingNotifier caption bus flow', () {
    test('start → emitted result reaches bus with correct sourceId', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final bus = MockCaptionBus();
      final container = _buildContainer(
        engine0: e0,
        engine1: e1,
        bus: bus,
        prefs: prefs,
      );

      final events = <CaptionEvent>[];
      final sub = bus.stream.listen(events.add);
      addTearDown(sub.cancel);

      await container.read(broadcastRecordingNotifierProvider.notifier).start();

      // Session started — verify SessionStateEvent published.
      expect(
        events.whereType<SessionStateEvent>().last.state,
        isA<RecordingActiveState>(),
      );

      // Engine emits a result; notifier tags it with sourceId.
      e0.emit(
        SttResult(
          text: 'hello',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime(2026),
          sourceId: '',
        ),
      );
      await pumpEventQueue();

      final resultEvents = events.whereType<SttResultEvent>().toList();
      expect(resultEvents, hasLength(1));
      expect(resultEvents.first.result.sourceId, equals('mic-0'));
      expect(resultEvents.first.result.text, equals('hello'));
    });

    test('pause → engine emit → no SttResultEvent published', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final bus = MockCaptionBus();
      final container = _buildContainer(
        engine0: e0,
        engine1: e1,
        bus: bus,
        prefs: prefs,
      );

      await container.read(broadcastRecordingNotifierProvider.notifier).start();
      await container.read(broadcastRecordingNotifierProvider.notifier).pause();

      final countBeforeEmit = bus.published.whereType<SttResultEvent>().length;

      // Engine callback is still wired but notifier gates on
      // BroadcastActiveState.
      e0.emit(
        SttResult(
          text: 'should not publish',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime(2026),
          sourceId: '',
        ),
      );
      await pumpEventQueue();

      expect(
        bus.published.whereType<SttResultEvent>().length,
        equals(countBeforeEmit),
        reason: 'No SttResultEvent should be published while paused',
      );
    });

    test(
      'resume after pause → engine emit → SttResultEvent published again',
      () async {
        final e0 = MockSttEngine();
        final e1 = MockSttEngine();
        final bus = MockCaptionBus();
        final container = _buildContainer(
          engine0: e0,
          engine1: e1,
          bus: bus,
          prefs: prefs,
        );

        final notifier = container.read(
          broadcastRecordingNotifierProvider.notifier,
        );
        await notifier.start();
        await notifier.pause();
        await notifier.resume();

        final countBeforeEmit = bus.published
            .whereType<SttResultEvent>()
            .length;

        e0.emit(
          SttResult(
            text: 'after resume',
            isFinal: false,
            confidence: 1,
            timestamp: DateTime(2026),
            sourceId: '',
          ),
        );
        await pumpEventQueue();

        expect(
          bus.published.whereType<SttResultEvent>().length,
          greaterThan(countBeforeEmit),
        );
      },
    );

    test('stop → SessionStateEvent with StoppedState published', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final bus = MockCaptionBus();
      final container = _buildContainer(
        engine0: e0,
        engine1: e1,
        bus: bus,
        prefs: prefs,
      );

      final notifier = container.read(
        broadcastRecordingNotifierProvider.notifier,
      );
      await notifier.start();
      await notifier.stop();

      final stateEvents = bus.published.whereType<SessionStateEvent>().toList();
      final lastState = stateEvents.last.state;
      expect(lastState, isA<StoppedState>());
    });

    test('two sources → each result tagged with its own sourceId', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final bus = MockCaptionBus();
      final container = _buildContainer(
        engine0: e0,
        engine1: e1,
        bus: bus,
        prefs: prefs,
      );

      await container.read(broadcastRecordingNotifierProvider.notifier).start();

      e0.emit(
        SttResult(
          text: 'from mic-0',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime(2026),
          sourceId: '',
        ),
      );
      e1.emit(
        SttResult(
          text: 'from mic-1',
          isFinal: true,
          confidence: 1,
          timestamp: DateTime(2026),
          sourceId: '',
        ),
      );
      await pumpEventQueue();

      final results = bus.published
          .whereType<SttResultEvent>()
          .map((e) => e.result)
          .toList();
      expect(
        results.where((r) => r.sourceId == 'mic-0').map((r) => r.text),
        contains('from mic-0'),
      );
      expect(
        results.where((r) => r.sourceId == 'mic-1').map((r) => r.text),
        contains('from mic-1'),
      );
    });
  });
}
