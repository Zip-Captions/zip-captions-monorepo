import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

part 'transcript_settings_provider.g.dart';

/// Manages the transcript capture toggle.
///
/// Persists a boolean in SharedPreferences under `transcript.captureEnabled`.
/// Default: `true` (capture enabled).
@Riverpod(keepAlive: true)
class TranscriptSettingsNotifier extends _$TranscriptSettingsNotifier {
  static const _key = 'transcript.captureEnabled';

  @override
  bool build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? true;
  }

  /// Toggle transcript capture on or off.
  Future<void> setCaptureEnabled(bool enabled) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, enabled);
    state = enabled;
  }
}
