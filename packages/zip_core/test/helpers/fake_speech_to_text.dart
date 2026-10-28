import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// An ordered log of calls shared between fakes, so a test can assert what
/// happened *before* what (for example "a check precedes every listen").
class CallLog {
  /// The entries, oldest first.
  final List<String> entries = [];

  /// Appends [entry].
  void add(String entry) => entries.add(entry);

  /// Entries that are, or start with, [prefix].
  List<String> where(String prefix) =>
      entries.where((e) => e.startsWith(prefix)).toList();
}

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

/// A hand-written stand-in for the `speech_to_text` 7.3.0 plugin class.
///
/// It models the behaviours the engine depends on, as read from the locked
/// source:
/// - the public `statusListener` and `errorListener` fields;
/// - a first `initialize()` assigns the listener fields from its arguments
///   (null when none are given), and a second call returns before assigning
///   anything (`speech_to_text.dart:313-319`);
/// - `listen()` may throw [ListenFailedException].
///
/// Every other member throws if called ([Fake]).
class FakeSpeechToText extends Fake implements SpeechToText {
  /// Creates a fake, optionally sharing a [CallLog].
  FakeSpeechToText([CallLog? log]) : log = log ?? CallLog();

  /// The shared call log.
  final CallLog log;

  /// What `initialize()` returns the first time.
  bool initializeResult = true;

  /// How many times `initialize()` was called.
  int initializeCalls = 0;

  /// Outcomes for successive `listen()` calls: `null` means success, an
  /// [Exception] is thrown. When the list is empty, `listen()` succeeds.
  final List<Exception?> listenOutcomes = [];

  /// Every `listen()` call, oldest first.
  final List<FakeListenCall> listenCalls = [];

  /// The `options` argument of the latest `initialize()` call.
  List<SpeechConfigOption>? lastInitializeOptions;

  /// How many times `stop()` was called.
  int stopCalls = 0;

  /// How many times `cancel()` was called.
  int cancelCalls = 0;

  /// When set, every `listen()` waits for this future before it returns (or
  /// throws), so a test can hold the call open.
  Future<void>? listenGate;

  bool _initWorked = false;

  @override
  SpeechErrorListener? errorListener;

  @override
  SpeechStatusListener? statusListener;

  @override
  bool get isAvailable => _initWorked;

  @override
  Future<bool> initialize({
    SpeechErrorListener? onError,
    SpeechStatusListener? onStatus,
    Object? debugLogging = false,
    Duration finalTimeout = SpeechToText.defaultFinalTimeout,
    List<SpeechConfigOption>? options,
  }) async {
    initializeCalls++;
    lastInitializeOptions = options;
    log.add('initialize');
    if (_initWorked) return true;
    errorListener = onError;
    statusListener = onStatus;
    _initWorked = initializeResult;
    return initializeResult;
  }

  @override
  Future<List<LocaleName>> locales() async => const [];

  @override
  Future<void> listen({
    SpeechResultListener? onResult,
    Duration? listenFor,
    Duration? pauseFor,
    String? localeId,
    SpeechSoundLevelChange? onSoundLevelChange,
    Object? cancelOnError = false,
    Object? partialResults = true,
    Object? onDevice = false,
    ListenMode listenMode = ListenMode.confirmation,
    Object? sampleRate = 0,
    SpeechListenOptions? listenOptions,
  }) async {
    log.add('listen');
    listenCalls.add(
      FakeListenCall(
        localeId: localeId,
        listenOptions: listenOptions,
        onResult: onResult,
        usedDeprecatedArguments: cancelOnError != false ||
            partialResults != true ||
            onDevice != false ||
            listenMode != ListenMode.confirmation ||
            sampleRate != 0,
      ),
    );
    final gate = listenGate;
    if (gate != null) await gate;
    if (listenOutcomes.isNotEmpty) {
      final outcome = listenOutcomes.removeAt(0);
      if (outcome != null) throw outcome;
    }
  }

  @override
  Future<void> stop() async {
    stopCalls++;
    log.add('stop');
  }

  @override
  Future<void> cancel() async {
    cancelCalls++;
    log.add('cancel');
  }

  // --- Test controls -------------------------------------------------------

  /// Delivers a plugin status (`listening`, `notListening`, `done`).
  void emitStatus(String status) => statusListener?.call(status);

  /// Delivers a plugin error with [code] (the plugin always sets
  /// `permanent: true`, so the fake does too).
  void emitError(String code) =>
      errorListener?.call(SpeechRecognitionError(code, true));

  /// Delivers a recognition result to the latest `listen()`'s callback.
  void emitResult(String words, {required bool isFinal}) {
    final callback = listenCalls.last.onResult;
    callback?.call(
      SpeechRecognitionResult(
        [SpeechRecognitionWords(words, null, 1)],
        isFinal,
      ),
    );
  }
}
