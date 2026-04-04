import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'active_engine_id_provider.g.dart';

/// User-selected STT engine ID, persisted in SharedPreferences.
///
/// `null` means no explicit selection — the app uses the default engine.
@Riverpod(keepAlive: true)
class ActiveEngineIdNotifier extends _$ActiveEngineIdNotifier {
  static const _key = 'stt.activeEngineId';

  @override
  String? build() {
    _loadAsync();
    return null;
  }

  /// Sets and persists the active engine ID.
  Future<void> setEngineId(String? engineId) async {
    state = engineId;
    final prefs = await SharedPreferences.getInstance();
    if (engineId != null) {
      await prefs.setString(_key, engineId);
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
