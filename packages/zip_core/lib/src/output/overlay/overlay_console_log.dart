import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

/// Prints [log]'s records, and its descendants', to the console in a debug
/// build (fix round 6, R6-5).
///
/// Both apps forward `Logger.root` to `dart:developer`'s `log`, which DevTools
/// shows and `flutter run` does not. The overlay host's lines are the only
/// trace of a failed open, so a debug build also prints them through
/// [debugPrint]. A release build wires nothing and returns `null`.
///
/// The printed line is the level, the logger name and the message. The
/// record's error and stack trace are never printed: the overlay's messages
/// are fixed strings and an error's `runtimeType` at most (BR-U8-18), and the
/// error object itself carries no such guarantee.
///
/// Records are matched by name rather than by [log]'s own stream, so the
/// result is the same whether or not the app enabled hierarchical logging.
StreamSubscription<LogRecord>? routeOverlayLogToConsole(
  Logger log, {
  bool enabled = kDebugMode,
  DebugPrintCallback? printer,
}) {
  if (!enabled) return null;
  final name = log.fullName;
  final prefix = '$name.';
  return log.onRecord
      .where((r) => r.loggerName == name || r.loggerName.startsWith(prefix))
      .listen((record) {
    (printer ?? debugPrint)(
      '${record.level.name}: ${record.loggerName}: ${record.message}',
    );
  });
}
