import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:zip_core/zip_core.dart';

/// Writes [content] to a temp file, shares or saves it, then deletes the temp.
///
/// On mobile ([isMobile]=true) the system share sheet is used. On desktop,
/// a file-save dialog is shown. Throws on any I/O failure; callers should
/// wrap in try/catch and display an error to the user.
Future<void> exportTranscript({
  required String content,
  required String sessionId,
  required ExportFormat format,
  required bool isMobile,
  Rect? shareOrigin,
}) async {
  final tempDir = await getTemporaryDirectory();
  await Directory(tempDir.path).create(recursive: true);
  final filename = 'transcript_${sessionId.substring(0, 8)}.${format.name}';
  final path = '${tempDir.path}/$filename';
  await File(path).writeAsString(content);

  try {
    if (isMobile) {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path)],
          sharePositionOrigin: shareOrigin,
        ),
      );
    } else {
      final location = await getSaveLocation(
        suggestedName: filename,
        acceptedTypeGroups: [_typeGroupFor(format)],
      );
      if (location != null) {
        await File(path).copy(location.path);
      }
    }
  } finally {
    try {
      await File(path).delete();
    } on Object {
      // Best-effort cleanup; OS will eventually purge temp files.
    }
  }
}

XTypeGroup _typeGroupFor(ExportFormat format) {
  return switch (format) {
    ExportFormat.txt =>
      const XTypeGroup(label: 'Text', extensions: ['txt']),
    ExportFormat.srt =>
      const XTypeGroup(label: 'SubRip', extensions: ['srt']),
    ExportFormat.vtt =>
      const XTypeGroup(label: 'WebVTT', extensions: ['vtt']),
  };
}
