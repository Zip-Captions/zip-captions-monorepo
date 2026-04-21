import 'package:flutter/material.dart';
import 'package:zip_core/zip_core.dart';

/// Web stub for transcript export — not yet implemented.
Future<void> exportTranscript({
  required String content,
  required String sessionId,
  required ExportFormat format,
  required bool isMobile,
  Rect? shareOrigin,
}) async {
  throw UnsupportedError(
    'Transcript export is not available on this platform.',
  );
}
