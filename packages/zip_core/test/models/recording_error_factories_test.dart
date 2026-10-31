import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';

void main() {
  group('RecordingErrorFactories', () {
    test('permissionDenied has correct message and fatal severity', () {
      final error = RecordingErrorFactories.permissionDenied();
      expect(error.message, contains('denied'));
      expect(error.severity, RecordingErrorSeverity.fatal);
      expect(error.timestamp, isA<DateTime>());
    });

    test('permissionPermanentlyDenied references Settings', () {
      final error = RecordingErrorFactories.permissionPermanentlyDenied();
      expect(error.message, contains('Settings'));
      expect(error.severity, RecordingErrorSeverity.fatal);
    });

    test('engineInitFailed has correct message', () {
      final error = RecordingErrorFactories.engineInitFailed();
      expect(error.message, contains('initialize'));
      expect(error.severity, RecordingErrorSeverity.fatal);
    });

    test('engineStartFailed has correct message', () {
      final error = RecordingErrorFactories.engineStartFailed();
      expect(error.message, contains('start'));
      expect(error.severity, RecordingErrorSeverity.fatal);
    });

    test('engineRequiresModelDownload has correct message', () {
      final error = RecordingErrorFactories.engineRequiresModelDownload();
      expect(error.message, contains('download'));
      expect(error.severity, RecordingErrorSeverity.fatal);
    });

    test('localeNotSupported includes the locale ID', () {
      final error = RecordingErrorFactories.localeNotSupported('zh-TW');
      expect(error.message, contains('zh-TW'));
      expect(error.severity, RecordingErrorSeverity.fatal);
    });

    test('onDeviceRecognitionUnavailable names on-device recognition', () {
      final error = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      expect(error.message, contains('On-device'));
      expect(error.severity, RecordingErrorSeverity.fatal);
    });

    test('onDeviceRecognitionUnavailable is distinct from every other message',
        () {
      final others = <String>{
        RecordingErrorFactories.permissionDenied().message,
        RecordingErrorFactories.permissionPermanentlyDenied().message,
        RecordingErrorFactories.engineInitFailed().message,
        RecordingErrorFactories.engineStartFailed().message,
        RecordingErrorFactories.engineRequiresModelDownload().message,
        RecordingErrorFactories.localeNotSupported('en-US').message,
      };
      expect(
        others,
        isNot(
          contains(
            RecordingErrorFactories.onDeviceRecognitionUnavailable().message,
          ),
        ),
      );
    });

    test('all factories produce distinct timestamps', () async {
      final a = RecordingErrorFactories.permissionDenied();
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final b = RecordingErrorFactories.permissionDenied();
      expect(a.timestamp, isNot(equals(b.timestamp)));
    });
  });
}
