import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/app_settings.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

import '../helpers/generators.dart';
import '../helpers/prefs_helpers.dart';

class _RecoveryNotifier extends BaseSettingsNotifier {
  @override
  String get keyPrefix => 'rec';
}

final _recoveryProvider =
    NotifierProvider<_RecoveryNotifier, AppSettings>(
  _RecoveryNotifier.new,
);

void main() {
  group('Settings recovery PBT (BR-05)', () {
    // Generate a valid AppSettings + 5 independent FieldStates.
    Glados(
      any.combine6(
        arbitraryAppSettings,
        arbitraryFieldState,
        arbitraryFieldState,
        arbitraryFieldState,
        arbitraryFieldState,
        arbitraryFieldState,
        (
          settings,
          scrollState,
          textSizeState,
          fontState,
          themeState,
          linesState,
        ) =>
            (
          settings: settings,
          fieldStates: {
            'scrollDirection': scrollState,
            'captionTextSize': textSizeState,
            'captionFont': fontState,
            'themeModeSetting': themeState,
            'maxVisibleLines': linesState,
          },
        ),
      ),
    ).test(
      'corrupt fields recover to defaults, valid fields preserved',
      (input) async {
        final fieldStates = input.fieldStates;

        SharedPreferences.setMockInitialValues(
          corruptPrefsMap('rec', fieldStates, input.settings),
        );
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final loaded = container.read(_recoveryProvider);
        final defaults = AppSettings.defaults();

        // Each field: valid -> matches input, otherwise -> default.
        if (fieldStates['scrollDirection'] == FieldState.valid) {
          expect(
            loaded.scrollDirection,
            input.settings.scrollDirection,
          );
        } else {
          expect(
            loaded.scrollDirection,
            defaults.scrollDirection,
          );
        }

        if (fieldStates['captionTextSize'] == FieldState.valid) {
          expect(
            loaded.captionTextSize,
            input.settings.captionTextSize,
          );
        } else {
          expect(
            loaded.captionTextSize,
            defaults.captionTextSize,
          );
        }

        if (fieldStates['captionFont'] == FieldState.valid) {
          expect(
            loaded.captionFont,
            input.settings.captionFont,
          );
        } else {
          expect(loaded.captionFont, defaults.captionFont);
        }

        if (fieldStates['themeModeSetting'] == FieldState.valid) {
          expect(
            loaded.themeModeSetting,
            input.settings.themeModeSetting,
          );
        } else {
          expect(
            loaded.themeModeSetting,
            defaults.themeModeSetting,
          );
        }

        if (fieldStates['maxVisibleLines'] == FieldState.valid) {
          expect(
            loaded.maxVisibleLines,
            input.settings.maxVisibleLines,
          );
        } else {
          expect(
            loaded.maxVisibleLines,
            defaults.maxVisibleLines,
          );
        }
      },
    );
  });
}
