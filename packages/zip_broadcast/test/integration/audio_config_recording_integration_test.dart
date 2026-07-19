import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _buildContainer({
  required List<Override> engineOverrides,
  required SharedPreferences prefs,
}) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      captionBusProvider.overrideWithValue(MockCaptionBus()),
      wakeLockServiceProvider.overrideWithValue(FakeWakeLockService()),
      resolvedLocaleIdProvider.overrideWithValue('en-US'),
      ...engineOverrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

// ---------------------------------------------------------------------------
// Tests — INT-ZB-02: AudioInputConfigNotifier ↔ BroadcastRecordingNotifier
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('INT-ZB-02: AudioInputConfigNotifier → BroadcastRecordingNotifier', () {
    test('default config → start → one active session', () async {
      // AudioInputConfigNotifier starts with the built-in default: deviceId='default'.
      final engine = MockSttEngine();
      final container = _buildContainer(
        prefs: prefs,
        engineOverrides: [
          sttEngineFactoryProvider('default').overrideWith((_) => engine),
        ],
      );

      await container.read(broadcastRecordingNotifierProvider.notifier).start();

      final state = container.read(broadcastRecordingNotifierProvider);
      expect(state, isA<BroadcastActiveState>());
      final active = state as BroadcastActiveState;
      expect(active.perEngineStates.length, equals(1));
      expect(active.perEngineStates.keys, contains('default'));
    });

    test(
      'add custom config, remove default → start → session for custom deviceId',
      () async {
        final engine = MockSttEngine();
        final container = _buildContainer(
          prefs: prefs,
          engineOverrides: [
            sttEngineFactoryProvider('mic-custom').overrideWith((_) => engine),
          ],
        );

        // Mutate real AudioInputConfigNotifier via the Riverpod container.
        final configNotifier = container.read(
          audioInputConfigNotifierProvider.notifier,
        );
        await configNotifier.loadFuture;
        await configNotifier.removeConfig('default');
        await configNotifier.addConfig(
          const AudioInputConfig(deviceId: 'mic-custom', name: 'Custom Mic'),
        );

        await container
            .read(broadcastRecordingNotifierProvider.notifier)
            .start();

        final state = container.read(broadcastRecordingNotifierProvider);
        expect(state, isA<BroadcastActiveState>());
        final active = state as BroadcastActiveState;
        expect(active.perEngineStates.keys, contains('mic-custom'));
        expect(active.perEngineStates.keys, isNot(contains('default')));
      },
    );

    test('no configs → start → BroadcastIdleState with lastError', () async {
      final container = _buildContainer(engineOverrides: [], prefs: prefs);

      final configNotifier = container.read(
        audioInputConfigNotifierProvider.notifier,
      );
      await configNotifier.loadFuture;
      await configNotifier.removeConfig('default');

      await container.read(broadcastRecordingNotifierProvider.notifier).start();

      final state = container.read(broadcastRecordingNotifierProvider);
      expect(state, isA<BroadcastIdleState>());
      expect((state as BroadcastIdleState).lastError, isNotNull);
    });

    test('two configs → start → two active sessions', () async {
      final e0 = MockSttEngine();
      final e1 = MockSttEngine();
      final container = _buildContainer(
        prefs: prefs,
        engineOverrides: [
          sttEngineFactoryProvider('mic-a').overrideWith((_) => e0),
          sttEngineFactoryProvider('mic-b').overrideWith((_) => e1),
        ],
      );

      final configNotifier = container.read(
        audioInputConfigNotifierProvider.notifier,
      );
      await configNotifier.loadFuture;
      await configNotifier.removeConfig('default');
      await configNotifier.addConfig(
        const AudioInputConfig(deviceId: 'mic-a', name: 'A'),
      );
      await configNotifier.addConfig(
        const AudioInputConfig(deviceId: 'mic-b', name: 'B'),
      );

      await container.read(broadcastRecordingNotifierProvider.notifier).start();

      final state = container.read(broadcastRecordingNotifierProvider);
      expect(state, isA<BroadcastActiveState>());
      final active = state as BroadcastActiveState;
      expect(active.perEngineStates.length, equals(2));
      expect(active.perEngineStates.keys, containsAll(['mic-a', 'mic-b']));
    });
  });
}
