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
  TranscriptWriterTarget({
    required TranscriptRepository repository,
    required TranscriptSettings settings,
  })  : _repository = repository,
        _settings = settings;

  final TranscriptRepository _repository;
  final TranscriptSettings _settings;

  final _lastFinalBySource = <String, TranscriptSegment>{};
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
        if (event.result.isFinal) _handleFinalResult(event);
      case SessionStateEvent():
        _handleSessionState(event.state);
    }
  }

  @override
  void dispose() {
    _lastFinalBySource.clear();
    _sessionId = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
  }

  void _handleFinalResult(SttResultEvent event) {
    if (!_settings.captureEnabled || _sessionId == null) return;
    final result = event.result;
    final sourceId = result.sourceId;
    final prior = _lastFinalBySource[sourceId];
    final now = DateTime.now().millisecondsSinceEpoch;
    final sessionStart = _sessionStartMs!;

    if (prior != null &&
        (now - (sessionStart + prior.endTimeMs)) <= _mergeWindowMs) {
      // Within merge window: extend the existing segment in-place.
      final merged = prior.copyWith(
        text: '${prior.text} ${result.text}',
        endTimeMs: now - sessionStart,
      );
      _lastFinalBySource[sourceId] = merged;
      _log.fine(
        'saveSegment (merge): sessionId=$_sessionId'
        ' segmentId=${merged.segmentId}',
      );
      unawaited(_repository.saveSegment(_sessionId!, merged));
    } else {
      // New segment: gap > 2s or no prior segment for this source.
      final segment = TranscriptSegment(
        segmentId: _uuid.v4(),
        sessionId: _sessionId!,
        text: result.text,
        sourceId: sourceId,
        startTimeMs: now - sessionStart,
        endTimeMs: now - sessionStart,
      );
      _lastFinalBySource[sourceId] = segment;
      _totalSegmentCount++;
      _log.fine(
        'saveSegment (new): sessionId=$_sessionId'
        ' segmentId=${segment.segmentId}',
      );
      unawaited(_repository.saveSegment(_sessionId!, segment));
    }
  }

  void _handleSessionState(RecordingState state) {
    switch (state) {
      case RecordingActiveState():
        _sessionId = state.sessionId;
        _sessionStartMs = DateTime.now().millisecondsSinceEpoch;
        _lastFinalBySource.clear();
        _totalSegmentCount = 0;
        _log.fine(
          'session started: sessionId=${state.sessionId}',
        );
        unawaited(
          _repository.createSession(state.sessionId, DateTime.now()),
        );
      case StoppedState():
        _handleSessionStopped();
      case IdleState():
        _sessionId = null;
        _sessionStartMs = null;
        _lastFinalBySource.clear();
        _totalSegmentCount = 0;
      case PausedState() || ReconnectingState():
        break;
    }
  }

  void _handleSessionStopped() {
    if (_sessionId == null) return;
    final durationMs = _sessionStartMs == null
        ? 0
        : DateTime.now().millisecondsSinceEpoch - _sessionStartMs!;
    _log.fine(
      'finalizeSession: sessionId=$_sessionId'
      ' durationMs=$durationMs segmentCount=$_totalSegmentCount',
    );
    unawaited(
      _repository.finalizeSession(
        _sessionId!,
        durationMs: durationMs,
        segmentCount: _totalSegmentCount,
      ),
    );
    _lastFinalBySource.clear();
    _sessionId = null;
    _sessionStartMs = null;
    _totalSegmentCount = 0;
  }
}
