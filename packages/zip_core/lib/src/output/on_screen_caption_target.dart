import 'dart:async';

import 'package:logging/logging.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_core/src/models/caption_display_entry.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/output/transcript_repository.dart';
import 'package:zip_core/src/services/caption/caption_output_target.dart';

/// Caption output target that maintains a live display buffer.
///
/// Receives events from `CaptionOutputTargetRegistry` via [onCaptionEvent]
/// and exposes [onVisibleCaptionsChanged] for UI subscription. State is
/// updated synchronously on every event; `_controller.add()` is debounced
/// at 50ms to limit widget rebuilds (NFR PERF-U3.1).
class OnScreenCaptionTarget implements CaptionOutputTarget {
  /// Creates an [OnScreenCaptionTarget].
  ///
  /// [targetId] uniquely identifies this target in the registry.
  /// [maxBufferSegments] caps the in-memory final-segment buffer
  /// (default 2000). [repository] enables scrollback via
  /// [loadOlderSegments]; pass `null`
  /// when transcript capture is disabled.
  OnScreenCaptionTarget({
    required String targetId,
    int maxBufferSegments = 2000,
    TranscriptRepository? repository,
  })  : _targetId = targetId,
        _maxBufferSegments = maxBufferSegments,
        _repository = repository;

  final String _targetId;
  final int _maxBufferSegments;
  final TranscriptRepository? _repository;

  final _buffer = <CaptionDisplayEntry>[];
  CaptionDisplayEntry? _currentInterim;
  Timer? _debounceTimer;
  final _controller =
      StreamController<List<CaptionDisplayEntry>>.broadcast();
  String? _currentSessionId;

  static const _uuid = Uuid();
  static final _log = Logger('zip_core.OnScreenCaptionTarget');

  @override
  String get targetId => _targetId;

  /// Stream that emits the visible caption list after each 50ms debounce.
  Stream<List<CaptionDisplayEntry>> get onVisibleCaptionsChanged =>
      _controller.stream;

  /// Synchronous snapshot of the currently visible captions.
  ///
  /// Returns final buffer entries followed by the current interim entry,
  /// if any.
  List<CaptionDisplayEntry> get visibleCaptions => [
        ..._buffer,
        ?_currentInterim,
      ];

  @override
  void onCaptionEvent(CaptionEvent event) {
    switch (event) {
      case SttResultEvent():
        final result = event.result;
        if (result.isFinal) {
          _buffer.add(_makeEntry(result));
          _currentInterim = null;
          if (_buffer.length > _maxBufferSegments) _buffer.removeAt(0);
        } else {
          _currentInterim = _makeInterimEntry(result);
        }
        _scheduleEmit();
      case SessionStateEvent():
        _handleSessionState(event.state);
        _scheduleEmit();
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    unawaited(_controller.close());
    _log.fine('dispose: targetId=$_targetId');
  }

  /// Prepends segments older than the current buffer head to the buffer.
  ///
  /// No-op when repository is null, no session is active, or the buffer
  /// is empty.
  Future<void> loadOlderSegments() async {
    if (_repository == null ||
        _currentSessionId == null ||
        _buffer.isEmpty) {
      return;
    }
    _log.fine('loadOlderSegments: sessionId=$_currentSessionId');
    final segments = await _repository.getSegmentsBefore(
      sessionId: _currentSessionId!,
      beforeTimestamp: _buffer.first.timestamp,
    );
    if (segments.isEmpty) return;
    final entries = segments.reversed
        .map(
          (s) => CaptionDisplayEntry(
            entryId: s.segmentId,
            sessionId: s.sessionId,
            text: s.text,
            isFinal: true,
            sourceId: s.sourceId,
            timestamp:
                DateTime.fromMillisecondsSinceEpoch(s.startTimeMs),
          ),
        )
        .toList();
    _buffer.insertAll(0, entries);
    _scheduleEmit();
  }

  void _scheduleEmit() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 50), () {
      _controller.add(visibleCaptions);
    });
  }

  void _handleSessionState(RecordingState state) {
    switch (state) {
      case RecordingActiveState():
        _currentSessionId = state.sessionId;
        _buffer.clear();
        _currentInterim = null;
        _log.fine(
          'session started: targetId=$_targetId'
          ' sessionId=${state.sessionId}',
        );
      case StoppedState():
        _currentSessionId = null;
        _currentInterim = null;
        _log.fine('session stopped: targetId=$_targetId');
      case IdleState():
        _currentSessionId = null;
        _buffer.clear();
        _currentInterim = null;
      case PausedState() || ReconnectingState():
        break;
    }
  }

  CaptionDisplayEntry _makeEntry(SttResult result) => CaptionDisplayEntry(
        entryId: _uuid.v4(),
        sessionId: _currentSessionId ?? '',
        text: result.text,
        isFinal: true,
        sourceId: result.sourceId,
        timestamp: result.timestamp,
      );

  CaptionDisplayEntry _makeInterimEntry(SttResult result) =>
      CaptionDisplayEntry(
        entryId: _uuid.v4(),
        sessionId: _currentSessionId ?? '',
        text: result.text,
        isFinal: false,
        sourceId: result.sourceId,
        timestamp: result.timestamp,
      );
}
