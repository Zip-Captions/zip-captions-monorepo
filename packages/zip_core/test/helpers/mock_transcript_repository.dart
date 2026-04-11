import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/repository_event.dart';
import 'package:zip_core/src/output/transcript_repository.dart';

/// Mocktail mock for [TranscriptRepository].
class MockTranscriptRepository extends Mock implements TranscriptRepository {
  final _eventsController = StreamController<RepositoryEvent>.broadcast();

  @override
  Stream<RepositoryEvent> get events => _eventsController.stream;

  /// Emits a [RepositoryEvent.corruption] event on [events] with [path].
  void emitCorruption(String path) {
    _eventsController.add(
      RepositoryEvent.corruption(corruptFilePath: path),
    );
  }

  /// Closes the internal stream controller.
  void disposeController() => _eventsController.close();
}
