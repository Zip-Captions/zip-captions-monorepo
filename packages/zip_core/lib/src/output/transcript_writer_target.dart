import 'dart:async';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/transcript_save_result.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/src/models/transcript_settings.dart';
import 'package:zip_core/src/output/transcript_repository.dart';
import 'package:zip_core/src/services/caption/caption_output_target.dart';

/// Caption output target that persists transcript segments immediately.
///
/// Implements [CaptionOutputTarget] to receive events from the
/// `CaptionOutputTargetRegistry`. Each finalized [SttResultEvent] is
/// persisted via `repository.saveSegment()` within a 2-second merge
/// window per `sourceId` (NFR REL-U3.3).
///
/// **The session row is lazy** (Amendment 03 section 7, Q-2): no row is
/// created at session start. The start time is remembered, and the row is
/// created — with that start date — immediately before the first segment is
/// saved, chained so a segment can never precede its row. A session that
/// ends without a single saved segment therefore leaves no transcript
/// behind, even if the app is killed mid-session.
///
/// **A re-published [RecordingActiveState] with the same sessionId is a
/// continuation** (Amendment 03 section 8, Q-4): the notifier republishes it
/// on resume and after the REL-U2.1 recovery, and continuing keeps the start
/// time, the segment count and the merge state and creates nothing. A
/// different sessionId is a new session.
class TranscriptWriterTarget implements CaptionOutputTarget {
  /// Creates a [TranscriptWriterTarget].
  ///
  /// [now] overrides the wall-clock source; defaults to [DateTime.now].
  /// Inject a fake clock in tests to control merge-window timing.
  TranscriptWriterTarget({
    required TranscriptRepository repository,
    required TranscriptSettings settings,
    DateTime Function()? now,
    void Function()? onSessionStarted,
  }) : _repository = repository,
       _settings = settings,
       _now = now ?? DateTime.now,
       _onSessionStarted = onSessionStarted;

  final TranscriptRepository _repository;
  final TranscriptSettings _settings;
  final DateTime Function() _now;
  // Called when a new session starts, so the previous session's save outcome
  // is forgotten (the callback carries nothing: the outcome is "unknown").
  final void Function()? _onSessionStarted;

  final _lastFinalBySource = <String, TranscriptSegment>{};
  // Session-relative ms when the first interim result for an utterance arrived.
  // Consumed and cleared when the corresponding final result is processed.
  final _pendingStartBySource = <String, int>{};
  String? _sessionId;
  DateTime? _sessionStartAt;
  int? _sessionStartMs;
  int _totalSegmentCount = 0;
  // The repository row of the current session: null until the first segment
  // asks for it (Q-2). Its `created` flag turns true only when the create step
  // succeeds, so a failed create is never reported as saved. Each session has
  // its own mark, so a finalise queued behind the chain still sees the outcome
  // of its own session's create after the next session has begun.
  _RowMark? _row;

  // The one chain of writes for a session: the lazy create, every save,
  // every merge and the finalise. Each step is stamped with the chain length
  // when it is appended and starts synchronously as soon as every earlier
  // step has completed. Segments are upserted by id, so a write that overtook
  // an earlier one could overwrite merged text with the shorter original.
  // Each step catches its own failure, so one failed write does not block the
  // writes after it. Awaiting the chain waits for every step appended so far.
  Future<void> _writes = Future<void>.value();
  bool _drainRunning = false;
  final _chain = <Future<void> Function()>[];

  static const _targetIdValue = 'transcript_writer';
  static const _mergeWindowMs = 2000;
  static const _uuid = Uuid();
  static final _log = Logger('zip_core.TranscriptWriterTarget');

  @override
  String get targetId => _targetIdValue;

  @override
  void onCaptionEvent(CaptionEvent event) {
    switch (event) {
      case SttResultEvent():
        if (event.result.isFinal) {
          _handleFinalResult(event);
        } else {
          _handleInterimResult(event);
        }
      case SessionStateEvent():
        _handleSessionState(event.state);
    }
  }

