import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';
import 'package:zip_core/src/services/stt/stt_session_manager.dart';

import '../helpers/mock_permission_handler.dart';
import '../helpers/mock_stt_engine.dart';

void main() {
  late SttEngineRegistry registry;
  late MockSttEngine engine;
  late SttSessionManager manager;
  late MockPermissionHandlerPlatform mockPermissions;
  late List<RecordingError> capturedErrors;
  late List<SttResult> capturedResults;

  setUp(() {
    engine = MockSttEngine();
    registry = SttEngineRegistry()..register(engine);
    manager = SttSessionManager(registry: registry);
    capturedErrors = [];
    capturedResults = [];

    mockPermissions = MockPermissionHandlerPlatform();
    PermissionHandlerPlatform.instance = mockPermissions;
  });

  void stubPermissionGranted() {
    when(() => mockPermissions.checkPermissionStatus(Permission.microphone))
        .thenAnswer((_) async => PermissionStatus.granted);
  }

  void stubPermissionDenied() {
    when(() => mockPermissions.checkPermissionStatus(Permission.microphone))
        .thenAnswer((_) async => PermissionStatus.denied);
    when(() => mockPermissions.requestPermissions([Permission.microphone]))
        .thenAnswer(
      (_) async => {Permission.microphone: PermissionStatus.denied},
    );
  }

  void stubPermissionPermanentlyDenied() {
    when(() => mockPermissions.checkPermissionStatus(Permission.microphone))
        .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
  }

  group('SttSessionManager', () {
    group('initialize', () {
      test('succeeds when engine found and permission granted', () async {
        stubPermissionGranted();

        final ok = await manager.initialize(
          engineId: 'mock',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );

        expect(ok, isTrue);
        expect(manager.activeEngine, isNotNull);
        expect(capturedErrors, isEmpty);
      });

      test('fails when engine not found', () async {
        final ok = await manager.initialize(
          engineId: 'nonexistent',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );

        expect(ok, isFalse);
        expect(capturedErrors, hasLength(1));
      });

      test('fails when permission denied', () async {
        stubPermissionDenied();

        final ok = await manager.initialize(
          engineId: 'mock',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );

        expect(ok, isFalse);
        expect(capturedErrors, hasLength(1));
        expect(capturedErrors.first.message, contains('denied'));
      });

      test('fails when permission permanently denied', () async {
        stubPermissionPermanentlyDenied();

        final ok = await manager.initialize(
          engineId: 'mock',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );

        expect(ok, isFalse);
        expect(capturedErrors, hasLength(1));
        expect(capturedErrors.first.message, contains('Settings'));
      });
    });

    group('full lifecycle', () {
      setUp(() {
        stubPermissionGranted();
      });

      test('initialize → startListening → pause → resume → stop', () async {
        await manager.initialize(
          engineId: 'mock',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );

        final listenOk = await manager.startListening();
        expect(listenOk, isTrue);
        expect(engine.isListening, isTrue);

        final pauseOk = await manager.pause();
        expect(pauseOk, isTrue);

        final resumeOk = await manager.resume();
        expect(resumeOk, isTrue);

        await manager.stop();
        expect(engine.isListening, isFalse);
      });

      test('startListening returns false when not initialized', () async {
        final ok = await manager.startListening();
        expect(ok, isFalse);
      });
    });

    group('handleEngineError', () {
      setUp(() async {
        stubPermissionGranted();
        await manager.initialize(
          engineId: 'mock',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );
        await manager.startListening();
      });

      test('recovers on first error', () async {
        final recovered =
            await manager.handleEngineError(Exception('test error'));
        expect(recovered, isTrue);
        expect(engine.isListening, isTrue);
      });
    });

    group('dispose', () {
      test('releases engine resources', () async {
        stubPermissionGranted();
        await manager.initialize(
          engineId: 'mock',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );

        manager.dispose();
        expect(manager.activeEngine, isNull);
      });
    });
  });
}
