import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    _loadAsync();
    return null;
  }

  /// Sets and persists the active locale ID.
  Future<void> setLocaleId(String? localeId) async {
    state = localeId;
    final prefs = await SharedPreferences.getInstance();
    if (localeId != null) {
      await prefs.setString(_key, localeId);
    } else {
      await prefs.remove(_key);
    }
  }

  Future<void> _loadAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored != null) {
      state = stored;
    }
  }
}
