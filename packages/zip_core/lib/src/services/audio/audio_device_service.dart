import 'package:zip_core/src/models/audio_device.dart';

/// Platform-agnostic interface for enumerating audio input devices
/// and directing input to a user-selected device.
///
/// Platform implementations are provided per-target and registered
/// at app startup via [audioDeviceServiceProvider].
abstract interface class AudioDeviceService {
  /// Returns all available audio input devices on the current platform.
  ///
  /// Always includes at least the system default (with `isDefault: true`).
  /// Returns a single default entry if enumeration is unsupported.
  Future<List<AudioDevice>> listInputDevices();

  /// Directs the platform audio session to use the identified device
  /// before the next STT session starts.
  ///
  /// Persists the preference in SharedPreferences under
  /// `audio.preferredInputDeviceId`.
  Future<void> setPreferredInputDevice(String deviceId);

  /// Removes the device preference. Subsequent sessions use the
  /// system default.
  Future<void> clearPreferredInputDevice();

  /// Synchronous accessor to the currently stored preference.
  /// `null` means system default.
  String? get currentPreferredDeviceId;
}
