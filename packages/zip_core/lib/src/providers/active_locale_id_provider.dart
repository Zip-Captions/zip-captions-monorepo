import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

part 'active_locale_id_provider.g.dart';

/// User-selected locale ID for speech recognition, persisted in
/// SharedPreferences.
///
/// `null` means no explicit selection — the app uses the fallback locale.
@Riverpod(keepAlive: true)
class ActiveLocaleIdNotifier extends _$ActiveLocaleIdNotifier {
  static const _key = 'stt.activeLocaleId';

  @override
  String? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_key);
  }

  /// Sets and persists the active locale ID.
  Future<void> setLocaleId(String? localeId) async {
    state = localeId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (localeId != null) {
      await prefs.setString(_key, localeId);
    } else {
      await prefs.remove(_key);
    }
  }
}
