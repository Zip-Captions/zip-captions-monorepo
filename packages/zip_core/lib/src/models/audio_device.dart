import 'package:freezed_annotation/freezed_annotation.dart';

part 'audio_device.freezed.dart';
part 'audio_device.g.dart';

/// Represents an audio input device available on the current platform.
///
/// Obtained from `AudioDeviceService.listInputDevices`.
@freezed
abstract class AudioDevice with _$AudioDevice {
  /// Creates an [AudioDevice].
  const factory AudioDevice({
    /// Platform-specific device identifier.
    required String deviceId,

    /// Human-readable device name for UI display.
    required String name,

    /// Whether this is the system default input device.
    @Default(false) bool isDefault,
  }) = _AudioDevice;

  /// Creates an [AudioDevice] from JSON.
  factory AudioDevice.fromJson(Map<String, dynamic> json) =>
      _$AudioDeviceFromJson(json);
}
