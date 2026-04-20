import 'dart:async';

import 'package:drift/drift.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/database/transcript_database.dart';
import 'package:zip_core/src/models/export_format.dart';
import 'package:zip_core/src/models/repository_event.dart';
import 'package:zip_core/src/models/transcript_search_result.dart';
import 'package:zip_core/src/models/transcript_segment.dart';
import 'package:zip_core/src/models/transcript_session.dart';

/// Data access layer for transcript sessions and segments.
///
/// Wraps `TranscriptDatabase` and exposes a domain-level API for the rest of
/// the application. Use `transcriptRepositoryProvider` to obtain an instance.
class TranscriptRepository {
  /// Creates a [TranscriptRepository] backed by [db].
  ///
  /// If [db] was opened after a corruption recovery, a
  /// `RepositoryEvent.corruption` event is scheduled on [events]
  /// immediately after construction.
  TranscriptRepository(TranscriptDatabase db) : _db = db {
    if (db.corruptFilePath != null) {
      scheduleMicrotask(() {
        _eventsController.add(
          RepositoryEvent.corruption(corruptFilePath: db.corruptFilePath!),
        );
      });
    }
  }

  final TranscriptDatabase _db;
  final _eventsController = StreamController<RepositoryEvent>.broadcast();
  static final _log = Logger('zip_core.TranscriptRepository');

  /// Stream of repository-level events such as corruption notifications.
  Stream<RepositoryEvent> get events => _eventsController.stream;

  /// Closes the event stream and the underlying database connection.
  Future<void> dispose() async {
    await _eventsController.close();
    await _db.close();
  }

  // ---------------------------------------------------------------------------
  // Write operations
  // ---------------------------------------------------------------------------

  /// Creates the session row for [sessionId] at [date].
  ///
  /// Must be called before the first [saveSegment] for the session.
  Future<void> createSession(String sessionId, DateTime date) async {
    _log.fine('createSession: sessionId=$sessionId');
    await _db.into(_db.transcriptSessions).insertOnConflictUpdate(
      TranscriptSessionsCompanion(
        sessionId: Value(sessionId),
        date: Value(date),
      ),
    );
  }

  /// Inserts or replaces [segment] for [sessionId].
  Future<void> saveSegment(
    String sessionId,
    TranscriptSegment segment,
  ) async {
    _log.fine(
      'saveSegment: sessionId=$sessionId segmentId=${segment.segmentId}',
    );
    await _db.into(_db.transcriptSegments).insertOnConflictUpdate(
      TranscriptSegmentsCompanion(
        segmentId: Value(segment.segmentId),
        sessionId: Value(sessionId),
        segmentText: Value(segment.text),
        sourceId: Value(segment.sourceId),
        startTimeMs: Value(segment.startTimeMs),
        endTimeMs: Value(segment.endTimeMs),
      ),
    );
  }