  /// Finalizes the current session by persisting duration and segment count.
  ///
  /// Must be called before [StoppedState] is published so that callers can
  /// await completion. Clears session state immediately so any subsequent
  /// [StoppedState] delivery via the caption bus is a safe no-op.
  ///
  /// Returns how the session turned out (Q-2, BR-U10-60):
  /// [TranscriptSaveResult.nothingRecognised] when it never reached its first
  /// segment (no row to finalize, nothing is called on the repository),
  /// [TranscriptSaveResult.saved] when the row was created and at least one
  /// segment save or merge succeeded, and [TranscriptSaveResult.saveFailed]
  /// otherwise. The caller (the provider's stop callback) publishes the
  /// outcome for `RecordingScreen`.
  Future<TranscriptSaveResult> finalizeCurrentSession() async {
    if (_sessionId == null) return TranscriptSaveResult.nothingRecognised;
    final sessionId = _sessionId!;
    final row = _row;
    final durationMs = _sessionStartMs == null
        ? 0
        : _now().millisecondsSinceEpoch - _sessionStartMs!;
    final segmentCount = _totalSegmentCount;
    _lastFinalBySource.clear();
    _pendingStartBySource.clear();
    _sessionId = null;
    _sessionStartAt = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
    _row = null;
    if (row == null) {
      // Q-2: nothing was ever saved, so there is no row to finalize.
      _log.fine(
        'finalizeCurrentSession: sessionId=$sessionId skipped, no row',
      );
      return TranscriptSaveResult.nothingRecognised;
    }
    _log.fine(
      'finalizeCurrentSession: sessionId=$sessionId'
      ' durationMs=$durationMs segmentCount=$segmentCount',
    );
    // Appended to the chain (Q-2, Step 29b): the finalise runs after every
    // save still in flight, and awaiting the chain means the caller's await
    // covers those writes too.
    _appendWrite(() async {
      if (!row.created) return;
      await _repository.finalizeSession(
        sessionId,
        durationMs: durationMs,
        segmentCount: segmentCount,
      );
    });
    await _writes;
    // Every save ran ahead of this step in the chain, so the outcome is known.
    return row.succeeded
        ? TranscriptSaveResult.saved
        : TranscriptSaveResult.saveFailed;
  }

  @override
  void dispose() {
    _lastFinalBySource.clear();
    _pendingStartBySource.clear();
    _sessionId = null;
    _sessionStartAt = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
    _row = null;
  }

  void _handleInterimResult(SttResultEvent event) {
    if (!_settings.captureEnabled || _sessionId == null) return;
    final sourceId = event.result.sourceId;
    // Record the start of a new utterance the first time an interim result
    // arrives for this source. Subsequent interim results for the same
    // utterance are no-ops here; the value is consumed by the final result.
    _pendingStartBySource.putIfAbsent(
      sourceId,
      () => _now().millisecondsSinceEpoch - _sessionStartMs!,
    );
  }

