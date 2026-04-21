import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart';

part 'transcript_database.g.dart';

/// Drift table definition for transcript session metadata.
@DataClassName('TranscriptSessionRow')
class TranscriptSessions extends Table {
  /// UUID primary key identifying the session.
  TextColumn get sessionId => text()();

  /// Wall-clock timestamp when the session started.
  DateTimeColumn get date => dateTime()();

  /// Optional user-assigned session title.
  TextColumn get title => text().nullable()();

  /// Total session duration in milliseconds.
  IntColumn get durationMs => integer().withDefault(const Constant(0))();

  /// Number of segments persisted for this session.
  IntColumn get segmentCount => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {sessionId};
}

/// Drift table definition for individual transcript segments.
@DataClassName('TranscriptSegmentRow')
class TranscriptSegments extends Table {
  /// UUID primary key identifying the segment.
  TextColumn get segmentId => text()();

  /// Foreign key to [TranscriptSessions]; cascades on delete.
  TextColumn get sessionId => text().customConstraint(
    'NOT NULL REFERENCES transcript_sessions(session_id) ON DELETE CASCADE',
  )();

  /// Transcript text for this segment.
  TextColumn get segmentText => text().named('text')();

  /// Identifier of the audio source that produced this segment.
  TextColumn get sourceId => text()();

  /// Segment start offset in milliseconds relative to session start.
  IntColumn get startTimeMs => integer()();

  /// Segment end offset in milliseconds relative to session start.
  IntColumn get endTimeMs => integer()();

  @override
  Set<Column> get primaryKey => {segmentId};
}

/// Drift database for transcript sessions and segments.
///
/// Use [TranscriptDatabase.open] to obtain a file-backed production instance.
/// For tests, construct directly with
/// `TranscriptDatabase(NativeDatabase.memory())`.
@DriftDatabase(tables: [TranscriptSessions, TranscriptSegments])
class TranscriptDatabase extends _$TranscriptDatabase {
  /// Creates a [TranscriptDatabase] backed by the given executor.
  ///
  /// Pass `NativeDatabase.memory()` for in-memory test databases.
  TranscriptDatabase(super.e) : corruptFilePath = null;

  TranscriptDatabase._openFresh(String dbPath, {String? corruptPath})
      : corruptFilePath = corruptPath,
        super(
          NativeDatabase(
            File(dbPath),
            setup: (db) {
              db
                ..execute('PRAGMA journal_mode=WAL')
                ..execute('PRAGMA foreign_keys=ON');
            },
          ),
        );

  /// Path of the renamed corrupt file; non-null only after corruption recovery.
  ///
  /// When non-null, callers should emit a `RepositoryEvent.corruption` event
  /// with this path as the `corruptFilePath` argument.
  final String? corruptFilePath;

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement('''
        CREATE VIRTUAL TABLE transcript_fts USING fts5(
          text,
          segment_id UNINDEXED,
          session_id UNINDEXED,
          content=transcript_segments,
          content_rowid=rowid,
          tokenize='porter unicode61'
        )
      ''');
      await customStatement('''
        CREATE TRIGGER fts_insert AFTER INSERT ON transcript_segments BEGIN
          INSERT INTO transcript_fts(rowid, text, segment_id, session_id)
          VALUES (NEW.rowid, NEW.text, NEW.segment_id, NEW.session_id);
        END
      ''');
      await customStatement('''
        CREATE TRIGGER fts_delete AFTER DELETE ON transcript_segments BEGIN
          INSERT INTO transcript_fts(transcript_fts, rowid, text, segment_id, session_id)
          VALUES ('delete', OLD.rowid, OLD.text, OLD.segment_id, OLD.session_id);
        END
      ''');
    },
    onUpgrade: (m, from, to) async {
      switch (from) {
        // schemaVersion: 1 — no migrations yet.
      }
    },
  );

  /// Opens a file-backed [TranscriptDatabase] at [dbPath].
  ///
  /// Runs `PRAGMA integrity_check` on any existing file. If the check fails,
  /// the corrupt file is renamed to `$dbPath.corrupt` and a fresh database
  /// is opened. Inspect [corruptFilePath] on the returned instance and emit a
  /// `RepositoryEvent.corruption` event when it is non-null.
  static Future<TranscriptDatabase> open(String dbPath) async {
    final file = File(dbPath);
    if (file.existsSync()) {
      final checkDb = sqlite3.open(dbPath);
      try {
        final result = checkDb.select('PRAGMA integrity_check');
        final ok = result.first.values.first == 'ok';
        if (!ok) {
          checkDb.dispose();
          final corruptPath = '$dbPath.corrupt';
          await file.rename(corruptPath);
          return TranscriptDatabase._openFresh(
            dbPath,
            corruptPath: corruptPath,
          );
        }
      } finally {
        checkDb.dispose();
      }
    }
    return TranscriptDatabase._openFresh(dbPath);
  }
}
