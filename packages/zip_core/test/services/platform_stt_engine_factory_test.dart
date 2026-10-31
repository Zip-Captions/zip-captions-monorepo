import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine_factory.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

import '../helpers/fake_on_device_checker.dart';
import '../helpers/mock_audio_device_service.dart';

void main() {
  group('createPlatformSttEngine', () {
    test('builds a PlatformSttEngine with the "platform" engine id', () {
      final engine = createPlatformSttEngine(
        onDeviceSupportChecker: FakeOnDeviceChecker().call,
        deviceService: MockAudioDeviceService(),
      );
      expect(engine, isA<PlatformSttEngine>());
      expect(engine.engineId, 'platform');
      expect(engine, isA<SttErrorSource>());
    });

    test('makes no platform call and no check at construction', () {
      final checker = FakeOnDeviceChecker();
      createPlatformSttEngine(
        onDeviceSupportChecker: checker.call,
        deviceService: MockAudioDeviceService(),
      );
      expect(checker.localesChecked, isEmpty);
    });
  });
}
