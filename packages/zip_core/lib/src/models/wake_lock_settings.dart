import 'package:freezed_annotation/freezed_annotation.dart';

part 'wake_lock_settings.freezed.dart';
part 'wake_lock_settings.g.dart';

/// User preferences for screen wake lock during captioning sessions.
///
/// Backed by SharedPreferences via `WakeLockSettingsProvider`.
@freezed
abstract class WakeLockSettings with _$WakeLockSettings {
  /// Creates [WakeLockSettings].
  const factory WakeLockSettings({
    /// Whether the screen should stay on during captioning.
    @Default(true) bool enabled,

    /// Whether to release the wake lock when the session is paused.
    @Default(true) bool releaseOnPause,
  }) = _WakeLockSettings;

  /// Creates [WakeLockSettings] from JSON.
  factory WakeLockSettings.fromJson(Map<String, dynamic> json) =>
      _$WakeLockSettingsFromJson(json);
}
