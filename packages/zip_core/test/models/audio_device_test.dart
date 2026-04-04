import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/audio_device.dart';

void main() {
  group('AudioDevice', () {
    test('creates with required fields', () {
      const device = AudioDevice(deviceId: 'mic-1', name: 'Built-in Mic');
      expect(device.deviceId, 'mic-1');
      expect(device.name, 'Built-in Mic');
      expect(device.isDefault, isFalse);
    });

    test('isDefault defaults to false', () {
      const device = AudioDevice(deviceId: 'id', name: 'name');
      expect(device.isDefault, isFalse);
    });

    test('isDefault can be set to true', () {
      const device =
          AudioDevice(deviceId: 'id', name: 'name', isDefault: true);
      expect(device.isDefault, isTrue);
    });

    test('equality compares all fields', () {
      const a = AudioDevice(deviceId: 'id', name: 'A');
      const b = AudioDevice(deviceId: 'id', name: 'A');
      const c = AudioDevice(deviceId: 'id', name: 'B');

      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('copyWith creates a new instance with updated fields', () {
      const device =
          AudioDevice(deviceId: 'mic-1', name: 'Mic 1', isDefault: false);
      final updated = device.copyWith(isDefault: true);

      expect(updated.deviceId, 'mic-1');
      expect(updated.name, 'Mic 1');
      expect(updated.isDefault, isTrue);
    });

    test('JSON round-trip preserves all fields', () {
      const device =
          AudioDevice(deviceId: 'mic-1', name: 'Mic', isDefault: true);
      final json = device.toJson();
      final restored = AudioDevice.fromJson(json);
      expect(restored, equals(device));
    });
  });
}
