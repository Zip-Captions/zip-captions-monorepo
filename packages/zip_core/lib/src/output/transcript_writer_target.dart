import 'dart:async';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
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
class TranscriptWriterTarget implements CaptionOutputTarget {
  /// Creates a [TranscriptWriterTarget].
  ///
  /// [now] overrides the wall-clock source; defaults to [DateTime.now].
  /// Inject a fake clock in tests to control merge-window timing.
  TranscriptWriterTarget({
    required TranscriptRepository repository,
    required TranscriptSettings settings,
    DateTime Function()? now,
  })  : _repository = repository,
        _settings = settings,
        _now = now ?? DateTime.now;

  final TranscriptRepository _repository;
  final TranscriptSettings _settings;
  final DateTime Function() _now;

  final _lastFinalBySource = <String, TranscriptSegment>{};
  // Session-relative ms when the first interim result for an utterance arrived.
  // Consumed and cleared when the corresponding final result is processed.
  final _pendingStartBySource = <String, int>{};
  String? _sessionId;
  int? _sessionStartMs;
  int _totalSegmentCount = 0;

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
  Future<void> finalizeCurrentSession() async {
    if (_sessionId == null) return;
    final sessionId = _sessionId!;
    final durationMs = _sessionStartMs == null
        ? 0
        : _now().millisecondsSinceEpoch - _sessionStartMs!;
    final segmentCount = _totalSegmentCount;
    _log.fine(
      'finalizeCurrentSession: sessionId=$sessionId'
      ' durationMs=$durationMs segmentCount=$segmentCount',
    );
    _lastFinalBySource.clear();
    _pendingStartBySource.clear();
    _sessionId = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
    try {
      await _repository.finalizeSession(
        sessionId,
        durationMs: durationMs,
        segmentCount: segmentCount,
      );
    } on Object catch (e) {
      _log.severe('finalizeCurrentSession failed: ${e.runtimeType}');
    }
  }

  @override
  void dispose() {
    _lastFinalBySource.clear();
    _pendingStartBySource.clear();
    _sessionId = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
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
      unawaited(
        _repository.saveSegment(_sessionId!, merged).catchError((Object e) {
          _log.severe('saveSegment (merge) failed: ${e.runtimeType}');
        }),
      );
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
      unawaited(
        _repository.saveSegment(_sessionId!, segment).catchError((Object e) {
          _log.severe('saveSegment (new) failed: ${e.runtimeType}');
        }),
      );
    }
  }

  void _handleSessionState(RecordingState state) {
    switch (state) {
      case RecordingActiveState():
        _sessionId = state.sessionId;
        _sessionStartMs = _now().millisecondsSinceEpoch;
        _lastFinalBySource.clear();
        _pendingStartBySource.clear();
        _totalSegmentCount = 0;
        _log.fine(
          'session started: sessionId=${state.sessionId}',
        );
        unawaited(
          _repository.createSession(state.sessionId, DateTime.now()).catchError(
            (Object e) {
              _log.severe('createSession failed: ${e.runtimeType}');
            },
          ),
        );
      case StoppedState():
        _handleSessionStopped();
      case IdleState():
        _sessionId = null;
        _sessionStartMs = null;
        _lastFinalBySource.clear();
        _pendingStartBySource.clear();
        _totalSegmentCount = 0;
      case PausedState() || ReconnectingState():
        break;
    }
  }

  void _handleSessionStopped() {
    if (_sessionId == null) return;
    final durationMs = _sessionStartMs == null
        ? 0
        : _now().millisecondsSinceEpoch - _sessionStartMs!;
    _log.fine(
      'finalizeSession: sessionId=$_sessionId'
      ' durationMs=$durationMs segmentCount=$_totalSegmentCount',
    );
    unawaited(
      _repository
          .finalizeSession(
            _sessionId!,
            durationMs: durationMs,
            segmentCount: _totalSegmentCount,
          )
          .catchError((Object e) {
        _log.severe('finalizeSession failed: ${e.runtimeType}');
      }),
    );
    _lastFinalBySource.clear();
    _pendingStartBySource.clear();
    _sessionId = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
  }
}
