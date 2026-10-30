import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zip_core/src/constants/stt_listening_limits.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/stt/engines/segmented_recognizer_bridge.dart';
import 'package:zip_core/src/stt/on_device_support_checker.dart';
import 'package:zip_core/src/stt/stt_engine.dart';
import 'package:zip_core/src/stt/stt_error_source.dart';

/// Android's silent continuous engine (Amendment 03).
///
/// Wraps one platform segmented recogniser session per user start: Android
/// keeps listening for [SttListeningLimits.segmentedSessionLength] and sends
/// each phrase as a segment, so nothing has to restart on a pause in speech
/// and Android's per-session start/stop chime is heard only on a user action
/// or a renewal (BR-U10-43).
///
/// Implements [SttEngine] and the sibling capability [SttErrorSource]. The
/// platform side is injected as a [SegmentedRecognizerBridge], so the
/// contract stays in `zip_core` and the recogniser in the app's runner.
///
/// Rules this class implements (Amendment 03 section 4):
/// - BR-U10-37: one session per start, after the on-device check.
/// - BR-U10-38: partials are interim, segments are final and trimmed, an
///   empty segment is dropped, and a pending partial is not flushed: the
///   segment that follows it is its final.
/// - BR-U10-39: `endOfSession` while listening is the only renewal, and a
///   full-length one never counts towards the failure budget.
/// - BR-U10-40: silence codes 6 and 7 renew; 9, 12, 13, 14 and 15 are lasting
///   and report once; everything else, including an unknown code, is
///   transient and counts against the Amendment 01 cap.
/// - BR-U10-41: codes 5 and 11 recreate the recogniser before the retry.
/// - BR-U10-42: stop, pause and dispose win over every await (the epoch rule
///   of Amendment 01, BR-U10-19).
/// - BR-U10-44: an end before 90% of
///   [SttListeningLimits.segmentedSessionLength] is an early end, counted in
///   its own budget which only a user start or resume resets; the one that
///   reaches the cap reports `restartCapReached` once and stops.
/// - BR-U10-55: stop and pause wait up to
///   [SttListeningLimits.finalResultDrainTimeout] for the platform to finish
///   recognising the speech already captured, deliver it, and only then
///   return; nothing in the wait renews, counts or reports.
/// - BR-U10-45: every renewal waits `restartDelay` (a cancellable timer, as
///   in `PlatformSttEngine`) before checking and starting, and a refused or
///   throwing renewal is a transient failure that retries until the cap
///   reports: the engine never stops silently.
///
/// **Security (SECURITY-03)**: never logs, throws or stores recognised text
/// beyond the [SttResult] handed to the caller. Only kinds, codes and
/// booleans appear in logs.
class SegmentedSpeechEngine implements SttEngine, SttErrorSource {
  /// Creates a [SegmentedSpeechEngine].
  ///
  /// [onDeviceSupportChecker] is required so a build cannot forget the check
  /// that keeps recognition on the device (Amendment 02).
  SegmentedSpeechEngine({
    required SegmentedRecognizerBridge bridge,
    required OnDeviceSupportChecker onDeviceSupportChecker,
    SttListeningLimits limits = defaultSttListeningLimits,
    DateTime Function() now = DateTime.now,
  }) : _bridge = bridge,
       _checker = onDeviceSupportChecker,
       _limits = limits,
       _now = now {
    _subscription = bridge.events.listen(
      _onEvent,
      onError: (Object _) {
        // The same guard as `_onEvent`: a channel error after a stop or a
        // pause, or while a start is in flight, belongs to no session anyone
        // asked for and must not count or renew.
        if (_draining) {
          // Nothing more will come from a broken channel, so the wait for the
          // last phrase is over (BR-U10-55); nothing is counted.
          _endDrain();
          return;
        }
        if (_intent != _Intent.listening || !_sessionLive) return;
        // A broken channel is a transient failure of the session in flight:
        // treat it as an error without a code.
        _onTransientError();
      },
    );
  }

  static final _log = Logger('zip_core.SegmentedSpeechEngine');

  static const _engineIdValue = 'platform';
  static const _displayNameValue = 'On-device Speech Recognition';

