import 'dart:async';
import 'dart:math' show min;

import 'package:logging/logging.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:zip_core/src/constants/stt_listening_limits.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/audio/audio_device_service.dart';
import 'package:zip_core/src/stt/on_device_support_checker.dart';
import 'package:zip_core/src/stt/stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

/// Wraps [SpeechToText] for Tier 1 platforms (iOS, macOS, Android, Windows).
///
/// Implements [SttEngine] and the sibling capability [SttErrorSource].
/// Accepts [SpeechToText], [AudioDeviceService] and an
/// [OnDeviceSupportChecker] via constructor injection for testability
/// (TEST-U2.1).
///
/// **Fail closed on-device (Unit 10, Amendment 02):** before **every**
/// `listen()` the engine asks the checker whether on-device recognition is
/// supported for the session's locale, and refuses to listen when the answer
/// is `false`, an exception, or a timeout. The check is never cached. The
/// stock plugin does not do this itself (on iOS it replies with an error but
/// carries on; on Android it silently falls back to the default recogniser).
///
/// **Continuous listening (Unit 10, Amendment 01):** the plugin is built for
/// short phrases, so a session ends at the first pause (Android) or after
/// about a minute (iOS). The engine restarts listening itself when a session
/// ends normally, on the plugin's `done` status only and once per session
/// end, and reports lasting errors through [SttErrorSource].
///
/// **Security (SECURITY-03)**: Never logs transcript text from results.
class PlatformSttEngine implements SttEngine, SttErrorSource {
  /// Creates a [PlatformSttEngine].
  ///
  /// [onDeviceSupportChecker] is required so that a build cannot forget it.
  /// [limits] and [now] default to the production values and exist so tests
  /// can control time and numbers.
  PlatformSttEngine({
    required SpeechToText stt,
    required AudioDeviceService deviceService,
    required OnDeviceSupportChecker onDeviceSupportChecker,
    SttListeningLimits limits = defaultSttListeningLimits,
    DateTime Function() now = DateTime.now,
  }) : _stt = stt,
       _deviceService = deviceService,
       _checker = onDeviceSupportChecker,
       _limits = limits {
    _loop = _SessionLoop(
      limits: limits,
      now: now,
      listen: _listen,
      deliver: (result) => _onResult?.call(result),
      report: _report,
      cancelPlugin: _cancelQuietly,
    );
  }

  static final _log = Logger('zip_core.PlatformSttEngine');

  final SpeechToText _stt;
  final AudioDeviceService _deviceService;
  final OnDeviceSupportChecker _checker;
  final SttListeningLimits _limits;
  late final _SessionLoop _loop;

  void Function(SttEngineError error)? _errorListener;
  String? _activeLocaleId;
  void Function(SttResult)? _onResult;

  @override
  String get engineId => 'platform';

  @override
  String get displayName => 'Platform Speech Recognition';

  @override
  bool get requiresNetwork => false;

  @override
  bool get requiresDownload => false;

  @override
  bool get requiresMicrophone => true;

  @override
  void setErrorListener(void Function(SttEngineError error)? listener) {
    _errorListener = listener;
  }

