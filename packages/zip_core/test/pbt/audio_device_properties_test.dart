import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:zip_core/src/models/audio_device.dart';

import '../helpers/generators.dart';

void main() {
  group('AudioDevice PBT', () {
    Glados(arbitraryAudioDevice).test(
      'JSON serialization round-trip preserves all fields',
      (device) {
        final json = device.toJson();
        final restored = AudioDevice.fromJson(json);
        expect(restored, equals(device));
      },
    );

    Glados(arbitraryAudioDevice).test(
      'deviceId is never empty',
      (device) {
        expect(device.deviceId, isNotEmpty);
      },
    );

    Glados(arbitraryAudioDevice).test(
      'name is never empty',
      (device) {
        expect(device.name, isNotEmpty);
      },
    );
  });
}
