import 'package:drift/native.dart';
import 'package:zip_core/src/database/transcript_database.dart';

/// Creates an in-memory [TranscriptDatabase] for testing.
///
/// The `onCreate` migration runs automatically, creating the FTS5 virtual
/// table and sync triggers via the same production path.
Future<TranscriptDatabase> buildTestDatabase() async {
  final db = TranscriptDatabase(NativeDatabase.memory());
  // Force schema creation by running a trivial query.
  await db.customSelect('SELECT 1').get();
  return db;
}
