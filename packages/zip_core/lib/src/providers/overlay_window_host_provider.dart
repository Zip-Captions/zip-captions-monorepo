import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/output/overlay/overlay_console_log.dart';
import 'package:zip_core/src/output/overlay/overlay_window_host.dart';

part 'overlay_window_host_provider.g.dart';

/// The engine's one [OverlayWindowHost] (NFR Design §2).
///
/// Keep-alive so both window controllers share one router, one display
/// observer and one close channel for the container's lifetime; the host is
/// disposed with the container.
///
/// The host is built on a named logger so its router, enumerator and
/// controllers log beneath it, and a debug build prints that subtree to the
/// console (R6-5). A release build adds no route.
@Riverpod(keepAlive: true)
OverlayWindowHost overlayWindowHost(Ref ref) {
  final log = Logger('zip_core.OverlayWindowHost');
  final host = OverlayWindowHost(log: log);
  final console = routeOverlayLogToConsole(log);
  ref.onDispose(() async {
    await console?.cancel();
    await host.dispose();
  });
  return host;
}
