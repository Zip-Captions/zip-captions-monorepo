import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:zip_core/src/constants/speech_inactivity.dart';
import 'package:zip_core/src/constants/stt_listening_limits.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/src/models/transcript_settings.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/output/transcript_writer_target.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/caption_output_target_registry_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/audio/mobile_audio_device_service.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';
import 'package:zip_core/src/services/stt/stt_session_manager.dart';
import 'package:zip_core/src/stt/engines/platform_stt_engine.dart';
import 'package:zip_core/src/stt/engines/segmented_speech_engine.dart';
import 'package:zip_core/src/stt/stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

import '../helpers/fake_on_device_checker.dart';
import '../helpers/fake_segmented_recognizer_bridge.dart';
import '../helpers/fake_speech_to_text.dart';
import '../helpers/mock_permission_handler.dart';
import '../helpers/mock_transcript_repository.dart';
import '../helpers/mock_wake_lock_service.dart';
import '../helpers/pbt.dart' as pbt;

// TP-6, TP-12 and PBT-10: no transcript text reaches a log record, an
// SttEngineError, a RecordingError or a state's toString, on any of the Unit 10
// paths. The text is generated so that a leak cannot be dismissed as a test
// artifact, and every checked string is also matched token by token, so a
// partial leak counts.

/// Characters that mark a token as generated (PBT-07). Deliberately excludes
/// the em dash: three notifier log lines contain one
/// (`recording_state_notifier.dart:371,377,406`), so using it as a marker
/// would flag those fixed strings. Verified absent from every `_log.` line in
/// `lib/` before this set was fixed.
const _markers = ['ß', 'ø', 'é', 'ñ', 'ü', 'ç', 'å', '語'];

const _punctuation = ['!', '?', '.', ';'];

/// A phrase of three generated tokens.
class _Phrase {
  /// Builds a phrase from [tokens], joining them with punctuation so a leak of
  /// a delimiter-bearing fragment is caught too.
  _Phrase(this.tokens)
      : text = '${tokens[0]}, ${tokens[1]} ${tokens[2]}!';

  /// A phrase whose text is fixed (the PBT-10 example), so it can be const.
  const _Phrase.fixed(this.tokens, this.text);

  final List<String> tokens;
  final String text;

  /// The growing prefixes the interim results use.
  List<String> get prefixes => [
    tokens[0],
    '${tokens[0]}, ${tokens[1]}',
    text,
  ];

  /// Every string that must not appear anywhere: the full phrase and each
  /// token, so a partial leak counts.
  List<String> get forbidden => [text, ...tokens];

  /// Smallest forbidden string length, used to skip short log messages.
  int get shortest => forbidden.map((f) => f.length).reduce(min);

  @override
  String toString() => 'phrase("$text")';
}

_Phrase _generatePhrase(Random r) {
  final tokens = List.generate(3, (_) {
    final length = 8 + r.nextInt(5);
    final markerAt = r.nextInt(length);
    final chars = List.generate(length, (i) {
      if (i == markerAt) {
        return _markers[r.nextInt(_markers.length)];
      }
      return String.fromCharCode(0x61 + r.nextInt(26));
    });
    // At least one separator-like character, so tokens are not one blob.
    if (r.nextBool()) {
      chars[length - 1] = '-';
    }
    return chars.join();
  });
  // Some punctuation is always present (the constructor adds ", " and "!"),
  // and sometimes an extra one is folded into a token.
  if (r.nextBool()) {
    final i = r.nextInt(tokens.length);
    tokens[i] = '${tokens[i]}${_punctuation[r.nextInt(_punctuation.length)]}';
  }
  return _Phrase(tokens);
}

/// The text that reached a sink, so a run cannot pass vacuously.
///
/// Only the text is kept: the vacuity check asks whether a token of *this*
/// scenario's phrase arrived, which an empty-or-not test cannot answer.
class _Sink {
  /// The text of every [SttResultEvent] published to the bus.
  final busTexts = <String>[];

  /// The text of every segment handed to `saveSegment`.
  final savedTexts = <String>[];

  /// Every sink text, in arrival order.
  Iterable<String> get allTexts sync* {
    yield* busTexts;
    yield* savedTexts;
  }

  /// Whether a token of [phrase] (or the whole phrase) reached a sink.
  bool reachedThisPhrase(_Phrase phrase) =>
      allTexts.any((t) => phrase.tokens.any(t.contains));
}

/// Decorator that records every lasting error before forwarding it (TP-12).
///
/// Registered under the engine's own id so the manager finds it; every call
/// is forwarded to the real engine.
class _TeeEngine implements SttEngine, SttErrorSource {
  _TeeEngine(this._inner);

  final SttEngine _inner;

  /// Every error the engine reported, in order.
  final seen = <SttEngineError>[];

  void Function(SttEngineError error)? _downstream;

