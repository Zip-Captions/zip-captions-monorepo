import 'package:flutter_test/flutter_test.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'call_log.dart';
import 'fake_listen_call.dart';

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

  /// When set, the next `stop()` waits for this before returning (consumed
  /// after one call), so a test can hold a stop open.
  Future<void>? stopGate;

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
        usedDeprecatedArguments:
            cancelOnError != false ||
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
    final gate = stopGate;
    stopGate = null;
    if (gate != null) await gate;
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