  final SegmentedRecognizerBridge _bridge;
  final OnDeviceSupportChecker _checker;
  final SttListeningLimits _limits;
  final DateTime Function() _now;
  late final StreamSubscription<SegmentedRecognizerEvent> _subscription;

  void Function(SttEngineError error)? _errorListener;
  void Function(SttResult)? _onResult;
  String? _localeId;
  bool _initialized = false;

  _Intent _intent = _Intent.idle;

  /// Moves on every stop, pause or dispose (BR-U10-19, BR-U10-42). A guarded
  /// call captures it before its awaits and abandons the attempt if it moved.
  int _epoch = 0;

  // The two counted budgets (Amendment 01 cap, Amendment 03 early ends), kept
  // in one helper so the engine holds only the session flow.
  late final _RenewalBudget _budget = _RenewalBudget(_limits, _now);

  /// The worst class seen in the session in flight.
  _ErrorClass _worst = _ErrorClass.none;

  /// Whether a renewal is scheduled or in flight, so a repeated end of
  /// session or silence code cannot start two sessions.
  bool _renewing = false;

  /// The BR-U10-45 renewal wait. Cancellable: `stopListening`, `pause` and
  /// `dispose` cancel it, as `PlatformSttEngine` cancels its restart timer.
  Timer? _renewTimer;

  /// Whether the code 5 or 11 recreate has run for the session in flight, so
  /// a repeat of the same code retries without recreating again.
  bool _recreatedForSession = false;

  /// Whether a session has begun since the last start, stop, pause or dispose.
  /// While it is `false` the bridge's events belong to a superseded session
  /// and are dropped.
  bool _sessionLive = false;

  /// Whether a stop or a pause is waiting for the platform to finish
  /// recognising the speech it already captured (BR-U10-55). While it is
  /// `true` the bridge's events are read by [_onDrainEvent] only.
  bool _draining = false;

  /// Completed when the drain ends: a final segment, the end of the session,
  /// an error, or the deadline.
  Completer<void>? _drainDone;

  /// Whether a final segment was delivered during the drain.
  bool _drainDeliveredFinal = false;

  /// The latest partial of the session in flight (cleared by a segment or a
  /// new session). Held in memory only, never logged (SECURITY-03), so the
  /// drain can deliver it as final when the platform sends no final
  /// (the BR-U10-16 flush).
  String? _pendingPartial;

  @override
  String get engineId => _engineIdValue;