  @override
  String get engineId => _inner.engineId;
  @override
  String get displayName => _inner.displayName;
  @override
  bool get requiresNetwork => _inner.requiresNetwork;
  @override
  bool get requiresDownload => _inner.requiresDownload;
  @override
  bool get requiresMicrophone => _inner.requiresMicrophone;

  @override
  Future<bool> initialize() => _inner.initialize();
  @override
  Future<bool> isAvailable() => _inner.isAvailable();
  @override
  Future<List<SpeechLocale>> supportedLocales() => _inner.supportedLocales();
  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) => _inner.startListening(localeId: localeId, onResult: onResult);
  @override
  Future<void> stopListening() => _inner.stopListening();
  @override
  Future<bool> pause() => _inner.pause();
  @override
  Future<bool> resume() => _inner.resume();
  @override
  void dispose() => _inner.dispose();

  @override
  void setErrorListener(void Function(SttEngineError error)? listener) {
    _downstream = listener;
    // The real engine's listener is this tee's own wrapper, installed once.
    if (_inner case final SttErrorSource source) {
      source.setErrorListener((error) {
        seen.add(error);
        _downstream?.call(error);
      });
    }
  }
}

/// One built session: a notifier plus everything it talks to.
class _Harness {
  _Harness({
    required this.stt,
    required this.checker,
    required this.repository,
    required this.container,
    required this.notifier,
    required this.tee,
    required this.target,
    required this.busEvents,
    required this.states,
    required this.sink,
    this.segmentBridge,
  });

  final FakeSpeechToText stt;
  final FakeOnDeviceChecker checker;
  final MockTranscriptRepository repository;
  final ProviderContainer container;
  final RecordingStateNotifier notifier;
  final _TeeEngine tee;
  final TranscriptWriterTarget target;
  final List<CaptionEvent> busEvents;
  final List<RecordingState> states;
  final _Sink sink;

  /// The segmented engine's platform, when the harness built one (G9).
  final FakeSegmentedRecognizerBridge? segmentBridge;

  RecordingState get state => container.read(recordingStateNotifierProvider);

  void dispose() {
    container.dispose();
  }
}

/// Builds a harness wired as production is, with only the plugin, checker,
/// repository and wake lock swapped for test doubles.
_Harness _build(
  SharedPreferences prefs, {
  bool defaultCheckerResult = true,
  bool segmented = false,
}) {
  final stt = FakeSpeechToText();
  final checker = FakeOnDeviceChecker(stt.log)
    ..defaultResult = defaultCheckerResult;
  final repository = MockTranscriptRepository();
  final sink = _Sink();

  when(() => repository.createSession(any(), any())).thenAnswer((_) async {});
  when(() => repository.saveSegment(any(), any())).thenAnswer((inv) async {
    final segment = inv.positionalArguments[1] as TranscriptSegment;
    sink.savedTexts.add(segment.text);
  });
  when(
    () => repository.finalizeSession(
      any(),
      durationMs: any(named: 'durationMs'),
      segmentCount: any(named: 'segmentCount'),
    ),
  ).thenAnswer((_) async {});

  // G9: the segmented engine is driven through the same harness, with its
  // platform side a fake bridge instead of the plugin.
  FakeSegmentedRecognizerBridge? segmentBridge;
  final SttEngine engine;
  if (segmented) {
    segmentBridge = FakeSegmentedRecognizerBridge(stt.log);
    engine = SegmentedSpeechEngine(
      bridge: segmentBridge,
      onDeviceSupportChecker: checker.call,
    );
  } else {
    engine = PlatformSttEngine(
      stt: stt,
      deviceService: MobileAudioDeviceService(prefs),
      onDeviceSupportChecker: checker.call,
    );
  }
  final tee = _TeeEngine(engine);
  // Both engines claim the id 'platform', so a harness that leaves the
  // plugin engine registered would have the manager resolve whichever came
  // last. Registering only the selected one keeps the run deterministic.
  final registry = SttEngineRegistry()..register(tee);
  final manager = SttSessionManager(registry: registry);

  final wakeLock = MockWakeLockService();
  when(wakeLock.acquire).thenAnswer((_) async {});
  when(wakeLock.release).thenAnswer((_) async {});
  when(wakeLock.onPause).thenAnswer((_) async {});
  when(() => wakeLock.settings).thenReturn(const WakeLockSettings());

  final captionBus = CaptionBus();
  final container = ProviderContainer(
    overrides: [
      captionBusProvider.overrideWithValue(captionBus),
      sttSessionManagerProvider.overrideWithValue(manager),
      wakeLockServiceProvider.overrideWithValue(wakeLock),
      sttEngineProvider.overrideWithValue(tee),
      resolvedLocaleIdProvider.overrideWithValue('en-US'),
    ],
  );

  // A real finaliser, wired the way transcriptWriterTargetProvider does it.
  final target = TranscriptWriterTarget(
    repository: repository,
    settings: const TranscriptSettings(),
  );
  container.read(captionOutputTargetRegistryProvider).add(target);
  container.read(sessionStopCallbackProvider).callback = () async {
    // Counted so the tearDownAll can prove the finaliser ran.
    _finalizeRuns++;
    await target.finalizeCurrentSession();
  };

  final busEvents = <CaptionEvent>[];
  captionBus.stream.listen((event) {
    busEvents.add(event);
    if (event case SttResultEvent(:final result)) {
      sink.busTexts.add(result.text);
    }
  });
  final states = <RecordingState>[];
  container.listen(
    recordingStateNotifierProvider,
    (_, next) => states.add(next),
  );

  return _Harness(
    stt: stt,
    checker: checker,
    repository: repository,
    container: container,
    notifier: container.read(recordingStateNotifierProvider.notifier),
    tee: tee,
    target: target,
    busEvents: busEvents,
    states: states,
    sink: sink,
    segmentBridge: segmentBridge,
  );
}

