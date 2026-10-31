import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/audio_device.dart';
import 'package:zip_core/src/services/audio/audio_device_service.dart';

/// [AudioDeviceService] for iOS and Android (Unit 10, FD E2).
///
/// It claims one input, the system default, and does no routing: the
/// operating system picks the microphone. That claim is true on every
/// platform, so the app overrides `audioDeviceServiceProvider` with it
/// everywhere and the provider no longer throws `UnimplementedError`.
///
/// A preferred device id is stored so the interface's contract holds
/// (`PlatformSttEngine` reads `currentPreferredDeviceId` before listening),
/// but it is not applied.
class MobileAudioDeviceService implements AudioDeviceService {
  /// Creates a [MobileAudioDeviceService] backed by the given preferences.
  MobileAudioDeviceService(this._prefs);

  /// SharedPreferences key documented on [AudioDeviceService].
  static const preferredDeviceKey = 'audio.preferredInputDeviceId';

  static const _systemDefault = AudioDevice(
    deviceId: 'default',
    name: 'System default',
    isDefault: true,
  );

  final SharedPreferences _prefs;

  @override
  Future<List<AudioDevice>> listInputDevices() async => const [_systemDefault];

  @override
  Future<void> setPreferredInputDevice(String deviceId) async {
    await _prefs.setString(preferredDeviceKey, deviceId);
  }

  @override
  Future<void> clearPreferredInputDevice() async {
    await _prefs.remove(preferredDeviceKey);
  }

  @override
  String? get currentPreferredDeviceId => _prefs.getString(preferredDeviceKey);
}