  @override
  String get displayName => _displayNameValue;

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
    // The recogniser is created by the bridge's first start, so there is
    // nothing to prepare; used only to report availability.
    try {
      _initialized = true;
      _log.info('Segmented engine initialized');
      return true;
    } on Object catch (e) {
      _log.severe('Initialize error: ${e.runtimeType}');
      return false;
    }
  }

  @override
  Future<bool> isAvailable() async {
    if (!_initialized) await initialize();
    return _initialized;
  }

  @override
  Future<List<SpeechLocale>> supportedLocales() async {
    // BR-U10-50: the bridge's on-device languages, so Settings can list them.
    // A failure is an empty list and the resolver falls back (Amendment 03
    // section 6).
    try {
      final tags = await _bridge.supportedLocales();
      return tags
          .map((tag) => SpeechLocale(localeId: tag, displayName: tag))
          .toList();
    } on Object catch (e) {
      _log.warning('supportedLocales error: ${e.runtimeType}');
      return [];
    }
  }

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    _localeId = localeId;
    _onResult = onResult;
    final epoch = ++_epoch;
    _intent = _Intent.listening;
    _sessionLive = false;
    // A user start (and `resume`, which calls this) owns the session now:
    // drop any pending renewal and start both budgets fresh (BR-U10-44).
    _cancelRenewal();
    _budget.onUserStart();

    final allowed = await _onDeviceAllowed(localeId);
    if (_epoch != epoch) return false;
    if (!allowed) {
      // BR-U10-27, unchanged: refuse, no session, one lasting error.
      _report(SttEngineErrorKind.onDeviceModelMissing);
      _intent = _Intent.failed;
      return false;
    }

    final started = await _startSession(localeId);
    if (!started) {
      if (_epoch == epoch) _intent = _Intent.failed;
      return false;
    }
    if (_epoch != epoch) {
      // A stop or pause arrived while the start was in flight: the session
      // may already be listening, so it is cancelled here.
      await _cancelQuietly();
      return false;
    }
    return true;
  }

  /// Asks the checker, failing closed: an exception or a timeout is
  /// "unsupported". Logs the boolean only.
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

  /// Starts one bridged session and resets the per-session record.
  Future<bool> _startSession(String localeId) async {
    final minimumLengthMs = _limits.segmentedSessionLength.inMilliseconds;
    try {
      final started = await _bridge.start(
        localeId: localeId,
        minimumLengthMs: minimumLengthMs,
      );
      if (started) {
        _beginSession();
        _log.info(
          'Segmented session started for $localeId, '
          'lengthMs=$minimumLengthMs',
        );
      } else {
        _log.warning('Segmented session refused');
        _countFailure();
      }
      return started;
    } on Object catch (e) {
      // The exception's message is never inspected or logged.
      _log.severe('Start error: ${e.runtimeType}');
      await _cancelQuietly();
      _countFailure();
      return false;
    }
  }

  void _beginSession() {
    _sessionLive = true;
    _worst = _ErrorClass.none;
    _recreatedForSession = false;
    _renewing = false;
    _pendingPartial = null;
    // BR-U10-44: the early-end test is measured from the session's own start.
    _budget.onSessionStarted();
  }

  void _onEvent(SegmentedRecognizerEvent event) {
    // BR-U10-55: after a stop or a pause the platform still finishes the
    // speech it captured; only that is accepted, and only until the drain
    // ends.
    if (_draining) {
      _onDrainEvent(event);
      return;
    }
    // Events for a session nobody asked for (after stop, pause or dispose)
    // are dropped, so a trailing segment cannot reach a stopped session.
    // Likewise for a session that has not begun since the last start, stop or
    // pause: a late end or error from the previous session must not renew or
    // count while a start or resume is still in flight.
    if (_intent != _Intent.listening || !_sessionLive) return;
    switch (event) {
      case SegmentedReady():
        break;
      case SegmentedPartial(:final text):
        _pendingPartial = text;
        _deliver(text, isFinal: false);
      case SegmentedSegment(:final text):
        // BR-U10-38: trim, drop an empty one, deliver once as final.
        final trimmed = text.trim();
        if (trimmed.isEmpty) return;
        _pendingPartial = null;
        _deliver(trimmed, isFinal: true);
      case SegmentedEndOfSession():
        _onEndOfSession();
      case SegmentedError(:final code):
        _onErrorCode(code);
    }
  }

  void _deliver(String text, {required bool isFinal}) {
    // Recognised speech resets the transient budget only: BR-U10-44 keeps the
    // early-end count through delivered results.
    _budget.onDeliveredResult();
    _worst = _ErrorClass.none;
    _emit(text, isFinal: isFinal);
  }

  /// Hands one result to the app without touching the budgets, so a drained
  /// result (BR-U10-55) never counts, resets or renews anything.
  void _emit(String text, {required bool isFinal}) {
    _onResult?.call(
      SttResult(
        text: text,
        isFinal: isFinal,
        // The segmented API reports no confidence; 1.0 is the documented
        // "not reported" value (SttResult.confidence).
        confidence: 1,
        timestamp: _now(),
        sourceId: engineId,
      ),
    );
  }

  /// BR-U10-39 and BR-U10-44: an end of session renews the session, checked
  /// first and after `restartDelay`. A full-length end is the only silent
  /// renewal (a chime at most once per
  /// [SttListeningLimits.segmentedSessionLength], BR-U10-43); an early one
  /// is counted in its own budget and the one that reaches the cap reports
  /// `restartCapReached` and stops.
  void _onEndOfSession() {
    final localeId = _localeId;
    if (localeId == null || _renewing) return;
    if (_budget.onSessionEnd()) {
      _log.warning('Early-end cap reached');
      _intent = _Intent.failed;
      _report(SttEngineErrorKind.restartCapReached);
      return;
    }
    _log.info('Segment session ended, renewing');
    _scheduleRenewal(_epoch);
  }

  /// BR-U10-45: the renewal waits `restartDelay`, then checks and starts.
  void _scheduleRenewal(int epoch) {
    if (_renewing) return;
    _renewing = true;
    _renewTimer?.cancel();
    _renewTimer = Timer(
      _limits.restartDelay,
      () => unawaited(_runRenewal(epoch)),
    );
  }

  Future<void> _runRenewal(int epoch) async {
    _renewTimer = null;
    if (_epoch != epoch || _intent != _Intent.listening) {
      _renewing = false;
      return;
    }
    final localeId = _localeId;
    if (localeId == null) {
      _renewing = false;
      return;
    }
    final allowed = await _onDeviceAllowed(localeId);
    if (_epoch != epoch || _intent != _Intent.listening) {
      _renewing = false;
      return;
    }
    if (!allowed) {
      _renewing = false;
      _report(SttEngineErrorKind.onDeviceModelMissing);
      _intent = _Intent.failed;
      return;
    }
    final started = await _startSession(localeId);
    if (_epoch != epoch || _intent != _Intent.listening) {
      _renewing = false;
      if (started) await _cancelQuietly();
      return;
    }
    // On success `_beginSession` already cleared `_renewing`. A refusal or a
    // throw was counted by `_startSession`; below the cap the engine retries
    // after another delay (BR-U10-45: it never stops silently), at the cap
    // the count already reported `restartCapReached` and moved to failed.
    if (started) return;
    _renewing = false;
    if (_intent != _Intent.listening) return;
    _scheduleRenewal(epoch);
  }

  void _cancelRenewal() {
    _renewTimer?.cancel();
    _renewTimer = null;
    _renewing = false;
  }

  /// BR-U10-40 and BR-U10-41: classify the code and act.
  void _onErrorCode(int code) {
    final lasting = _lastingCodes[code];
    if (lasting != null) {
      _log.warning('Lasting engine error: ${lasting.name} (code $code)');
      _intent = _Intent.failed;
      _report(lasting);
      unawaited(_cancelQuietly());
      return;
    }
    if (_silenceCodes.contains(code)) {
      // BR-U10-39: a session renewal is a normal end.
      _log.info('Silence code $code, renewing');
      _onEndOfSession();
      return;
    }
    _onTransientError(errorClass: _ErrorClass.transient, errorCode: code);
  }

  /// A transient failure: count it, recreate for a dead service, then renew.
  void _onTransientError({_ErrorClass? errorClass, int? errorCode}) {
    if (errorClass != null && errorClass.index > _worst.index) {
      _worst = errorClass;
    }
    _log.info('Transient engine error (code ${errorCode ?? 'none'})');
    // Count first (BR-U10-40, BR-U10-45): a service that keeps dying after
    // each successful start must reach the cap, so the failure that reaches it
    // reports and stops without a further recreate.
    if (_countFailure()) return;
    final recreate = errorCode != null && _recreateCodes.contains(errorCode);
    if (recreate && !_recreatedForSession) {
      _recreatedForSession = true;
      // BR-U10-41: destroy and create the recogniser before retrying, so a
      // restarted system service is used rather than a stale binding.
      unawaited(
        _recreateThenRenew(_epoch),
      );
      return;
    }
    _scheduleRenewal(_epoch);
  }

  Future<void> _recreateThenRenew(int epoch) async {
    await _recreateQuietly();
    if (_epoch != epoch || _intent != _Intent.listening) return;
    _scheduleRenewal(epoch);
  }

  Future<void> _recreateQuietly() async {
    try {
      await _bridge.recreate();
      _log.info('Recogniser recreated');
    } on Object catch (e) {
      _log.warning('Recreate error: ${e.runtimeType}');
    }
  }

  /// Increment-then-compare (Amendment 01, BR-U10-40 and BR-U10-45): at the
  /// cap, report once and stop.
  ///
  /// Returns `true` when the cap was reached.
  bool _countFailure() {
    if (!_budget.countTransientFailure()) return false;
    _log.warning('Restart cap reached');
    _intent = _Intent.failed;
    _report(SttEngineErrorKind.restartCapReached);
    return true;
  }

  Future<void> _cancelQuietly() async {
    try {
      await _bridge.cancel();
    } on Object catch (e) {
      _log.warning('Cancel error: ${e.runtimeType}');
    }
  }

  void _report(SttEngineErrorKind kind) {
    _log.warning('Reporting engine error: ${kind.name}');
    _errorListener?.call(SttEngineError(kind));
  }

  /// Opens the BR-U10-55 drain when a session is live, before the intent
  /// changes. Returns whether one was opened: with no live session there is
  /// nothing to wait for.
  bool _beginDrain() {
    final live = _intent == _Intent.listening && _sessionLive;
    if (!live || _draining) return false;
    _draining = true;
    _drainDeliveredFinal = false;
    _drainDone = Completer<void>();
    return true;
  }

  /// Waits for the drain to end (a final segment, the end of the session, an
  /// error or `finalResultDrainTimeout`), then flushes a pending partial as
  /// final once if no final arrived (BR-U10-16). Always leaves the drain
  /// closed, so a later event is dropped as before.
  Future<void> _awaitDrain() async {
    final done = _drainDone;
    if (done == null) return;
    final timer = Timer(_limits.finalResultDrainTimeout, _endDrain);
    try {
      await done.future;
    } finally {
      timer.cancel();
      final pending = _pendingPartial?.trim();
      _pendingPartial = null;
      if (!_drainDeliveredFinal && pending != null && pending.isNotEmpty) {
        _emit(pending, isFinal: true);
      }
      _closeDrain();
    }
  }

  void _closeDrain() {
    _draining = false;
    _drainDone = null;
  }

  void _endDrain() {
    final done = _drainDone;
    if (done != null && !done.isCompleted) done.complete();
  }

  /// BR-U10-55: during a drain only a segment or a partial is accepted. The
  /// first non-empty segment is delivered as final and ends the wait; a
  /// partial is remembered, not shown; the end of the session or an error
  /// ends the wait. Nothing is counted, renewed or reported.
  void _onDrainEvent(SegmentedRecognizerEvent event) {
    switch (event) {
      case SegmentedReady():
        break;
      case SegmentedPartial(:final text):
        if (!_drainDeliveredFinal) _pendingPartial = text;
      case SegmentedSegment(:final text):
        final trimmed = text.trim();
        if (trimmed.isEmpty || _drainDeliveredFinal) return;
        _drainDeliveredFinal = true;
        _pendingPartial = null;
        _emit(trimmed, isFinal: true);
        _endDrain();
      case SegmentedEndOfSession():
      case SegmentedError():
        _endDrain();
    }
  }

  @override
  Future<void> stopListening() async {
    // Intent first, then the platform, so a trailing event never renews.
    final drain = _beginDrain();
    _epoch++;
    _intent = _Intent.stopped;
    _sessionLive = false;
    _cancelRenewal();
    try {
      await _bridge.stop();
      _log.info('Segmented session stopped');
      if (drain) await _awaitDrain();
    } on Object catch (e) {
      _log.warning('Stop error: ${e.runtimeType}');
    } finally {
      // A throwing stop skipped the wait: close the drain all the same.
      if (drain) _closeDrain();
    }
    // BR-U10-55: a stop ends with the platform session cancelled, unless a
    // new start has begun meanwhile (Amendment 06 revision 3): the cancel
    // would end that session.
    if (_intent == _Intent.stopped) await _cancelQuietly();
  }

  @override
  Future<bool> pause() async {
    final drain = _beginDrain();
    _epoch++;
    _intent = _Intent.paused;
    _sessionLive = false;
    _cancelRenewal();
    try {
      await _bridge.stop();
      _log.info('Paused (via stop)');
      if (drain) await _awaitDrain();
      return true;
    } on Object catch (e) {
      _log.warning('Pause error: ${e.runtimeType}');
      return false;
    } finally {
      if (drain) _closeDrain();
    }
  }

  @override
  Future<bool> resume() async {
    if (_intent != _Intent.paused || _localeId == null || _onResult == null) {
      return false;
    }
    // BR-U10-42: a resume is a user action, so a new checked session (and its
    // chime) is expected.
    return startListening(localeId: _localeId!, onResult: _onResult!);
  }

  @override
  void dispose() {
    _epoch++;
    _intent = _Intent.stopped;
    _sessionLive = false;
    _cancelRenewal();
    _endDrain();
    unawaited(_subscription.cancel());
    unawaited(_cancelQuietly());
    unawaited(_disposeBridge());
    _onResult = null;
    _errorListener = null;
  }

  Future<void> _disposeBridge() async {
    try {
      await _bridge.dispose();
      _log.info('Segmented engine disposed');
    } on Object catch (e) {
      _log.warning('Dispose error: ${e.runtimeType}');
    }
  }
}

