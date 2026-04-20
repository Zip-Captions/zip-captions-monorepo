import 'package:drift/native.dart';
import 'package:zip_core/src/database/transcript_database.dart';

/// Creates an in-memory [TranscriptDatabase] for testing.
///
/// Applies the same PRAGMA setup as production (`journal_mode=WAL` is
/// silently ignored for in-memory databases, but `foreign_keys=ON` is
/// enforced, matching the production FK constraint behaviour).
Future<TranscriptDatabase> buildTestDatabase() async {
  final db = TranscriptDatabase(
    NativeDatabase.memory(
      setup: (rawDb) {
        rawDb
          ..execute('PRAGMA journal_mode=WAL')
          ..execute('PRAGMA foreign_keys=ON');
      },
    ),
  );
  // Force schema creation by running a trivial query.
  await db.customSelect('SELECT 1').get();
  return db;
}
