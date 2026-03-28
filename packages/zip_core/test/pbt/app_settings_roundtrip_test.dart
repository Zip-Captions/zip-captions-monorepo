import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/app_settings.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

import '../helpers/generators.dart';
import '../helpers/prefs_helpers.dart';

class _RoundTripNotifier extends BaseSettingsNotifier {
  @override
  String get keyPrefix => 'rt';
}

final _roundTripProvider =
    NotifierProvider<_RoundTripNotifier, AppSettings>(
  _RoundTripNotifier.new,
);

void main() {
  group('AppSettings round-trip PBT', () {
    Glados(arbitraryAppSettings).test(
      'save then reload produces equal AppSettings',
      (settings) async {
        // Save: build a valid prefs map from the generated settings.
        SharedPreferences.setMockInitialValues(
          validPrefsMap('rt', settings),
        );
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        final loaded = container.read(_roundTripProvider);
        expect(loaded, equals(settings));
      },
    );
  });
}