/// What the engine is doing.
enum _Intent { idle, listening, paused, stopped, failed }

/// How a non-lasting error is handled. Ordered by severity so the worst class
/// seen in the session in flight can be kept (Amendment 01, section 4.1).
enum _ErrorClass { none, transient }

/// Silence is a normal end: the session renews, and it is never counted.
const _silenceCodes = {6, 7};

/// Lasting: report once, then `failed` (BR-U10-40). These are Android's
/// `ERROR_*` codes from Amendment 03 section 1.
const _lastingCodes = <int, SttEngineErrorKind>{
  9: SttEngineErrorKind.permissionRevoked,
  12: SttEngineErrorKind.localeUnsupported,
  13: SttEngineErrorKind.onDeviceModelMissing,
  14: SttEngineErrorKind.onDeviceModelMissing,
  15: SttEngineErrorKind.onDeviceModelMissing,
};

/// BR-U10-41: a client or server connection died, so the recogniser is
/// recreated before the retry (O-3).
const _recreateCodes = {5, 11};

/// The two budgets a segmented session is judged by, apart from the session
/// flow itself. Kept out of [SegmentedSpeechEngine] so the engine reads as
/// one state machine:
///
/// - the Amendment 01 transient-failure count: increment-then-compare, reset
///   by a delivered result and by a user start;
/// - the BR-U10-44 early-end count (decision D-4): an end that arrives
///   before 90% of [SttListeningLimits.segmentedSessionLength] since the
///   session began is counted on its own, is reset only by a user start or
///   resume — never by recognised speech and never by a successful renewal —
///   and the count that reaches the cap stops the engine.
final class _RenewalBudget {
  _RenewalBudget(this._limits, this._now);