  @override
  Future<bool> initialize() async {
    try {
      final available = await _stt.initialize();
      if (available) {
        // BR-U10-24: assign the plugin's listener fields ourselves. A second
        // call to the plugin's own initialize() returns before assigning
        // anything, and the first call assigns null when none is passed.
        _stt
          ..statusListener = _loop.onStatus
          ..errorListener = (error) => _loop.onError(error.errorMsg);
      }
      _log.info('Platform STT initialized: $available');
      return available;
    } on Exception catch (e) {
      _log.severe('Initialize error: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    try {
      return _stt.isAvailable;
    } on Exception {
      return false;
    }
  }

  @override
  Future<List<SpeechLocale>> supportedLocales() async {
    try {
      final locales = await _stt.locales();
      return locales
          .map(
            (l) => SpeechLocale(
              localeId: l.localeId,
              displayName: l.name,
            ),
          )
          .toList();
    } on Exception catch (e) {
      _log.warning('supportedLocales error: ${e.runtimeType}');
      return [];
    }
  }

  /// Starts a listening session, guarded by the on-device check.
  ///
  /// **Ordering assumption (speech_to_text 7.3.0):** the plugin's `listen()`
  /// only completes once the platform has accepted the request, so its normal
  /// return is the authority for "started". A stop or pause that lands while
  /// `listen()` is still awaiting its reply therefore cannot prevent the
  /// plugin session from beginning; this method detects that with the epoch
  /// and cancels the plugin itself. Re-verify on any plugin upgrade: if
  /// `listen()` ever returns before the platform starts, or gains a way to be
  /// cancelled while pending, this method's cancel here becomes unnecessary
  /// and the early epoch checks may be able to move later.
  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    _activeLocaleId = localeId;
    _onResult = onResult;

    // BR-U10-19: a stop or a pause that arrives while this call is awaiting
    // must win, so the microphone is never left live. The epoch moves on each
    // of those requests (and on dispose); comparing it after every await tells
    // this call it has been superseded.
    final epoch = _loop.epoch;

    // Set preferred device before listening (BR-U2-16).
    final preferredDevice = _deviceService.currentPreferredDeviceId;
    if (preferredDevice != null) {
      await _deviceService.setPreferredInputDevice(preferredDevice);
      if (_loop.epoch != epoch) return false;
    }

    // BR-U10-19 again between the guard and the plugin: an interrupt during
    // the on-device check means no listen() is made at all.
    final allowed = await _onDeviceAllowed(localeId);
    if (_loop.epoch != epoch) return false;
    if (!allowed) {
      // BR-U10-27: refuse. No listen() call; one lasting error.
      _report(SttEngineErrorKind.onDeviceModelMissing);
      return false;
    }

    // The plugin may deliver a status or an error before `listen()` returns;
    // the loop holds those for this epoch and applies them once the session
    // is marked started. A result is passed to the app at once (the notifier
    // holds it until the start succeeds: BR-U10-62); the loop holds and
    // replays only its effect on the loop's own state.
    _loop.startingSession();
    final outcome = await _listenPlugin(localeId);
    if (_loop.epoch != epoch) {
      // The interrupt won while listen() was in flight. Per the ordering
      // assumption above, the plugin session may already have begun; the
      // outcome is only knowable now, so an already started session is
      // cancelled here.
      if (outcome == _ListenOutcome.started) await _cancelQuietly();
      return false;
    }
    if (outcome == _ListenOutcome.started) {
      _loop.sessionStarted(localeId);
      return true;
    }
    _loop.abandonStarting();
    return false;
  }

  /// The loop's restart path. The on-device guard runs first, every time
  /// (BR-U10-26). [epoch] is what the caller captured before any await; if a
  /// stop, pause or dispose moved it during the check, no `listen()` is made
  /// (BR-U10-19).
  Future<_ListenOutcome> _listen(String localeId, int epoch) async {
    final allowed = await _onDeviceAllowed(localeId);
    if (_loop.epoch != epoch) return _ListenOutcome.superseded;
    if (!allowed) {
      // BR-U10-27: refuse. No listen() call; one lasting error.
      _report(SttEngineErrorKind.onDeviceModelMissing);
      return _ListenOutcome.refused;
    }
    // Hold the new session's events from here (not from before the check, so
    // a late event of the old, ended session is not taken for the new one).
    _loop.startingSession();
    return _listenPlugin(localeId);
  }

