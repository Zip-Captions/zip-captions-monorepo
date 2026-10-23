import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/overlay.dart';

part 'overlay_window_controller_provider.g.dart';

/// The one external display window controller, alive for the app container.
///
/// Kept alive: the controller owns a window, a timer and a platform display
/// observer, so it is a long-lived resource rather than a per-watch value.
@Riverpod(keepAlive: true)
OverlayWindowController overlayWindowController(Ref ref) {
  // One enumerator, shared by the window service (which needs the primary's
  // height and the target display's scale to convert frames) and the
  // controller (which watches the same list). A second instance would open a
  // second platform observer that nothing disposes.
  final enumerator = ScreenRetrieverDisplayEnumerator();
  final controller = OverlayWindowController(
    windowService: DesktopMultiWindowService.withEnumerator(enumerator),
    enumerator: enumerator,
    handlerInstaller: overlayMethodHandlerInstaller,
    log: Logger('zip_broadcast.OverlayWindowController'),
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
@riverpod
Stream<List<DisplayInfo>> displayList(Ref ref) =>
    ref.watch(overlayWindowControllerProvider).enumerator.changes;