  final SttListeningLimits _limits;
  final DateTime Function() _now;

  int _failureCount = 0;
  int _earlyEndCount = 0;
  DateTime? _sessionStartedAt;

  /// A user `startListening` or `resume`: both budgets start fresh.
  void onUserStart() {
    _failureCount = 0;
    _earlyEndCount = 0;
  }

  /// A delivered result resets the transient count only: recognised speech
  /// does not excuse a recogniser that ends sessions early (BR-U10-44).
  void onDeliveredResult() => _failureCount = 0;

  /// Records the start of the session now in flight, against which the next
  /// end is judged.
  void onSessionStarted() => _sessionStartedAt = _now();

  /// Classifies an end of session. An end before 90% of
  /// [SttListeningLimits.segmentedSessionLength] — or with no recorded
  /// session start, which cannot be proven full-length — is an early end and
  /// counts. Returns `true` when this early end reaches the cap, in which
  /// case the caller reports `restartCapReached` once and stops renewing.
  bool onSessionEnd() {
    final startedAt = _sessionStartedAt;
    if (startedAt == null) {
      _earlyEndCount++;
      return _earlyEndCount >= _limits.restartCap;
    }
    final threshold = _limits.segmentedSessionLength * 0.9;
    if (_now().difference(startedAt) >= threshold) return false;
    _earlyEndCount++;
    return _earlyEndCount >= _limits.restartCap;
  }

  /// Counts one transient failure or refused renewal (BR-U10-40, BR-U10-45).
  /// Increment-then-compare: returns `true` at the cap.
  bool countTransientFailure() {
    _failureCount++;
    return _failureCount >= _limits.restartCap;
  }
}
