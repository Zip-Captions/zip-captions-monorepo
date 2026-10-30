import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

class _FakeErrorSource implements SttErrorSource {
  void Function(SttEngineError error)? listener;

  @override
  void setErrorListener(void Function(SttEngineError error)? listener) {
    this.listener = listener;
  }
}

void main() {
  group('SttEngineErrorKind', () {
    test('lists exactly the five lasting-error kinds', () {
      expect(
        SttEngineErrorKind.values.map((k) => k.name).toSet(),
        {
          'recognizerUnavailable',
          'onDeviceModelMissing',
          'localeUnsupported',
          'permissionRevoked',
          'restartCapReached',
        },
      );
    });
  });

  group('SttEngineError', () {
    test('carries only its kind (no free-text payload)', () {
      const error = SttEngineError(SttEngineErrorKind.restartCapReached);
      expect(error.kind, SttEngineErrorKind.restartCapReached);
      // The textual form is the type and the kind name, nothing else, so it
      // can never carry a transcript (SECURITY-03).
      expect(
        error.toString(),
        'SttEngineError(kind: SttEngineErrorKind.restartCapReached)',
      );
    });

    test('has value equality on the kind', () {
      expect(
        const SttEngineError(SttEngineErrorKind.permissionRevoked),
        const SttEngineError(SttEngineErrorKind.permissionRevoked),
      );
      expect(
        const SttEngineError(SttEngineErrorKind.permissionRevoked),
        isNot(const SttEngineError(SttEngineErrorKind.localeUnsupported)),
      );
      expect(
        const SttEngineError(SttEngineErrorKind.permissionRevoked).hashCode,
        const SttEngineError(SttEngineErrorKind.permissionRevoked).hashCode,
      );
    });
  });

  group('SttErrorSource', () {
    test('delivers an error to the listener and clears with null', () {
      final source = _FakeErrorSource();
      final received = <SttEngineError>[];
      source.setErrorListener(received.add);
      source.listener!(
        const SttEngineError(SttEngineErrorKind.onDeviceModelMissing),
      );
      expect(received, [
        const SttEngineError(SttEngineErrorKind.onDeviceModelMissing),
      ]);

      source.setErrorListener(null);
      expect(source.listener, isNull);
    });
  });
}