int _finalizeRuns = 0;

/// The mock instance captured on the first run, so later runs reuse it.
late SharedPreferences _prefs;


// --- Log capture -----------------------------------------------------------

final _records = <LogRecord>[];
final _loggersSeen = <String>{};
final _levelsSeen = <Level>{};
final _errorKindsSeen = <SttEngineErrorKind>{};
late StreamSubscription<LogRecord> _subscription;
late Level _savedLevel;

/// Every string from a log record that could carry text.
Iterable<String> _recordStrings(LogRecord r) sync* {
  yield r.message;
  final object = r.object;
  if (object != null) yield object.toString();
  final error = r.error;
  if (error != null) yield error.toString();
  final stack = r.stackTrace;
  if (stack != null) yield stack.toString();
}

/// Asserts no checked string contains [phrase] or any of its tokens.
void _assertClean(Iterable<String> strings, _Phrase phrase, String where) {
  for (final s in strings) {
    // Short strings cannot contain an 8-character token; skipping them keeps
    // the message readable and cannot hide a leak.
    if (s.length < phrase.shortest) continue;
    for (final forbidden in phrase.forbidden) {
      expect(
        s.contains(forbidden),
        isFalse,
        reason:
            'transcript text leaked into $where: "$s" '
            '(matched "${forbidden.length > 12 ? 'the phrase' : 'a token'}") '
            'for $phrase',
      );
    }
  }
}

/// Checks everything currently known about a harness against [phrase].
void _assertHarnessClean(_Harness h, _Phrase phrase, String scenario) {
  _assertClean(
    _records.expand(_recordStrings),
    phrase,
    'a log record ($scenario)',
  );

  for (final error in h.tee.seen) {
    _assertClean([error.toString()], phrase, 'an SttEngineError ($scenario)');
  }

  final lastError = h.notifier.lastError;
  if (lastError != null) {
    _assertClean(
      [lastError.message, lastError.toString()],
      phrase,
      'RecordingError ($scenario)',
    );
  }

  for (final state in h.states) {
    _assertClean(
      [state.toString()],
      phrase,
      'a state ($scenario)',
    );
  }
}

/// Drives one scenario and returns the harness's sink for the non-vacuity
/// assertion.
_Sink _runScenario(
  FakeAsync async,
  _Phrase phrase,
  String scenario,
  void Function(_Harness h, FakeAsync async) body, {
  bool defaultCheckerResult = true,
  bool segmented = false,
}) {
  // The mock values are set in setUp, so the instance resolves synchronously.
  unawaited(SharedPreferences.getInstance().then((p) => _prefs = p));
  async.flushMicrotasks();
  final prefs = _prefs;

  final h = _build(
    prefs,
    defaultCheckerResult: defaultCheckerResult,
    segmented: segmented,
  );

  _finalizeRuns = 0;

  body(h, async);

  // Everything the scenario produced is checked together.
  async.flushMicrotasks();
  _assertHarnessClean(h, phrase, scenario);
  // Each record is checked once, against its own scenario's phrase. Without
  // this every later scenario would re-check every earlier seed's records.
  // The logger and level sets keep accumulating for tearDownAll.
  _records.clear();
  _errorKindsSeen.addAll(h.tee.seen.map((e) => e.kind));
  h.dispose();
  return h.sink;
}

// --- Scenarios -------------------------------------------------------------

/// S1: a whole normal session, through a restart and a pause.
void _s1(_Harness h, FakeAsync async, _Phrase phrase) {
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S1 start');

  final prefix = phrase.prefixes;
  h.stt.emitResult(prefix[0], isFinal: false);
  async.flushMicrotasks();
  h.stt.emitResult(prefix[1], isFinal: false);
  async.flushMicrotasks();
  h.stt.emitResult(phrase.text, isFinal: true);
  async.flushMicrotasks();

  // A normal end restarts listening (BR-U10-15).
  h.stt.emitStatus(SpeechToText.doneStatus);
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 300))
    ..flushMicrotasks();

  h.stt.emitResult(prefix[0], isFinal: false);
  async.flushMicrotasks();

  unawaited(n.pause());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<PausedState>(), reason: 'S1 paused');

  unawaited(n.resume());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S1 resumed');

  h.stt.emitResult(prefix[0], isFinal: false);
  async.flushMicrotasks();

  unawaited(n.stop());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
  expect(h.state, isA<StoppedState>(), reason: 'S1 stopped');
}

