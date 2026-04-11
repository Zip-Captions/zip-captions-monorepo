import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/database/transcript_database.dart';
import 'package:zip_core/src/models/transcript_settings.dart';
import 'package:zip_core/src/output/transcript_repository.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';

part 'transcript_providers.g.dart';

/// Provides a file-backed [TranscriptRepository] for the session lifetime.
///
/// Opens `transcripts.db` in the application documents directory.
/// Corruption is handled by [TranscriptDatabase.open]; the repository
/// emits a `RepositoryEvent.corruption` event when recovery occurs.
@Riverpod(keepAlive: true)
Future<TranscriptRepository> transcriptRepository(Ref ref) async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = '${dir.path}/transcripts.db';
  final db = await TranscriptDatabase.open(dbPath);
  final repo = TranscriptRepository(db);
  ref.onDispose(() => unawaited(repo.dispose()));
  return repo;
}

/// Manages [TranscriptSettings] persistence via `SharedPreferences`.
@Riverpod(keepAlive: true)
class TranscriptSettingsNotifier extends _$TranscriptSettingsNotifier {
  static const _captureEnabledKey = 'transcript.captureEnabled';

  @override
  TranscriptSettings build() {
    final prefs = ref.read(sharedPreferencesProvider);
    return TranscriptSettings(
      captureEnabled: prefs.getBool(_captureEnabledKey) ?? true,
    );
  }

  /// Persists and applies a new value for [TranscriptSettings.captureEnabled].
  Future<void> setCaptureEnabled({required bool value}) async {
    state = state.copyWith(captureEnabled: value);
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_captureEnabledKey, value);
  }
}