  /// Updates session metadata after recording stops.
  Future<void> finalizeSession(
    String sessionId, {
    required int durationMs,
    required int segmentCount,
  }) async {
    _log.fine(
      'finalizeSession: sessionId=$sessionId'
      ' durationMs=$durationMs segmentCount=$segmentCount',
    );
    await (_db.update(_db.transcriptSessions)
          ..where((t) => t.sessionId.equals(sessionId)))
        .write(
      TranscriptSessionsCompanion(
        durationMs: Value(durationMs),
        segmentCount: Value(segmentCount),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Read operations
  // ---------------------------------------------------------------------------

  /// Returns a paginated list of sessions ordered by date descending.
  Future<List<TranscriptSession>> getSessions({
    int limit = 50,
    int offset = 0,
  }) async {
    final rows = await (_db.select(_db.transcriptSessions)
          ..orderBy([(t) => OrderingTerm.desc(t.date)])
          ..limit(limit, offset: offset))
        .get();
    return rows.map(_rowToSession).toList();
  }

  /// Returns the session with [sessionId], or `null` if not found.
  Future<TranscriptSession?> getSession(String sessionId) async {
    final row = await (_db.select(_db.transcriptSessions)
          ..where((t) => t.sessionId.equals(sessionId)))
        .getSingleOrNull();
    return row == null ? null : _rowToSession(row);
  }

  /// Returns all segments for [sessionId] ordered by start time ascending.
  Future<List<TranscriptSegment>> getSegments(String sessionId) async {
    final rows = await (_db.select(_db.transcriptSegments)
          ..where((t) => t.sessionId.equals(sessionId))
          ..orderBy([(t) => OrderingTerm.asc(t.startTimeMs)]))
        .get();
    return rows.map(_rowToSegment).toList();
  }

  /// Returns segments for [sessionId] that started before [beforeTimestamp].
  ///
  /// [beforeTimestamp] is a wall-clock time; it is converted to a session
  /// offset by subtracting the session's start date.
  Future<List<TranscriptSegment>> getSegmentsBefore({
    required String sessionId,
    required DateTime beforeTimestamp,
    int limit = 100,
  }) async {
    final session = await getSession(sessionId);
    if (session == null) return [];
    final offsetMs = beforeTimestamp.millisecondsSinceEpoch -
        session.date.millisecondsSinceEpoch;
    final rows = await (_db.select(_db.transcriptSegments)
          ..where(
            (t) =>
                t.sessionId.equals(sessionId) &
                t.startTimeMs.isSmallerThanValue(offsetMs),
          )
          ..orderBy([(t) => OrderingTerm.desc(t.startTimeMs)])
          ..limit(limit))
        .get();
    return rows.map(_rowToSegment).toList();
  }

  // ---------------------------------------------------------------------------
  // Full-text search
  // ---------------------------------------------------------------------------

  /// Searches transcript content using FTS5 MATCH.
  ///
  /// Results are grouped by session, with up to 3 snippets per session,
  /// ordered by ascending BM25 relevance score (lower = more relevant).
  Future<List<TranscriptSearchResult>> search(String query) async {
    final rows = await _db.customSelect(
      '''
      SELECT
        ts.session_id,
        snippet(transcript_fts, 0, '[', ']', '...', 64) AS snippet,
        bm25(transcript_fts) AS score
      FROM transcript_fts
      JOIN transcript_segments seg ON seg.segment_id = transcript_fts.segment_id
      JOIN transcript_sessions ts ON ts.session_id = seg.session_id
      WHERE transcript_fts MATCH ?
      ORDER BY score ASC
      LIMIT 50
      ''',
      variables: [Variable.withString(query)],
      readsFrom: {_db.transcriptSessions, _db.transcriptSegments},
    ).get();

    final grouped = <String, ({double bestScore, List<String> snippets})>{};
    for (final row in rows) {
      final sessionId = row.read<String>('session_id');
      final snippet = row.read<String>('snippet');
      final score = row.read<double>('score');
      final entry = grouped[sessionId];
      if (entry == null) {
        grouped[sessionId] = (bestScore: score, snippets: [snippet]);
      } else if (entry.snippets.length < 3) {
        grouped[sessionId] = (
          bestScore: entry.bestScore,
          snippets: [...entry.snippets, snippet],
        );
      }
    }

    final results = <TranscriptSearchResult>[];
    for (final MapEntry(:key, :value) in grouped.entries) {
      final session = await getSession(key);
      if (session != null) {
        results.add(
          TranscriptSearchResult(
            session: session,
            snippets: value.snippets,
            relevanceScore: value.bestScore,
          ),
        );
      }
    }
    return results;
  }

  // ---------------------------------------------------------------------------
  // Delete
  // ---------------------------------------------------------------------------

  /// Deletes the session with [sessionId] and all its segments.
  Future<void> deleteSession(String sessionId) async {
    _log.fine('deleteSession: sessionId=$sessionId');
    await (_db.delete(_db.transcriptSegments)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
    await (_db.delete(_db.transcriptSessions)
          ..where((t) => t.sessionId.equals(sessionId)))
        .go();
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  /// Exports all segments for [sessionId] in the specified [format].
  Future<String> exportSession(
    String sessionId,
    ExportFormat format,
  ) async {
    _log.fine('exportSession: sessionId=$sessionId format=$format');
    final segments = await getSegments(sessionId);
    return switch (format) {
      ExportFormat.txt => _exportTxt(segments),
      ExportFormat.srt => _exportSrt(segments),
      ExportFormat.vtt => _exportVtt(segments),
    };
  }

  // ---------------------------------------------------------------------------
  // Converters
  // ---------------------------------------------------------------------------

  TranscriptSession _rowToSession(TranscriptSessionRow row) =>
      TranscriptSession(
        sessionId: row.sessionId,
        date: row.date.toUtc(),
        durationMs: row.durationMs,
        segmentCount: row.segmentCount,
        title: row.title,
      );

  TranscriptSegment _rowToSegment(TranscriptSegmentRow row) =>
      TranscriptSegment(
        segmentId: row.segmentId,
        sessionId: row.sessionId,
        text: row.segmentText,
        sourceId: row.sourceId,
        startTimeMs: row.startTimeMs,
        endTimeMs: row.endTimeMs,
      );

  // ---------------------------------------------------------------------------
  // Export helpers
  // ---------------------------------------------------------------------------

  String _exportTxt(List<TranscriptSegment> segments) =>
      segments.map((s) => s.text).join('\n');

  String _exportSrt(List<TranscriptSegment> segments) {
    final buffer = StringBuffer();
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final endMs = _effectiveEndMs(s, i, segments);
      buffer
        ..writeln(i + 1)
        ..writeln(
          '${_srtTimestamp(s.startTimeMs)} --> ${_srtTimestamp(endMs)}',
        )
        ..writeln(s.text)
        ..writeln();
    }
    return buffer.toString();
  }

  String _exportVtt(List<TranscriptSegment> segments) {
    final buffer = StringBuffer('WEBVTT\n\n');
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      final endMs = _effectiveEndMs(s, i, segments);
      buffer
        ..writeln(
          '${_vttTimestamp(s.startTimeMs)} --> ${_vttTimestamp(endMs)}',
        )
        ..writeln(s.text)
        ..writeln();
    }
    return buffer.toString();
  }

  /// Returns a meaningful end time for cue at index [i].
  ///
  /// When stored end equals start (the writer records arrival time for both
  /// when a new segment is created), end is inferred from the next segment's
  /// start. For the last segment, 3 seconds are added as a default.
  int _effectiveEndMs(
    TranscriptSegment s,
    int i,
    List<TranscriptSegment> segments,
  ) {
    if (s.endTimeMs > s.startTimeMs) return s.endTimeMs;
    if (i + 1 < segments.length) return segments[i + 1].startTimeMs;
    return s.startTimeMs + 3000;
  }

  String _srtTimestamp(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s,$millis';
  }

  String _vttTimestamp(int ms) {
    final d = Duration(milliseconds: ms);
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    final millis = (ms % 1000).toString().padLeft(3, '0');
    return '$h:$m:$s.$millis';
  }
}