/// S2: a held interim is flushed as final by `done`, and the session restarts.
void _s2(_Harness h, FakeAsync async, _Phrase phrase) {
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));

  h.stt.emitResult(phrase.prefixes[1], isFinal: false);
  async.flushMicrotasks();

  final listensBefore = h.stt.listenCalls.length;
  h.stt.emitStatus(SpeechToText.doneStatus);
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 300))
    ..flushMicrotasks();

  // BR-U10-16: the held interim became a final, and the restart happened.
  final finals = h.busEvents.whereType<SttResultEvent>().where(
    (e) => e.result.isFinal,
  );
  expect(finals, isNotEmpty, reason: 'S2 flush');
  expect(
    h.stt.listenCalls.length,
    greaterThan(listensBefore),
    reason: 'S2 restart',
  );

  unawaited(n.stop());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
}

/// Drives transient failure codes until the engine reports
/// `restartCapReached` (one cap's worth).
///
/// Each code is followed by `done` inside the immediate-failure window, so
/// every session end counts as a failure (Amendment 01 section 4.2).
void _fillOneCap(_Harness h, FakeAsync async) {
  const limits = defaultSttListeningLimits;
  for (var i = 0; i < limits.restartCap; i++) {
    h.stt.emitError('error_unknown');
    async.flushMicrotasks();
    h.stt.emitStatus(SpeechToText.doneStatus);
    async
      ..flushMicrotasks()
      ..elapse(limits.restartDelay + const Duration(milliseconds: 10))
      ..flushMicrotasks();
  }
}

/// S3: two caps' worth of failures (Amendment 01 section 3.4).
///
/// The first cap is forwarded to the notifier, whose single REL-U2.1 recovery
/// succeeds and starts a fresh engine session with a zeroed counter. The
/// second cap then arrives on a session that has already used its one
/// restart, so it finishes the session.
void _s3(_Harness h, FakeAsync async, _Phrase phrase) {
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S3 start');

  h.stt.emitResult(phrase.prefixes[0], isFinal: false);
  async.flushMicrotasks();

  // First cap: forwarded, then recovered (Reconnecting and back to Active).
  _fillOneCap(h, async);
  expect(
    h.tee.seen,
    [const SttEngineError(SttEngineErrorKind.restartCapReached)],
    reason: 'S3 first cap forwarded once',
  );
  expect(
    h.states,
    contains(isA<ReconnectingState>()),
    reason: 'S3 went through Reconnecting',
  );
  expect(
    h.state,
    isA<RecordingActiveState>(),
    reason: 'S3 recovery started a fresh session',
  );

  // Second cap on the recovered session: no restart left, so it stops.
  h.stt.emitResult(phrase.prefixes[0], isFinal: false);
  async.flushMicrotasks();
  _fillOneCap(h, async);
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();

  expect(
    h.tee.seen,
    const [
      SttEngineError(SttEngineErrorKind.restartCapReached),
      SttEngineError(SttEngineErrorKind.restartCapReached),
    ],
    reason: 'S3 exactly two restartCapReached',
  );
  expect(h.state, isA<StoppedState>(), reason: 'S3 stopped');
  expect(
    h.states.whereType<StoppedState>(),
    hasLength(1),
    reason: 'S3 one StoppedState',
  );
  expect(_finalizeRuns, 1, reason: 'S3 finalised exactly once');
  // The mapping the session manager applies to restartCapReached.
  expect(
    h.notifier.lastError?.message,
    RecordingErrorFactories.engineStartFailed().message,
    reason: 'S3 lastError is the mapped error',
  );
}

/// The lasting plugin codes and the kind each maps to.
///
/// Written out here rather than read from the engine's private map, so a
/// change to that map has to be matched by a change here. Android codes are
/// those of `speech_to_text` 7.3.0; the three `error_speech_recognizer_*` and
/// `error_assets_not_installed` codes are the iOS strings read from the same
/// version's Swift source (R5), which Amendment 01 section 4.1 records as an
/// extension rather than assuming they match Android.
const _lastingCodes = <String, SttEngineErrorKind>{
  'error_permission': SttEngineErrorKind.permissionRevoked,
  'error_language_unavailable': SttEngineErrorKind.onDeviceModelMissing,
  'error_language_not_supported': SttEngineErrorKind.localeUnsupported,
  'error_speech_recognizer_request_not_authorized':
      SttEngineErrorKind.permissionRevoked,
  'error_assets_not_installed': SttEngineErrorKind.onDeviceModelMissing,
  'error_speech_recognizer_disabled': SttEngineErrorKind.recognizerUnavailable,
};