  /// The plugin call alone, with the guard already passed.
  Future<_ListenOutcome> _listenPlugin(String localeId) async {
    try {
      await _stt.listen(
        localeId: localeId,
        onResult: (result) {
          final sttResult = SttResult(
            text: result.recognizedWords,
            isFinal: result.finalResult,
            confidence: result.confidence,
            timestamp: DateTime.now(),
            sourceId: engineId,
          );
          // The loop decides whether the app should see it, and which words:
          // a result after a stop or a pause is dropped unless the drain is
          // collecting the last phrase (BR-U10-55), and words already
          // committed at a pause are trimmed off (BR-U10-69).
          final delivered = _loop.onResult(sttResult);
          if (delivered != null) _onResult?.call(delivered);
        },
        // BR-U10-20: partial results on and cancel-on-error off are the
        // plugin's defaults; the 'listen options' test pins both so a change
        // to the defaults cannot silently change the engine's behaviour.
        // BR-U10-71: punctuation and Apple's dictation task hint, for running
        // speech (the plugin applies both on iOS only).
        listenOptions: SpeechListenOptions(
          onDevice: true,
          autoPunctuation: true,
          listenMode: ListenMode.dictation,
        ),
      );
      _log.info('Listening started for locale $localeId');
      return _ListenOutcome.started;
    } on Exception catch (e) {
      // BR-U10-30/31: any failure of listen() is transient, and the plugin may
      // have carried on regardless (iOS), so cancel at once. The exception's
      // message is never inspected or logged.
      _log.severe('startListening error: ${e.runtimeType}');
      await _cancelQuietly();
      return _ListenOutcome.threw;
    }
  }

  /// Asks the checker, failing closed (BR-U10-29): an exception, a missing
  /// plugin or a timeout is "unsupported". Logs the boolean only.
  Future<bool> _onDeviceAllowed(String localeId) async {
    try {
      final allowed = await _checker(
        localeId,
      ).timeout(_limits.onDeviceCheckTimeout);
      _log.info('On-device support check: $allowed');
      return allowed;
    } on Object catch (e) {
      _log.warning('On-device support check failed: ${e.runtimeType}');
      return false;
    }
  }

  Future<void> _cancelQuietly() async {
    try {
      await _stt.cancel();
    } on Exception catch (e) {
      _log.warning('cancel error: ${e.runtimeType}');
    }
  }

  void _report(SttEngineErrorKind kind) {
    _log.warning('Reporting engine error: ${kind.name}');
    _errorListener?.call(SttEngineError(kind));
  }

  @override
  Future<void> stopListening() async {
    // Intent first, then the plugin (BR-U10-19), so a trailing `done` never
    // restarts.
    final drain = _loop.stopRequested();
    try {
      await _stt.stop();
      // BR-U10-55: `stop()` lets the platform finish the speech it already
      // captured (Android and iOS alike); cancelling at once would discard
      // the iOS final result. Wait for it, bounded, then cancel.
      if (drain != null) await _loop.awaitDrain(drain);
      // Amendment 06 revision 3: a stop that returns after a new start, or
      // while one is in flight, must not cancel the plugin session that start
      // began or is beginning (its intent is still `stopped` until `listen()`
      // returns).
      if (_loop.isStopped && !_loop.isStarting) await _stt.cancel();
      _log.info('Listening stopped');
    } on Exception catch (e) {
      _log.warning('stopListening error: ${e.runtimeType}');
    } finally {
      if (drain != null) _loop.closeDrain(drain);
    }
  }

  @override
  Future<bool> pause() async {
    // speech_to_text has no native pause — stop and record paused state.
    final drain = _loop.pauseRequested();
    try {
      await _stt.stop();
      // BR-U10-55: the last phrase is accepted before pause returns, so the
      // notifier saves it before it sets the paused state (BR-U10-56). The
      // plugin is left stopped, not cancelled.
      if (drain != null) await _loop.awaitDrain(drain);
      _log.info('Paused (via stop)');
      return true;
    } on Exception catch (e) {
      _log.warning('Pause error: ${e.runtimeType}');
      return false;
    } finally {
      if (drain != null) _loop.closeDrain(drain);
    }
  }

  @override
  Future<bool> resume() async {
    if (!_loop.isPaused || _activeLocaleId == null || _onResult == null) {
      return false;
    }
    // Transparent restart with same locale and callback. It goes through
    // startListening, so the on-device guard runs again.
    return startListening(
      localeId: _activeLocaleId!,
      onResult: _onResult!,
    );
  }

