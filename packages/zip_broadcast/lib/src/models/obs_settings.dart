import 'package:freezed_annotation/freezed_annotation.dart';

part 'obs_settings.freezed.dart';

/// In-memory representation of OBS WebSocket connection settings.
///
/// The [password] field is only ever held in RAM; it is stored to and loaded
/// from `flutter_secure_storage`, never `SharedPreferences` (Q11=A).
///
/// **Security (SEC-U3.2)**: [password] must never be logged. Log [host] and
/// [port] only.
@freezed
abstract class ObsSettings with _$ObsSettings {
  /// Creates an [ObsSettings] instance.
  const factory ObsSettings({
    /// OBS WebSocket host. Persisted to `SharedPreferences` key `obs.host`.
    @Default('localhost') String host,

    /// OBS WebSocket port. Persisted to `SharedPreferences` key `obs.port`.
    @Default(4455) int port,

    /// OBS WebSocket password. Persisted to `flutter_secure_storage` key
    /// `obs.password`. Never logged.
    @Default('') String password,
  }) = _ObsSettings;
}