/// The error `SttSessionManager` reports for [kind] (Amendment 01 section 3.3,
/// with Amendment 02's change to the `onDeviceModelMissing` row).
RecordingError _mappedError(SttEngineErrorKind kind) => switch (kind) {
      SttEngineErrorKind.recognizerUnavailable =>
        RecordingErrorFactories.engineInitFailed(),
      SttEngineErrorKind.onDeviceModelMissing =>
        RecordingErrorFactories.onDeviceRecognitionUnavailable(),
      SttEngineErrorKind.localeUnsupported =>
        RecordingErrorFactories.localeNotSupported('en-US'),
      SttEngineErrorKind.permissionRevoked =>
        RecordingErrorFactories.permissionDenied(),
      SttEngineErrorKind.restartCapReached =>
        RecordingErrorFactories.engineStartFailed(),
    };

/// Breaks a session with [code] and lets the notifier's single recovery run.
void _reportLastingAndRecover(
  _Harness h,
  FakeAsync async,
  String code,
) {
  h.stt.emitError(code);
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
}

/// S4: one lasting code, reported twice (Amendment 01 section 3.4).
///
/// The first report is forwarded once and the single recovery succeeds; the
/// cause is still there, so a real plugin raises the same code again, and the
/// second report has no restart left.
void _s4(
  _Harness h,
  FakeAsync async,
  _Phrase phrase,
  String code,
  SttEngineErrorKind kind,
) {
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));

  h.stt.emitResult(phrase.prefixes[0], isFinal: false);
  async.flushMicrotasks();

  // First report: forwarded once, then recovered with a check-first listen.
  final listensBefore = h.stt.listenCalls.length;
  final checksBefore = h.checker.localesChecked.length;
  _reportLastingAndRecover(h, async, code);

  expect(
    h.tee.seen,
    [SttEngineError(kind)],
    reason: 'S4 ($code) first lasting error forwarded once',
  );
  expect(
    h.states,
    contains(isA<ReconnectingState>()),
    reason: 'S4 ($code) went through Reconnecting',
  );
  expect(
    h.state,
    isA<RecordingActiveState>(),
    reason: 'S4 ($code) recovery started a fresh session',
  );
  // The recovery goes through the guard: a check precedes the new listen().
  final recoveryCall = h.stt.log.entries.skip(checksBefore).toList();
  expect(
    h.checker.localesChecked.length,
    greaterThan(checksBefore),
    reason: 'S4 ($code) recovery ran the on-device check',
  );
  final firstListenAfterCheck = recoveryCall.indexOf('listen');
  expect(
    firstListenAfterCheck,
    greaterThan(-1),
    reason: 'S4 ($code) recovery listened again (log: $recoveryCall)',
  );
  expect(
    recoveryCall.take(firstListenAfterCheck).any(
          (e) => e.startsWith('check:'),
        ),
    isTrue,
    reason: 'S4 ($code) a check precedes the recovery listen '
        '(log: $recoveryCall)',
  );
  expect(
    h.stt.listenCalls.length,
    greaterThan(listensBefore),
    reason: 'S4 ($code) recovery made a listen call',
  );

  // Second report: no restart left, so the session stops.
  h.stt.emitResult(phrase.prefixes[1], isFinal: false);
  async.flushMicrotasks();
  _reportLastingAndRecover(h, async, code);

  expect(
    h.tee.seen,
    [SttEngineError(kind), SttEngineError(kind)],
    reason: 'S4 ($code) exactly two reports of ${kind.name}',
  );
  expect(h.state, isA<StoppedState>(), reason: 'S4 ($code) stopped');
  expect(_finalizeRuns, 1, reason: 'S4 ($code) finalised exactly once');
  expect(
    h.notifier.lastError?.message,
    _mappedError(kind).message,
    reason: 'S4 ($code) lastError is the mapped error for ${kind.name}',
  );
}

/// S4b: one lasting code, once, then the recovered session carries on.
///
/// Pins the accepted design: a recovered session does not ignore a *later*
/// lasting error, but the first one costs only one restart.
void _s4b(_Harness h, FakeAsync async, _Phrase phrase) {
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));

  h.stt.emitResult(phrase.prefixes[0], isFinal: false);
  async.flushMicrotasks();

  _reportLastingAndRecover(h, async, 'error_language_unavailable');

  // The recovered session keeps captioning.
  h.stt.emitResult(phrase.prefixes[1], isFinal: false);
  async.flushMicrotasks();
  h.stt.emitResult(phrase.text, isFinal: true);
  async.flushMicrotasks();

  expect(
    h.state,
    isA<RecordingActiveState>(),
    reason: 'S4b still recording after the recovery',
  );
  expect(h.notifier.lastError, isNull, reason: 'S4b lastError cleared');
  expect(_finalizeRuns, 0, reason: 'S4b not finalised before the stop');

  unawaited(n.stop());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();

  expect(h.state, isA<StoppedState>(), reason: 'S4b stopped');
  expect(_finalizeRuns, 1, reason: 'S4b finalised exactly once');
}