  @override
  void dispose() {
    _loop.dispose();
    _stt
      ..statusListener = null
      ..errorListener = null;
    unawaited(_stt.cancel());
    _onResult = null;
    _errorListener = null;
  }
}

/// What a call to the engine's `listen()` path came to.
enum _ListenOutcome {
  /// The plugin's `listen()` returned normally.
  started,

  /// The on-device guard refused (a lasting error was already reported).
  refused,

  /// The plugin's `listen()` threw (already cancelled).
  threw,

  /// A stop, pause or dispose arrived during the on-device check, so no
  /// `listen()` was made.
  superseded,
}

/// How a non-lasting error code from the plugin is handled (Amendment 01,
/// section 4.1). Ordered by severity so the worst class seen in a session can
/// be kept. Lasting codes are handled at once and never recorded here.
enum _ErrorClass { none, silence, transient }

/// Silence: a normal end. Restarts, reports nothing, never counts.
const _silenceCodes = {'error_no_match', 'error_speech_timeout'};

/// Lasting: reports once and stops. Android codes are those of
/// `speech_to_text` 7.3.0 (`SpeechToTextPlugin.kt`); the iOS codes are read
/// from the same version's `SpeechToTextPlugin.swift` (R5). Everything not
/// listed here, including `error_unknown (n)`, is transient.
const _lastingCodes = <String, SttEngineErrorKind>{
  'error_permission': SttEngineErrorKind.permissionRevoked,
  'error_language_unavailable': SttEngineErrorKind.onDeviceModelMissing,
  'error_language_not_supported': SttEngineErrorKind.localeUnsupported,
  'error_speech_recognizer_request_not_authorized':
      SttEngineErrorKind.permissionRevoked,
  'error_assets_not_installed': SttEngineErrorKind.onDeviceModelMissing,
  'error_speech_recognizer_disabled': SttEngineErrorKind.recognizerUnavailable,
};

enum _Intent { idle, listening, paused, stopped, failed }

/// The continuous-listening loop (Unit 10, Amendment 01; P2).
///
/// Restarts on the plugin's `done` status only, once per session end.
/// Errors and `notListening` only update the per-session record. The
/// failure budget is increment-then-compare (`++count >= restartCap`).
/// Never logs or stores anything but result text held in memory for the
/// final-first flush (SECURITY-03).
class _SessionLoop {
  _SessionLoop({
    required this.limits,
    required this.now,
    required this.listen,
    required this.deliver,
    required this.report,
    required this.cancelPlugin,
  });

  static final _log = Logger('zip_core.PlatformSttEngine.loop');

  final SttListeningLimits limits;
  final DateTime Function() now;
  final Future<_ListenOutcome> Function(String localeId, int epoch) listen;
  final void Function(SttResult result) deliver;
  final void Function(SttEngineErrorKind kind) report;
  final Future<void> Function() cancelPlugin;

  _Intent _intent = _Intent.idle;

  /// Moves on every stop, pause or dispose (BR-U10-19). A guarded listen
  /// captures it before its awaits and abandons the attempt if it has moved,
  /// so an interrupt that arrives mid-start always wins.
  int _epoch = 0;
  int get epoch => _epoch;

  String? _localeId;
  Timer? _timer;
  int _failureCount = 0;

  // The per-session record (reset by `_beginSession`).
  DateTime _startedAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _deliveredResult = false;
  _ErrorClass _worst = _ErrorClass.none;
  bool _restartScheduled = false;
  SttResult? _pendingInterim;

  bool get isPaused => _intent == _Intent.paused;

  /// Still stopped: nothing has started since the last stop.
  bool get isStopped => _intent == _Intent.stopped;

