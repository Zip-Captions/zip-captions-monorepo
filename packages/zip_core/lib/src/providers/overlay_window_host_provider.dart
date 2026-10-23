import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/output/overlay/overlay_window_host.dart';

part 'overlay_window_host_provider.g.dart';

/// The engine's one [OverlayWindowHost] (NFR Design §2).
///
/// Keep-alive so both window controllers share one router, one display
/// observer and one close channel for the container's lifetime; the host is
/// disposed with the container.
@Riverpod(keepAlive: true)
OverlayWindowHost overlayWindowHost(Ref ref) {
  final host = OverlayWindowHost();
  ref.onDispose(host.dispose);
  return host;
}
