import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

part 'active_engine_id_provider.g.dart';

/// User-selected STT engine ID, persisted in SharedPreferences.
///
/// `null` means no explicit selection — the app uses the default engine.
@Riverpod(keepAlive: true)
class ActiveEngineIdNotifier extends _$ActiveEngineIdNotifier {
  static const _key = 'stt.activeEngineId';

  @override
  String? build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getString(_key);
  }

  /// Sets and persists the active engine ID.
  Future<void> setEngineId(String? engineId) async {
    state = engineId;
    final prefs = ref.read(sharedPreferencesProvider);
    if (engineId != null) {
      await prefs.setString(_key, engineId);
    } else {
      await prefs.remove(_key);
    }
  }
}