  void _handleFinalResult(SttResultEvent event) {
    if (!_settings.captureEnabled || _sessionId == null) return;
    final result = event.result;
    final sourceId = result.sourceId;
    final prior = _lastFinalBySource[sourceId];
    final now = _now().millisecondsSinceEpoch;
    final sessionStart = _sessionStartMs!;
    // Consume the pending start captured by the first interim result.
    // Falls back to the finalization time if no interim results were seen
    // (e.g. engines that emit finals directly without interim results).
    final startMs =
        _pendingStartBySource.remove(sourceId) ?? (now - sessionStart);

    if (prior != null &&
        (now - (sessionStart + prior.endTimeMs)) <= _mergeWindowMs) {
      // Within merge window: extend the existing segment in-place.
      // startTimeMs of the prior segment is preserved intentionally.
      final merged = prior.copyWith(
        text: '${prior.text} ${result.text}',
        endTimeMs: now - sessionStart,
      );
      _lastFinalBySource[sourceId] = merged;
      _log.fine(
        'saveSegment (merge): sessionId=$_sessionId'
        ' segmentId=${merged.segmentId}',
      );
      // A merge always follows a segment that already asked for the row.
      final sessionId = _sessionId!;
      final row = _row;
      _appendWrite(() async {
        // No row, no segment: the foreign key would reject it.
        if (row == null || !row.created) return;
        await _repository.saveSegment(sessionId, merged);
        // A merge that succeeds counts as a save (BR-U10-60): the text is in.
        row.segmentSaved = true;
      });
    } else {
      // New segment: gap > 2s or no prior segment for this source.
      final segment = TranscriptSegment(
        segmentId: _uuid.v4(),
        sessionId: _sessionId!,
        text: result.text,
        sourceId: sourceId,
        startTimeMs: startMs,
        endTimeMs: now - sessionStart,
      );
      _lastFinalBySource[sourceId] = segment;
      _totalSegmentCount++;
      _log.fine(
        'saveSegment (new): sessionId=$_sessionId'
        ' segmentId=${segment.segmentId}',
      );
      _saveNewSegment(segment);
    }
  }

  /// Saves a brand-new segment, creating the session row first when this is
  /// the first one (Q-2). Both go through the session's write chain, so the
  /// segment never reaches the repository before its row and never overtakes
  /// an earlier write.
  void _saveNewSegment(TranscriptSegment segment) {
    final sessionId = _sessionId!;
    final existing = _row;
    if (existing != null) {
      _appendWrite(() => _saveAndMark(existing, sessionId, segment));
      return;
    }
    final row = _row = _RowMark();
    final startedAt = _sessionStartAt ?? _now();
    // The create and its save are two steps, so the save starts only once
    // the create has completed, in that order, and nothing else can slip
    // between them. The row counts as created only if the create succeeds;
    // it is not retried. Without it no segment is written (the foreign key
    // would reject every one), the session is reported as not saved and it
    // is not finalised. A failed write still never blocks the ones after it.
    _appendWrite(() async {
      await _repository.createSession(sessionId, startedAt);
      row.created = true;
    });
    // A merge cannot precede the first save of the same segment, and the
    // save is appended after the create in the same turn, so this save runs
    // after the create completes.
    _appendWrite(() => _saveAndMark(row, sessionId, segment));
  }

  /// Saves [segment] and, only when the repository accepts it, records that
  /// the session has at least one saved segment (BR-U10-60). A failure
  /// propagates to the chain, which logs its type. Skipped when the row was
  /// never created, since the foreign key would reject the segment.
  Future<void> _saveAndMark(
    _RowMark row,
    String sessionId,
    TranscriptSegment segment,
  ) async {
    if (!row.created) return;
    await _repository.saveSegment(sessionId, segment);
    row.segmentSaved = true;
  }

  /// Appends [step] to the session's ordered write chain.
  ///
  /// **The order is fixed when the write is appended, and a write handed to
  /// the repository in the same turn still starts in that turn** (Step 29b).
  /// Two measured constraints shape this:
  /// - a plain `.then(step)` chain starts a step in a later microtask, so a
  ///   merge appended in the same turn would overtake the first save, and
  ///   the store (which upserts by id) would keep the shorter original;
  /// - anything the step's *start* — building a mapper, or the repository's
  ///   own dispatch — reads from the clock must read it in the caller's
  ///   turn, or `fakeAsync` hands the step a time that has not elapsed yet
  ///   and every fake-clock test sees a write out of order.
  /// So a step for which no predecessor is still running starts now, and a
  /// step appended behind a running one is started by that predecessor's
  /// completion, in order. [_writes] always holds the tail, so awaiting the
  /// chain waits for every step appended so far.
  void _appendWrite(Future<void> Function() step) {
    if (_drainRunning) {
      _chain.add(step);
      return;
    }
    _drainRunning = true;
    _writes = _drain(step);
  }