/// S5: the on-device refusal at start, in three flavours.
void _s5(_Harness h, FakeAsync async, _Phrase phrase, String variant) {
  switch (variant) {
    case 'false':
      h.checker.defaultResult = false;
    case 'throws':
      h.checker.script.add(Exception(phrase.text));
    case 'timeout':
      h.checker.script.add(FakeOnDeviceChecker.hang);
  }

  unawaited(h.notifier.start());
  async
    ..flushMicrotasks()
    ..elapse(defaultSttListeningLimits.onDeviceCheckTimeout * 2)
    ..flushMicrotasks();

  expect(h.notifier.lastError, isNotNull, reason: 'S5 $variant error');
  expect(h.stt.listenCalls, isEmpty, reason: 'S5 $variant never listened');
}

/// S6: the refusal arrives on a restart instead of the first start.
void _s6(_Harness h, FakeAsync async, _Phrase phrase) {
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S6 start');

  h.stt.emitResult(phrase.prefixes[0], isFinal: false);
  async.flushMicrotasks();

  // The next check refuses, so the restart reports onDeviceModelMissing once.
  h.checker.defaultResult = false;
  h.stt.emitStatus(SpeechToText.doneStatus);
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 2))
    ..flushMicrotasks();

  final missing = h.tee.seen.where(
    (e) => e.kind == SttEngineErrorKind.onDeviceModelMissing,
  );
  // Two reports, not one: the refused restart reports once, and the
  // notifier's REL-U2.1 recovery retries the guard, which refuses again
  // (Amendment 01 section 3.4), so the recovery fails and the session stops.
  expect(
    h.tee.seen,
    const [
      SttEngineError(SttEngineErrorKind.onDeviceModelMissing),
      SttEngineError(SttEngineErrorKind.onDeviceModelMissing),
    ],
    reason: 'S6 one report per refused attempt',
  );
  expect(missing, hasLength(2), reason: 'S6 two onDeviceModelMissing');
  expect(_finalizeRuns, 1, reason: 'S6 finalised exactly once');
}

/// S7: adversarial exceptions whose message carries the phrase.
/// S9 (Amendment 05): speech, then silence until the inactivity stop. The new
/// "Session stopping" log line must carry only the reason and the seconds.
void _s9(_Harness h, FakeAsync async, _Phrase phrase) {
  unawaited(h.notifier.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S9 start');

  h.stt.emitResult(phrase.prefixes[0], isFinal: false);
  async.flushMicrotasks();
  h.stt.emitResult(phrase.text, isFinal: true);
  async
    ..flushMicrotasks()
    ..elapse(defaultSpeechInactivityTimeout)
    ..flushMicrotasks();
  expect(h.state, isA<StoppedState>(), reason: 'S9 inactivity stop');
}

void _s7(
  _Harness h,
  FakeAsync async,
  _Phrase phrase,
  String variant,
) {
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S7 start');

  h.stt.emitResult(phrase.prefixes[0], isFinal: false);
  async.flushMicrotasks();

  switch (variant) {
    case 'listen':
      // The next listen (the restart) throws, message carrying the phrase.
      // Checked against speech_to_text 7.3.0: ListenFailedException(message).
      h.stt.listenOutcomes.add(ListenFailedException(phrase.text));
      h.stt.emitStatus(SpeechToText.doneStatus);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 2))
        ..flushMicrotasks();
    case 'repository':
      when(
        () => h.repository.saveSegment(any(), any()),
      ).thenAnswer((_) async => throw Exception(phrase.text));
      when(
        () => h.repository.finalizeSession(
          any(),
          durationMs: any(named: 'durationMs'),
          segmentCount: any(named: 'segmentCount'),
        ),
      ).thenAnswer((_) async => throw Exception(phrase.text));
      h.stt.emitResult(phrase.text, isFinal: true);
      async.flushMicrotasks();
      unawaited(n.stop());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 2))
        ..flushMicrotasks();
    case 'stopCallback':
      h.container.read(sessionStopCallbackProvider).callback = () async {
        throw Exception(phrase.text);
      };
      h.stt.emitResult(phrase.text, isFinal: true);
      async.flushMicrotasks();
      unawaited(n.stop());
      async
        ..flushMicrotasks()
        ..elapse(const Duration(seconds: 2))
        ..flushMicrotasks();
  }
}

/// S8 (G9): a whole segmented session, with the phrase reaching every sink
/// the engine can reach: bus, writer and, through a renewal, a second session.
void _s8(_Harness h, FakeAsync async, _Phrase phrase) {
  final bridge = h.segmentBridge!;
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S8 start');

  bridge.sendPartial(phrase.prefixes[0]);
  async.flushMicrotasks();
  // A later segment on Android begins with a space; the engine trims it.
  bridge.sendSegment(' ${phrase.prefixes[1]}');
  async.flushMicrotasks();
  bridge.sendSegment(phrase.text);
  async.flushMicrotasks();

  // A normal end of session renews, checked first (BR-U10-39).
  bridge.sendEndOfSession();
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
  expect(bridge.startedLocales, hasLength(2), reason: 'S8 renewal');

  bridge.sendSegment(phrase.prefixes[0]);
  async.flushMicrotasks();

  unawaited(n.pause());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<PausedState>(), reason: 'S8 paused');

  unawaited(n.resume());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));
  expect(h.state, isA<RecordingActiveState>(), reason: 'S8 resumed');

  unawaited(n.stop());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
}

