// Tests for Unit 8 (S-20): external display settings persistence.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/output/overlay/caption_position.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_core/zip_core.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<OutputTargetSettings> load(
    Map<String, Object> stored,
  ) async {
    SharedPreferences.setMockInitialValues(stored);
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);
    container.read(outputTargetSettingsNotifierProvider);
    await pumpEventQueue();
    return container.read(outputTargetSettingsNotifierProvider);
  }

  group('defaults', () {
    test('externalDisplayId is null and the caption position is bottom', () {
      const settings = OutputTargetSettings();

      expect(settings.externalDisplayId, isNull);
      expect(
        settings.externalDisplayCaptionPosition,
        CaptionPosition.bottom,
      );
    });
  });

  group('persistence', () {
    test('externalDisplayId and caption position persist and reload', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await container
          .read(outputTargetSettingsNotifierProvider.notifier)
          .update(
            const OutputTargetSettings(
              externalDisplayId: 'display-2',
              externalDisplayCaptionPosition: CaptionPosition.top,
            ),
          );

      expect(prefs.getString('output.externalDisplayId'), 'display-2');
      expect(
        prefs.getString('output.externalDisplayCaptionPosition'),
        'top',
      );

      final reloaded = await load({
        'output.externalDisplayId': 'display-2',
        'output.externalDisplayCaptionPosition': 'top',
      });
      expect(reloaded.externalDisplayId, 'display-2');
      expect(
        reloaded.externalDisplayCaptionPosition,
        CaptionPosition.top,
      );
    });

    test('an absent id stays null', () async {
      final settings = await load({});

      expect(settings.externalDisplayId, isNull);
      expect(
        settings.externalDisplayCaptionPosition,
        CaptionPosition.bottom,
      );
    });

    test(
      'a stored overlayEnabled=true reloads as false (BR-U8-21)',
      () async {
        final settings = await load({'output.overlayEnabled': true});

        expect(settings.overlayEnabled, isFalse);
      },
    );

    test('the launch force-off leaves the other toggles alone', () async {
      final settings = await load({
        'output.overlayEnabled': true,
        'output.onScreenEnabled': false,
        'output.obsEnabled': true,
        'output.browserSourceEnabled': true,
        'output.browserSourcePort': 9090,
      });

      expect(settings.overlayEnabled, isFalse);
      expect(settings.onScreenEnabled, isFalse);
      expect(settings.obsEnabled, isTrue);
      expect(settings.browserSourceEnabled, isTrue);
      expect(settings.browserSourcePort, 9090);
    });
  });
}