  /// Starts [first] now, then every step appended while it ran, in order.
  Future<void> _drain(Future<void> Function() first) async {
    var next = first;
    while (true) {
      await _runStep(next);
      if (_chain.isEmpty) break;
      next = _chain.removeAt(0);
    }
    _drainRunning = false;
  }

  /// Runs one step; a failure is logged by type only and does not stop the
  /// steps after it.
  Future<void> _runStep(Future<void> Function() step) async {
    try {
      await step();
    } on Object catch (e) {
      _log.severe('repository write failed: ${e.runtimeType}');
    }
  }

  void _handleSessionState(RecordingState state) {
    switch (state) {
      case RecordingActiveState():
        if (state.sessionId == _sessionId) {
          // Q-4: the same session was republished (resume, REL-U2.1
          // recovery). A continuation keeps the start, the count and the
          // merge state, and creates nothing.
          _log.fine(
            'session continued: sessionId=${state.sessionId}',
          );
          return;
        }
        // A different sessionId is a new session. No row is created here
        // (Q-2): laziness also means a session that never captions anything
        // leaves nothing behind, even if the app is killed mid-session.
        // Q-2 (Step 29b follow-up): a new session starts with no outcome, so
        // the previous session's is forgotten here. The target owns the
        // outcome's lifetime; the screen only reads it (a provider write from
        // the screen's Stopped listener re-created the provider's notifier and
        // threw `LateInitializationError`).
        _onSessionStarted?.call();
        _sessionId = state.sessionId;
        _sessionStartAt = _now();
        _sessionStartMs = _sessionStartAt!.millisecondsSinceEpoch;
        _lastFinalBySource.clear();
        _pendingStartBySource.clear();
        _totalSegmentCount = 0;
        _row = null;
        _log.fine(
          'session started: sessionId=${state.sessionId}',
        );
      case StoppedState():
        _handleSessionStopped();
      case IdleState():
        _sessionId = null;
        _sessionStartAt = null;
        _sessionStartMs = null;
        _lastFinalBySource.clear();
        _pendingStartBySource.clear();
        _totalSegmentCount = 0;
        _row = null;
      case PausedState() || ReconnectingState():
        break;
    }
  }

  void _handleSessionStopped() {
    if (_sessionId == null) return;
    final row = _row;
    if (row == null) {
      // Q-2: zero segments means no row — nothing is created, finalized or
      // deleted. Just drop the session state.
      _log.fine(
        'finalizeSession skipped (no row): sessionId=$_sessionId',
      );
      _lastFinalBySource.clear();
      _pendingStartBySource.clear();
      _sessionId = null;
      _sessionStartAt = null;
      _sessionStartMs = null;
      _totalSegmentCount = 0;
      return;
    }
    final durationMs = _sessionStartMs == null
        ? 0
        : _now().millisecondsSinceEpoch - _sessionStartMs!;
    _log.fine(
      'finalizeSession: sessionId=$_sessionId'
      ' durationMs=$durationMs segmentCount=$_totalSegmentCount',
    );
    final sessionId = _sessionId!;
    final segmentCount = _totalSegmentCount;
    _appendWrite(() async {
      if (!row.created) return;
      await _repository.finalizeSession(
        sessionId,
        durationMs: durationMs,
        segmentCount: segmentCount,
      );
    });
    _lastFinalBySource.clear();
    _pendingStartBySource.clear();
    _sessionId = null;
    _sessionStartAt = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
    _row = null;
  }
}

/// What one session's repository writes have achieved so far. Mutable, and
/// shared by the steps queued for that session.
class _RowMark {
  /// Whether the create step succeeded.
  bool created = false;

  /// Whether at least one segment save or merge succeeded (BR-U10-60).
  bool segmentSaved = false;

  /// The session counts as saved only with a row and a saved segment.
  bool get succeeded => created && segmentSaved;
}