/// S8a (G9): the segmented engine hits its failure budget, so a cap error is
/// raised and reported on a path that also carried text.
void _s8Cap(_Harness h, FakeAsync async, _Phrase phrase) {
  final bridge = h.segmentBridge!;
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));

  bridge.sendSegment(phrase.text);
  async.flushMicrotasks();

  // Two transient errors reach the cap of 3 (increment-then-compare).
  for (var i = 0; i < 3; i++) {
    bridge.sendError(3);
    async
      ..flushMicrotasks()
      ..elapse(const Duration(seconds: 1))
      ..flushMicrotasks();
  }

  unawaited(n.stop());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
}

/// S8b (G9): a lasting code (permission revoked) after text was delivered.
void _s8Lasting(_Harness h, FakeAsync async, _Phrase phrase) {
  final bridge = h.segmentBridge!;
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));

  bridge.sendSegment(phrase.text);
  async.flushMicrotasks();
  bridge.sendError(9);
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();

  unawaited(n.stop());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
}

/// S8c (G9): the bridge throws with the phrase as its message, on start, and
/// the engine must not carry it anywhere.
void _s8Throws(_Harness h, FakeAsync async, _Phrase phrase) {
  final bridge = h.segmentBridge!;
  final n = h.notifier;
  unawaited(n.start());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(milliseconds: 1));

  bridge
    ..sendSegment(phrase.text)
    ..startError = Exception(phrase.text)
    ..sendEndOfSession();
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 2))
    ..flushMicrotasks();

  unawaited(n.stop());
  async
    ..flushMicrotasks()
    ..elapse(const Duration(seconds: 1))
    ..flushMicrotasks();
}

// --- The scenario table ----------------------------------------------------

/// One named scenario the runner drives.
class _Scenario {
  const _Scenario(
    this.name,
    this.run, {
    this.refuses = false,
    this.segmented = false,
  });

  final String name;
  final void Function(_Harness h, FakeAsync async, _Phrase phrase) run;

  /// True for a path that must never get as far as a sink, so the
  /// non-vacuity check is inverted for it.
  final bool refuses;

  /// True for a scenario that runs on `SegmentedSpeechEngine` (G9).
  final bool segmented;
}

/// Every scenario, in run order. S4 runs once per lasting code, so all five
/// error kinds are exercised.
final _scenarios = <_Scenario>[
  const _Scenario('S1 normal session', _s1),
  const _Scenario('S2 pending interim flushed on done', _s2),
  const _Scenario('S3 restart cap', _s3),
  for (final entry in _lastingCodes.entries)
    _Scenario(
      'S4 lasting ${entry.key}',
      (h, a, p) => _s4(h, a, p, entry.key, entry.value),
    ),
  const _Scenario('S4b lasting once then recovered', _s4b),
  for (final variant in ['false', 'throws', 'timeout'])
    _Scenario(
      'S5 refusal at start ($variant)',
      (h, a, p) => _s5(h, a, p, variant),
      refuses: true,
    ),
  const _Scenario('S6 refusal during restart', _s6),
  for (final variant in ['listen', 'repository', 'stopCallback'])
    _Scenario(
      'S7 adversarial exception ($variant)',
      (h, a, p) => _s7(h, a, p, variant),
    ),
  // G9: the Android segmented engine, driven through its fake bridge.
  const _Scenario('S8 segmented session (G9)', _s8, segmented: true),
  const _Scenario('S8a segmented cap (G9)', _s8Cap, segmented: true),
  const _Scenario(
    'S8b segmented lasting error (G9)',
    _s8Lasting,
    segmented: true,
  ),
  const _Scenario('S8c segmented exception (G9)', _s8Throws, segmented: true),
  // Amendment 05: the inactivity stop and its log line.
  const _Scenario('S9 inactivity stop (Amendment 05)', _s9),
];

// --- Test scaffolding ------------------------------------------------------

final _scenarioCount = <String, int>{};

void _count(String name) {
  _scenarioCount[name] = (_scenarioCount[name] ?? 0) + 1;
}

/// A stand-in for [Permission] so mocktail's `any()` has a fallback.
class _FakePermission extends Fake implements Permission {}