  /// Whether a first start, a resume or a restart `listen()` is in flight.
  /// Plugin status and error events that arrive meanwhile are held in [_held]
  /// and replayed, in order, once [sessionStarted] or [_restartStarted] has
  /// marked the session as listening. Results are delivered at once (the app's
  /// notifier holds them during a start or a resume and drops them if it
  /// fails: Amendment 06, BR-U10-62); only their effect on the loop's state,
  /// such as the pending interim and the pause timer, is held and replayed.
  /// A stop, pause or dispose clears them (BR-U10-19: the interrupt wins).
  bool _starting = false;
  final List<void Function()> _held = [];

  /// Whether a start's `listen()` is in flight (the intent stays `stopped`
  /// until it returns).
  bool get isStarting => _starting;

  /// Marks a start, a resume or a restart `listen()` as about to be in flight.
  void startingSession() {
    _starting = true;
    _held.clear();
    // BR-U10-69: a new plugin session counts its words from zero.
    _committed.clear();
    _cancelPauseTimer();
    // Amendment 06 revision 3: a stop or pause still stuck in the plugin keeps
    // its drain open; the new session must not run inside it.
    _abandonDrain();
  }

  /// The start did not produce a session (refused or threw): drop what was
  /// held, as no session exists to apply it to.
  void abandonStarting() {
    _starting = false;
    _held.clear();
  }

  /// A session started successfully (first start or a resume).
  void sessionStarted(String localeId) {
    _localeId = localeId;
    _intent = _Intent.listening;
    _failureCount = 0;
    _restartScheduled = false;
    _beginSession();
    _replayHeld();
  }

  /// A restart's `listen()` succeeded. Unlike [sessionStarted] this keeps the
  /// failure count: only a delivered result resets it (Amendment 01).
  void _restartStarted() {
    _restartScheduled = false;
    _beginSession();
    _replayHeld();
  }

  void _replayHeld() {
    _starting = false;
    final held = List<void Function()>.of(_held);
    _held.clear();
    for (final apply in held) {
      apply();
    }
  }

  void _beginSession() {
    _startedAt = now();
    _deliveredResult = false;
    _worst = _ErrorClass.none;
    _pendingInterim = null;
    _cancelPauseTimer();
  }

  /// A recognition result arrived. Returns what the app's callback should
  /// receive now, or null for nothing.
  ///
  /// The plugin's text is cumulative for its session, so the words already
  /// committed at a pause are trimmed off first (BR-U10-69); a result with no
  /// new words is not delivered. During a drain (BR-U10-55) only the first
  /// final result is passed on; an interim is remembered so the end of the
  /// wait can flush it as final. After a stop or a pause, outside a drain,
  /// nothing is passed on.
  SttResult? onResult(SttResult raw) {
    if (_starting) {
      // A new session's words count from zero, so there is nothing to trim.
      // The result goes to the app at once (BR-U10-62: the notifier holds it
      // during a start and drops it if the start fails); the replay re-applies
      // only its effect on this loop (pending interim, pause timer) and its
      // return value is discarded.
      _held.add(() => onResult(raw));
      return raw;
    }
    final result = _trimCommitted(raw);
    if (_draining) {
      if (_drainDeliveredFinal) return null;
      if (raw.isFinal) {
        // A final with no new words still ends the wait.
        _drainDeliveredFinal = true;
        _pendingInterim = null;
        _endDrain();
        return result;
      }
      if (result != null) _pendingInterim = result;
      return null;
    }
    if (_intent == _Intent.stopped || _intent == _Intent.paused) return null;
    if (_intent == _Intent.listening) {
      _deliveredResult = true;
      _failureCount = 0;
      if (raw.isFinal) {
        // A final delivers the rest of the session at once and closes its
        // cumulative text, so whatever follows counts from zero.
        _pendingInterim = null;
        _cancelPauseTimer();
        _committed.clear();
      } else if (result != null) {
        // A result with no new words leaves what is pending as it is.
        _pendingInterim = result;
        _armPauseTimer();
      }
    }
    return result;
  }

