import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' show overlayWindowHostProvider;

part 'overlay_window_controller_provider.g.dart';

/// The one external display window controller, alive for the app container.
///
/// Built from the engine's one host (NFR Design §2), exactly like the pop-out,
/// so the router is the only writer of `desktop_multi_window`'s single
/// method-handler slot and both controllers share one display observer and one
/// close channel (review round 5, finding 1).
///
/// Keeping the controller alive is what keeps its window, timer and display
/// observer alive: it is a resource, not a per-watch value.
@Riverpod(keepAlive: true)
OverlayWindowController overlayWindowController(Ref ref) {
  final host = ref.watch(overlayWindowHostProvider);
  final controller = host.createController(
    mode: const ExternalDisplayMode(),
    prefix: 'zip_broadcast.OverlayWindowController',
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// The state the external display controls render.
///
/// Replays the current status first: [OverlayWindowController.statusChanges]
/// is a broadcast stream, so a plain subscription would stay in
/// `AsyncLoading` on a capable machine (the controller starts `Off` and emits
/// nothing until a transition), and the controls would never render.
@riverpod
Stream<ExternalDisplayStatus> externalDisplayStatus(Ref ref) async* {
  final controller = ref.watch(overlayWindowControllerProvider);
  yield controller.status;
  yield* controller.statusChanges;
}

/// The connected displays, per the enumerator's event contract.
///
/// Reads the host's shared list rather than the controller's lease: the host
/// owns the one observer now, and the controls want the engine's list.
@riverpod
Stream<List<DisplayInfo>> displayList(Ref ref) =>
    ref.watch(overlayWindowHostProvider).displays;
