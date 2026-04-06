import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

part 'locale_provider.g.dart';

/// Manages the user's display locale (BR-06).
///
/// Persistence key: `app_locale` (unprefixed — shared across apps).
///
/// Fallback chain:
/// 1. User-persisted locale
/// 2. Device locale
/// 3. English (`en`)
@Riverpod(keepAlive: true)
class LocaleNotifier extends _$LocaleNotifier {
  static const _key = 'app_locale';

  @override
  Locale build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return _loadLocale(prefs);
  }

  Locale _loadLocale(SharedPreferences prefs) {
    final stored = prefs.getString(_key);
    if (stored != null && stored.isNotEmpty) {
      return Locale(stored);
    }
    return _deviceLocale;
  }

  Locale get _deviceLocale {
    final dispatcher = PlatformDispatcher.instance;
    final locale = dispatcher.locale;
    if (locale.languageCode.isNotEmpty) return Locale(locale.languageCode);
    return const Locale('en');
  }

  /// Persists and applies a new display locale.
  Future<void> setLocale(Locale locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_key, locale.languageCode);
    state = locale;
  }
}
