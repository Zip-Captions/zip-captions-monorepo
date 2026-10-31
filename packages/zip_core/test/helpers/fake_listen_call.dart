import 'package:speech_to_text/speech_to_text.dart';

/// One recorded `listen()` call.
class FakeListenCall {
  /// Creates a record of a `listen()` call.
  FakeListenCall({
    required this.localeId,
    required this.listenOptions,
    required this.onResult,
    required this.usedDeprecatedArguments,
  });

  /// The locale passed to `listen()`.
  final String? localeId;

  /// The options passed to `listen()`, if any.
  final SpeechListenOptions? listenOptions;

  /// The result callback passed to `listen()`.
  final SpeechResultListener? onResult;

  /// Whether any of the deprecated per-option arguments were passed.
  final bool usedDeprecatedArguments;
}