  /// Words of the session's cumulative text already delivered as final at a
  /// pause, in normalized form (BR-U10-69). Cleared when a new plugin session
  /// starts, and when the plugin's text turns out to have been reset.
  final List<String> _committed = [];
  Timer? _pauseTimer;

  // Scripts written without spaces: each character is a token (BR-U10-69
  // revision 3).
  static const _unspacedScripts =
      r'\p{Script=Han}\p{Script=Hiragana}\p{Script=Katakana}\p{Script=Thai}'
      r'\p{Script=Lao}\p{Script=Khmer}\p{Script=Myanmar}';

  /// A token is one character of an unspaced script, or a run of other
  /// non-space characters.
  static final _tokenPattern = RegExp(
    '[$_unspacedScripts]|[^\\s$_unspacedScripts]+',
    unicode: true,
  );

  static final _notLetterDigitMark = RegExp(
    r'[^\p{L}\p{N}\p{M}]',
    unicode: true,
  );

  /// A token compared without case, punctuation or symbols. Combining marks
  /// stay: Thai and other scripts need them.
  static String _normalize(String token) =>
      token.toLowerCase().replaceAll(_notLetterDigitMark, '');

  /// The normalized tokens of [text] with their start offsets in it. A token
  /// that is empty once normalized (pure punctuation) is dropped.
  static List<({String token, int start})> _tokensOf(String text) {
    final tokens = <({String token, int start})>[];
    for (final match in _tokenPattern.allMatches(text)) {
      final token = _normalize(match[0]!);
      if (token.isNotEmpty) tokens.add((token: token, start: match.start));
    }
    return tokens;
  }

  /// [raw] without the tokens already committed, or null when none are new.
  /// With nothing committed the result is returned untouched.
  ///
  /// BR-U10-69 revision 2: the plugin may rewrite or restart its cumulative
  /// text (iOS does, mid-session). The text continues the committed tokens when
  /// more than half of them match, position by position, so a revised word or
  /// two is tolerated. Otherwise it is a reset: the committed tokens are
  /// forgotten and [raw] is returned whole. Accepted trade-off: a rewrite of
  /// more than half of the committed tokens looks like a reset, so that phrase
  /// repeats; repeated words are preferred to lost words.
  ///
  /// BR-U10-69 revision 3: tokens are single characters in scripts written
  /// without spaces. The trimmed text is cut from [raw]'s own text at the
  /// first new token, so its punctuation and capitals are kept; runs of
  /// whitespace are collapsed to one space.
  SttResult? _trimCommitted(SttResult raw) {
    if (_committed.isEmpty) return raw;
    final tokens = _tokensOf(raw.text);
    final compared = min(_committed.length, tokens.length);
    var matches = 0;
    for (var i = 0; i < compared; i++) {
      if (tokens[i].token == _committed[i]) matches++;
    }
    if (matches * 2 <= _committed.length) {
      _committed.clear();
      return raw;
    }
    if (tokens.length <= _committed.length) return null;
    return SttResult(
      text: raw.text
          .substring(tokens[_committed.length].start)
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
      isFinal: raw.isFinal,
      confidence: raw.confidence,
      timestamp: raw.timestamp,
      sourceId: raw.sourceId,
    );
  }

