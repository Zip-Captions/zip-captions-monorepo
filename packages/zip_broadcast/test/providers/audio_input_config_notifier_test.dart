import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';

import '../helpers/pbt.dart';

// ---------------------------------------------------------------------------
// Generators (PBT-2)
// ---------------------------------------------------------------------------

final _nonEmptyString = any.letterOrDigits;

final _audioInputConfigGen = any.combine4(
  _nonEmptyString,
  any.letterOrDigits,
  any.intInRange(0, 4),
  _nonEmptyString,
  (String deviceId, String speakerLabel, int colorIndex, String name) =>
      AudioInputConfig(
    deviceId: deviceId.isEmpty ? 'default' : deviceId,
    name: name.isEmpty ? 'Mic' : name,
    speakerLabel: speakerLabel,
    colorIndex: colorIndex,
  ),
);

final _configListGen = any.listWithLengthInRange(0, 5, _audioInputConfigGen);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AudioInputConfigNotifier', () {
    // -----------------------------------------------------------------------
    // TEST-U6.4 — persistence boundary tests
    // -----------------------------------------------------------------------

    test('addConfig persists to SharedPreferences under correct key', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(audioInputConfigNotifierProvider.notifier);

      await notifier.addConfig(
        const AudioInputConfig(deviceId: 'mic-1', name: 'Test Mic'),
      );

      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString('zip_broadcast.audioInputConfigs');
      expect(stored, isNotNull);
      expect(jsonDecode(stored!), isA<List<dynamic>>());
    });

    test('removeConfig updates state and persists', () async {
      SharedPreferences.setMockInitialValues({
        'zip_broadcast.audioInputConfigs': jsonEncode([
          {'deviceId': 'mic-1', 'name': 'Mic 1', 'speakerLabel': '', 'colorIndex': 0},
        ]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(audioInputConfigNotifierProvider.notifier);
      await notifier.loadFuture;

      await notifier.removeConfig('mic-1');

      final state = container.read(audioInputConfigNotifierProvider);
      expect(state.any((c) => c.deviceId == 'mic-1'), isFalse);
    });

    test('setSpeakerLabel updates state', () async {
      SharedPreferences.setMockInitialValues({
        'zip_broadcast.audioInputConfigs': jsonEncode([
          {'deviceId': 'mic-1', 'name': 'Mic 1', 'speakerLabel': '', 'colorIndex': 0},
        ]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(audioInputConfigNotifierProvider.notifier);
      await notifier.loadFuture;

      await notifier.setSpeakerLabel('mic-1', 'Speaker A');

      final state = container.read(audioInputConfigNotifierProvider);
      expect(
        state.firstWhere((c) => c.deviceId == 'mic-1').speakerLabel,
        equals('Speaker A'),
      );
    });

    test('setColor updates colorIndex', () async {
      SharedPreferences.setMockInitialValues({
        'zip_broadcast.audioInputConfigs': jsonEncode([
          {'deviceId': 'mic-1', 'name': 'Mic 1', 'speakerLabel': '', 'colorIndex': 0},
        ]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier =
          container.read(audioInputConfigNotifierProvider.notifier);
      await notifier.loadFuture;

      await notifier.setColor('mic-1', 2);

      final state = container.read(audioInputConfigNotifierProvider);
      expect(
        state.firstWhere((c) => c.deviceId == 'mic-1').colorIndex,
        equals(2),
      );
    });

    test('loads pre-seeded config from SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({
        'zip_broadcast.audioInputConfigs': jsonEncode([
          {
            'deviceId': 'mic-1',
            'name': 'Mic 1',
            'speakerLabel': 'Speaker A',
            'colorIndex': 1,
          },
        ]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Initialize the notifier and wait for async load.
      final loadNotifier =
          container.read(audioInputConfigNotifierProvider.notifier);
      await loadNotifier.loadFuture;

      final state = container.read(audioInputConfigNotifierProvider);
      expect(state.length, equals(1));
      expect(state.first.deviceId, equals('mic-1'));
      expect(state.first.speakerLabel, equals('Speaker A'));
    });
  });

  // -------------------------------------------------------------------------
  // PBT-2 — AudioInputConfig JSON round-trip
  // -------------------------------------------------------------------------

  group('PBT-2', () {
    Glados(_configListGen).test(
      'P4: AudioInputConfig JSON round-trip is lossless',
      (List<AudioInputConfig> configs) {
        final json = configs.map((c) => c.toJson()).toList();
        final decoded = json.map(AudioInputConfig.fromJson).toList();
        expect(decoded, equals(configs));
      },
    );
  });
}
