import 'package:zip_core/src/stt/stt_error_source.dart';

import 'mock_stt_engine.dart';

/// A [MockSttEngine] that also reports lasting errors (an [SttErrorSource]),
/// for the session manager's error-channel tests (Unit 10).
class MockErrorSourceSttEngine extends MockSttEngine implements SttErrorSource {
  MockErrorSourceSttEngine({super.engineId = 'mock-error-source'});

  void Function(SttEngineError error)? _errorListener;

  /// Whether a listener is currently registered.
  bool get hasErrorListener => _errorListener != null;

  @override
  void setErrorListener(void Function(SttEngineError error)? listener) {
    _errorListener = listener;
  }

  /// Reports [kind] to the registered listener, if any.
  void emitError(SttEngineErrorKind kind) {
    _errorListener?.call(SttEngineError(kind));
  }
}