/// A stand-in for [TranscriptSegment] so mocktail's `any()` has a fallback.
class _FakeTranscriptSegment extends Fake implements TranscriptSegment {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(_FakePermission());
    registerFallbackValue(_FakeTranscriptSegment());
  });

  setUp(() {
    expect(
      hierarchicalLoggingEnabled,
      isFalse,
      reason:
          'Logger.root.onRecord only sees every logger when hierarchy is '
          'disabled; enabling it would hide deeper loggers',
    );
    _savedLevel = Logger.root.level;
    Logger.root.level = Level.ALL;
    _subscription = Logger.root.onRecord.listen((record) {
      _records.add(record);
      _loggersSeen.add(record.loggerName);
      _levelsSeen.add(record.level);
    });
    SharedPreferences.setMockInitialValues({});
    PermissionHandlerPlatform.instance = MockPermissionHandlerPlatform();
    when(
      () => PermissionHandlerPlatform.instance.checkPermissionStatus(any()),
    ).thenAnswer((_) async => PermissionStatus.granted);
    when(
      () => PermissionHandlerPlatform.instance.requestPermissions(any()),
    ).thenAnswer(
      (_) async => {Permission.microphone: PermissionStatus.granted},
    );
  });

  tearDown(() async {
    await _subscription.cancel();
    _records.clear();
    Logger.root.level = _savedLevel;
  });

  tearDownAll(() {
    // Non-vacuity, in four parts.
    expect(_scenarioCount, isNotEmpty, reason: 'no scenario ran');
    expect(
      _scenarioCount.keys,
      containsAll(_scenarios.map((s) => s.name)),
      reason: 'a registered scenario never ran: $_scenarioCount',
    );
    for (final entry in _scenarioCount.entries) {
      expect(
        entry.value,
        100,
        reason: '${entry.key} ran ${entry.value} times, not 100',
      );
    }

    expect(
      _loggersSeen,
      containsAll(<String>[
        'zip_core.PlatformSttEngine',
        'zip_core.PlatformSttEngine.loop',
        'zip_core.SttSessionManager',
        'zip_core.RecordingStateNotifier',
        'zip_core.TranscriptWriterTarget',
      ]),
      reason: 'loggers seen: $_loggersSeen',
    );

    expect(
      _levelsSeen,
      containsAll(<Level>[Level.FINE, Level.INFO, Level.WARNING, Level.SEVERE]),
      reason: 'levels seen: $_levelsSeen',
    );

    // All five kinds, across all scenarios together: S4 covers the four that
    // come from a lasting plugin code (recognition-unavailable, locale,
    // permission revoked and recogniser unavailable, the last only from iOS's
    // error_speech_recognizer_disabled), and S3 covers the cap.
    expect(
      _errorKindsSeen,
      containsAll(SttEngineErrorKind.values),
      reason: 'engine error kinds seen: $_errorKindsSeen',
    );
  });

  // The generator is a top-level function, so const-ness is decided by the
  // runner, not this call site.
  // ignore: prefer_const_constructors
  pbt.Glados<_Phrase>(_generatePhrase).test(
    'TP-6/TP-12: for any generated phrase, no log record, SttEngineError, '
    'RecordingError or state contains it on any Unit 10 path',
    (phrase) {
      fakeAsync<void>((async) {
        for (final scenario in _scenarios) {
          _count(scenario.name);
          final sink = _runScenario(
            async,
            phrase,
            scenario.name,
            (h, a) => scenario.run(h, a, phrase),
            segmented: scenario.segmented,
          );
          // Non-vacuity, specific to this phrase: a token of it must have
          // reached a sink. The refusal scenario is the one path that should
          // never get that far, so it asserts the opposite.
          expect(
            sink.reachedThisPhrase(phrase),
            !scenario.refuses,
            reason: scenario.refuses
                ? '${scenario.name}: a token reached a sink on a path that '
                    'refuses to listen'
                : '${scenario.name}: no token of the phrase reached a sink, '
                    'so the run proved nothing',
          );
        }
      });
    },
  );

  // PBT-10: one example-based pin, so a regression is readable without a
  // failing seed. Same assertions, three scenarios.
  test('PBT-10: the fixed phrase never reaches a log, an engine error, a '
      'recording error or a state', () {
    const phrase = _Phrase.fixed(
      ['Straßenbahn', 'Köln-Süd', 'naïveté'],
      'Straßenbahn, Köln-Süd naïveté!',
    );

    final scenarios = [
      const _Scenario('S1 normal session', _s1),
      _Scenario(
        'S5 refusal at start (false)',
        (h, a, p) => _s5(h, a, p, 'false'),
        refuses: true,
      ),
      _Scenario(
        'S7 adversarial exception (listen)',
        (h, a, p) => _s7(h, a, p, 'listen'),
      ),
    ];

    for (final scenario in scenarios) {
      fakeAsync<void>((async) {
        final sink = _runScenario(
          async,
          phrase,
          scenario.name,
          (h, a) => scenario.run(h, a, phrase),
          segmented: scenario.segmented,
        );
        expect(
          sink.reachedThisPhrase(phrase),
          !scenario.refuses,
          reason: scenario.refuses
              ? '${scenario.name}: a token reached a sink on a path that '
                  'refuses to listen'
              : '${scenario.name}: no token of the phrase reached a sink',
        );
      });
    }
  });
}
