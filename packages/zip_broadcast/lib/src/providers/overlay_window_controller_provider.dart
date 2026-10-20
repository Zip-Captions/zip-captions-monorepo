import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_multi_window_service.dart';
import 'package:zip_broadcast/src/output/overlay/display_enumerator.dart';
import 'package:zip_broadcast/src/output/overlay/external_display_status.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_broadcast/src/output/overlay/screen_retriever_display_enumerator.dart';

/// The one external display window controller, alive for the app container.
///
/// A hand-written `Provider` rather than a `@Riverpod` one: the controller is a
/// plain class (NFR Design Q6), like the other service objects in this package.
final overlayWindowControllerProvider = Provider<OverlayWindowController>((ref) {
  final controller = OverlayWindowController(
    windowService: DesktopMultiWindowService(),
    enumerator: ScreenRetrieverDisplayEnumerator(),
    handlerInstaller: overlayMethodHandlerInstaller,
    log: Logger('zip_broadcast.OverlayWindowController'),
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// The state the external display controls render.
final externalDisplayStatusProvider =
    StreamProvider<ExternalDisplayStatus>((ref) {
  return ref.watch(overlayWindowControllerProvider).statusChanges;
});

/// The connected displays, per the enumerator's event contract.
final displayListProvider = StreamProvider<List<DisplayInfo>>((ref) {
  return ref.watch(overlayWindowControllerProvider).enumerator.changes;
});
