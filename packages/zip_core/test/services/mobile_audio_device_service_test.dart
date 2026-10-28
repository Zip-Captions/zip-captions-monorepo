import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/audio_device.dart';
import 'package:zip_core/src/services/audio/mobile_audio_device_service.dart';

import '../helpers/pbt.dart';

Future<MobileAudioDeviceService> _newService([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(initial);
  final prefs = await SharedPreferences.getInstance();
  return MobileAudioDeviceService(prefs);
}

/// A non-empty device id built from letters and digits (PBT-07: a domain
/// generator, not a raw string).
String _deviceId(String raw) => 'dev-$raw';

void main() {
  group('MobileAudioDeviceService (example-based)', () {
    test('lists exactly one device: the system default', () async {
      final service = await _newService();
      final devices = await service.listInputDevices();
      expect(devices, hasLength(1));
      expect(
        devices.single,
        const AudioDevice(
          deviceId: 'default',
          name: 'System default',
          isDefault: true,
        ),
      );
    });

    test('has no preference until one is set', () async {
      final service = await _newService();
      expect(service.currentPreferredDeviceId, isNull);
    });

    test('stores the preference under audio.preferredInputDeviceId', () async {
      final service = await _newService();
      await service.setPreferredInputDevice('usb-1');
      expect(service.currentPreferredDeviceId, 'usb-1');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('audio.preferredInputDeviceId'), 'usb-1');
    });

    test('reads a preference stored by an earlier run', () async {
      final service = await _newService({
        'audio.preferredInputDeviceId': 'earlier',
      });
      expect(service.currentPreferredDeviceId, 'earlier');
    });

    test('clearing removes the stored key', () async {
      final service = await _newService();
      await service.setPreferredInputDevice('usb-1');
      await service.clearPreferredInputDevice();
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.containsKey('audio.preferredInputDeviceId'), isFalse);
      expect(service.currentPreferredDeviceId, isNull);
    });
  });

  group('MobileAudioDeviceService (TP-7, property-based)', () {
    Glados(any.letterOrDigits).test(
      'after setPreferredInputDevice(id), currentPreferredDeviceId == id',
      (raw) async {
        final id = _deviceId(raw);
        final service = await _newService();
        await service.setPreferredInputDevice(id);
        expect(service.currentPreferredDeviceId, id);
      },
    );

    Glados(any.letterOrDigits).test(
      'after clearPreferredInputDevice() the preference is null, and '
      'clearing twice equals clearing once',
      (raw) async {
        final service = await _newService();
        await service.setPreferredInputDevice(_deviceId(raw));
        await service.clearPreferredInputDevice();
        expect(service.currentPreferredDeviceId, isNull);
        await service.clearPreferredInputDevice();
        expect(service.currentPreferredDeviceId, isNull);
      },
    );

    Glados(any.letterOrDigits).test(
      'listInputDevices always returns exactly one device and it is the '
      'default, whatever the stored preference',
      (raw) async {
        final service = await _newService();
        await service.setPreferredInputDevice(_deviceId(raw));
        final devices = await service.listInputDevices();
        expect(devices, hasLength(1));
        expect(devices.single.isDefault, isTrue);
      },
    );
  });
}
