/// The window-output library: the external display and the pop-out.
///
/// Deliberately **not** re-exported from `package:zip_core/zip_core.dart`
/// (R-M7). Both libraries export a `Failed`: this one from
/// `ExternalDisplayStatus`, the main library through `ConnectionStatus`, so
/// re-exporting would make every importer's `Failed` ambiguous.
///
/// The barrel lists only what `zip_core` owns. Everything the promotion moves
/// in (the controller, the codec, the snapshot, the bridges, the modes, the
/// enumerator and the window services) is added by that move, so this library
/// compiles at every step instead of naming files that do not exist yet.
library;

export 'src/models/overlay_window_config.dart';
export 'src/output/overlay/overlay_method_router.dart';
export 'src/output/overlay/pop_out_availability.dart';
export 'src/output/overlay/pop_out_geometry.dart';
export 'src/output/overlay/sub_window_closed_channel.dart';
export 'src/output/overlay/window_configurator.dart';
export 'src/output/overlay/window_configurator_export.dart';
