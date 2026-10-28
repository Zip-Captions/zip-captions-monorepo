import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';
import 'package:zip_core/src/services/stt/stt_session_manager.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

import '../helpers/mock_permission_handler.dart';
import '../helpers/mock_stt_engine.dart';
import '../helpers/pbt.dart' as pbt;

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

      test(
          'succeeds without permission check when requiresMicrophone is false',
          () async {
        // Engine declares it does not need the microphone — no permission
        // stub is set up, so any call to the permission handler would throw.
        final noMicEngine = MockSttEngine(
          engineId: 'no-mic',
          requiresMicrophone: false,
        );
        final noMicRegistry = SttEngineRegistry()..register(noMicEngine);
        final noMicManager = SttSessionManager(registry: noMicRegistry);

        final ok = await noMicManager.initialize(
          engineId: 'no-mic',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );

        expect(ok, isTrue);
        expect(capturedErrors, isEmpty);
      });
    });

    group('full lifecycle', () {
      setUp(stubPermissionGranted);

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

    group('engine error channel (Unit 10, SttErrorSource)', () {
      late MockErrorSourceSttEngine sourceEngine;

      /// The error each kind must map to (Amendment 02 section 5).
      RecordingError expectedFor(SttEngineErrorKind kind, String localeId) =>
          switch (kind) {
            SttEngineErrorKind.recognizerUnavailable =>
              RecordingErrorFactories.engineInitFailed(),
            SttEngineErrorKind.onDeviceModelMissing =>
              RecordingErrorFactories.onDeviceRecognitionUnavailable(),
            SttEngineErrorKind.localeUnsupported =>
              RecordingErrorFactories.localeNotSupported(localeId),
            SttEngineErrorKind.permissionRevoked =>
              RecordingErrorFactories.permissionDenied(),
            SttEngineErrorKind.restartCapReached =>
              RecordingErrorFactories.engineStartFailed(),
          };

      setUp(() async {
        sourceEngine = MockErrorSourceSttEngine();
        registry.register(sourceEngine);
        stubPermissionGranted();
      });

      Future<void> initialize() async {
        final ok = await manager.initialize(
          engineId: sourceEngine.engineId,
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );
        expect(ok, isTrue);
      }

      test('initialize registers a listener on an SttErrorSource', () async {
        expect(sourceEngine.hasErrorListener, isFalse);
        await initialize();
        expect(sourceEngine.hasErrorListener, isTrue);
      });

      test('each kind is forwarded exactly once, mapped to its factory error',
          () async {
        await initialize();
        for (final kind in SttEngineErrorKind.values) {
          capturedErrors.clear();
          sourceEngine.emitError(kind);

          expect(capturedErrors, hasLength(1), reason: kind.name);
          final expected = expectedFor(kind, 'en-US');
          expect(capturedErrors.single.message, expected.message,
              reason: kind.name);
          expect(capturedErrors.single.severity, expected.severity);
        }
      });

      test('dispose clears the listener', () async {
        await initialize();
        manager.dispose();
        expect(sourceEngine.hasErrorListener, isFalse);

        capturedErrors.clear();
        sourceEngine.emitError(SttEngineErrorKind.restartCapReached);
        expect(capturedErrors, isEmpty);
      });

      test('an engine that is not an SttErrorSource is unaffected', () async {
        final ok = await manager.initialize(
          engineId: 'mock',
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );
        expect(ok, isTrue);
        expect(capturedErrors, isEmpty);
      });

      test('a failed initialize registers no listener', () async {
        // Permission is denied, so the engine is never initialised.
        when(() => mockPermissions.checkPermissionStatus(Permission.microphone))
            .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        final ok = await manager.initialize(
          engineId: sourceEngine.engineId,
          localeId: 'en-US',
          onResult: capturedResults.add,
          onError: capturedErrors.add,
        );
        expect(ok, isFalse);
        expect(sourceEngine.hasErrorListener, isFalse);
      });

      pbt.Glados<SttEngineErrorKind>(
        pbt.any.choose(SttEngineErrorKind.values),
      ).test(
        'TP-13: every kind maps to one fatal, non-empty, transcript-free error',
        (kind) async {
          capturedErrors.clear();
          await initialize();
          sourceEngine.emitError(kind);
          expect(capturedErrors, hasLength(1));
          expect(capturedErrors.single.severity, RecordingErrorSeverity.fatal);
          expect(capturedErrors.single.message, isNotEmpty);
        },
      );
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