  /// BR-U10-68: each interim result re-arms the timer; when it fires, the
  /// pending text is a segment. The plugin session is left running.
  void _armPauseTimer() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(limits.iosSegmentPause, _commitPending);
  }

  void _cancelPauseTimer() {
    _pauseTimer?.cancel();
    _pauseTimer = null;
  }

  void _commitPending() {
    _pauseTimer = null;
    if (_intent != _Intent.listening || _draining || _starting) return;
    _flushPendingInterim();
  }

  /// Whether a stop or a pause is waiting for the platform to finish
  /// recognising the speech it already captured (BR-U10-55).
  bool _draining = false;
  Completer<void>? _drainDone;
  bool _drainDeliveredFinal = false;

  void _endDrain() {
    final done = _drainDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// Waits for the drain to end (a final result, the status `done`, an error
  /// or `finalResultDrainTimeout`), then delivers a pending interim as final
  /// once if no final arrived (BR-U10-16).
  ///
  /// Acts only while [drain] is still the open drain: one that a new session
  /// abandoned (Amendment 06 revision 3) returns at once and flushes nothing,
  /// so it never touches the new session's pending text.
  Future<void> awaitDrain(int drain) async {
    final done = _drainDone;
    if (done == null || _openDrain != drain) return;
    final timer = Timer(limits.finalResultDrainTimeout, _endDrain);
    try {
      await done.future;
    } finally {
      timer.cancel();
      if (_openDrain == drain) {
        if (_drainDeliveredFinal) {
          _pendingInterim = null;
        } else {
          _flushPendingInterim();
        }
        closeDrain(drain);
      }
    }
  }

  /// Closes the drain [drain]; later results are dropped again. Does nothing
  /// when that drain is no longer the open one.
  void closeDrain(int drain) {
    if (_openDrain != drain) return;
    _draining = false;
    _drainDone = null;
    _openDrain = 0;
    _pendingInterim = null;
  }

  /// Ends the open drain without flushing: a waiting [awaitDrain] returns at
  /// once and its text is dropped (Amendment 06 revision 3).
  void _abandonDrain() {
    if (!_draining) return;
    _endDrain();
    _draining = false;
    _drainDone = null;
    _openDrain = 0;
    _pendingInterim = null;
  }

  int _drainCount = 0;

  /// The number of the open drain, or 0 when none is open.
  int _openDrain = 0;

  /// Opens a drain when a session is live (not while a start or a restart is
  /// still in flight, and not after the session already ended with a restart
  /// pending: neither has anything to finish). Called before the intent
  /// changes; the pending interim is kept for the flush. Returns the new
  /// drain's number, or null when none was opened.
  int? _beginDrain() {
    final live =
        _intent == _Intent.listening &&
        !_starting &&
        !_restartScheduled &&
        !_draining;
    if (!live) return null;
    _draining = true;
    _drainDeliveredFinal = false;
    _drainDone = Completer<void>();
    return _openDrain = ++_drainCount;
  }

  /// A plugin status arrived. Only `done` drives a restart (BR-U10-15).
  void onStatus(String status) {
    if (_draining) {
      if (status == SpeechToText.doneStatus) _endDrain();
      return;
    }
    if (_starting) {
      _held.add(() => onStatus(status));
      return;
    }
    if (status == SpeechToText.doneStatus) _onDone();
  }

  /// A plugin error arrived, classified by code and never by the plugin's
  /// `permanent` flag, which is always true (BR-U10-18).
  void onError(String code) {
    if (_draining) {
      // Any error ends the wait for the last phrase; it is not classified,
      // counted or reported (BR-U10-55).
      _endDrain();
      return;
    }
    if (_starting) {
      _held.add(() => onError(code));
      return;
    }
    if (_intent != _Intent.listening) return;

    final lasting = _lastingCodes[code];
    if (lasting != null) {
      _log.warning('Lasting engine error: ${lasting.name}');
      _intent = _Intent.failed;
      _timer?.cancel();
      _timer = null;
      _cancelPauseTimer();
      _restartScheduled = false;
      report(lasting);
      unawaited(cancelPlugin());
      return;
    }

    final errorClass = _silenceCodes.contains(code)
        ? _ErrorClass.silence
        : _ErrorClass.transient;
    if (errorClass.index > _worst.index) _worst = errorClass;
  }

  void _onDone() {
    // Stop, pause, a lasting error or the cap already won; or this session
    // end already scheduled its restart (error then done, duplicate done).
    if (_intent != _Intent.listening || _restartScheduled) return;

    _flushPendingInterim();
    // The plugin session has ended; any later result belongs to a new one.
    _committed.clear();

    final elapsed = now().difference(_startedAt);
    final fastAndEmpty =
        _worst == _ErrorClass.none &&
        !_deliveredResult &&
        elapsed < limits.immediateFailureWindow;
    final countsAsFailure = _worst == _ErrorClass.transient || fastAndEmpty;
    if (countsAsFailure && _countFailureReachedCap()) return;

    _scheduleRestart();
  }

  /// BR-U10-16: a pending interim is delivered once as final, on `done` only,
  /// before the restart is scheduled.
  void _flushPendingInterim() {
    final pending = _pendingInterim;
    if (pending == null) return;
    _pendingInterim = null;
    _cancelPauseTimer();
    _committed.addAll(_tokensOf(pending.text).map((t) => t.token));
    deliver(
      SttResult(
        text: pending.text,
        isFinal: true,
        confidence: pending.confidence,
        timestamp: now(),
        sourceId: pending.sourceId,
      ),
    );
  }

  /// Increment-then-compare. At the cap: report once and stop restarting.
  bool _countFailureReachedCap() {
    _failureCount++;
    if (_failureCount < limits.restartCap) return false;
    _log.warning('Restart cap reached');
    _intent = _Intent.failed;
    _restartScheduled = false;
    report(SttEngineErrorKind.restartCapReached);
    return true;
  }

  void _scheduleRestart() {
    _restartScheduled = true;
    _timer?.cancel();
    _timer = Timer(limits.restartDelay, () => unawaited(_restart()));
  }

  Future<void> _restart() async {
    _timer = null;
    if (_intent != _Intent.listening) return;
    final localeId = _localeId;
    if (localeId == null) return;

    // BR-U10-19: a stop, pause or dispose moves the epoch. Comparing it (not
    // the intent) also catches a pause followed by a resume, which would make
    // the intent look unchanged.
    final epoch = _epoch;
    final outcome = await listen(localeId, epoch);

    if (_epoch != epoch) {
      // Stop, pause or dispose won while the restart was in flight; the plugin
      // may already be listening again, so stop it. If a resume has since won
      // (intent listening again) or its listen() is in flight (`_starting`),
      // the plugin's one session is the user's: the plugin's cancel() ends
      // whatever session it has, so leave it, and leave its record alone.
      if (outcome == _ListenOutcome.started &&
          _intent != _Intent.listening &&
          !_starting) {
        await cancelPlugin();
      }
      return;
    }
    switch (outcome) {
      case _ListenOutcome.started:
        _restartStarted();
      case _ListenOutcome.refused:
        // The guard already reported the lasting error.
        abandonStarting();
        _intent = _Intent.failed;
        _restartScheduled = false;
      case _ListenOutcome.threw:
        // No session exists, so no `done` will follow: the throw is the
        // session end (BR-U10-30). The retry runs the guard again.
        abandonStarting();
        if (_countFailureReachedCap()) return;
        _scheduleRestart();
      case _ListenOutcome.superseded:
        // Only returned when the epoch moved, which is handled above.
        abandonStarting();
    }
  }

  /// Records the pause. Returns the number of the drain it opened, if any,
  /// which the caller must wait on and close.
  int? pauseRequested() {
    final drain = _beginDrain();
    _epoch++;
    _intent = _Intent.paused;
    abandonStarting();
    _cancelTimer();
    return drain;
  }

  /// Records the stop. Returns the number of the drain it opened, if any,
  /// which the caller must wait on and close. A stop that arrives while a
  /// pause's drain is open joins that drain instead (BR-U10-55): the last
  /// phrase is kept, and the first waiter to finish flushes it once.
  int? stopRequested() {
    final drain = _beginDrain() ?? (_draining ? _openDrain : null);
    _epoch++;
    _intent = _Intent.stopped;
    abandonStarting();
    _cancelTimer();
    // Without a drain nothing will flush the interim, so it is dropped.
    if (drain == null) _pendingInterim = null;
    return drain;
  }

  void dispose() {
    _epoch++;
    _intent = _Intent.stopped;
    abandonStarting();
    _cancelTimer();
    _pendingInterim = null;
    _endDrain();
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
    _cancelPauseTimer();
    _restartScheduled = false;
  }
}
