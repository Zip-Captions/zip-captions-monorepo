/// The window-output library: the external display window and the pop-out.
///
/// Deliberately **not** re-exported from `package:zip_core/zip_core.dart`
/// (R-M7). Both libraries export a `Failed`: this one from
/// `ExternalDisplayStatus`, the main library through `ConnectionStatus`, so
/// re-exporting would make every importer's `Failed` ambiguous.
///
/// This is the full surface the promotion moves into `zip_core`: the
/// controller, the codec and snapshot, the bridges, the modes, the enumerator,
/// the window services, the configurator, the router, the lease, the close
/// channel, the geometry and the availability rule (FD §1, NFR-R §5.2).
library;

export 'src/models/overlay_config.dart';
export 'src/models/overlay_position.dart';
export 'src/models/overlay_window_config.dart';
export 'src/output/overlay/caption_overlay_codec.dart';
export 'src/output/overlay/caption_overlay_snapshot.dart';
export 'src/output/overlay/caption_position.dart';
export 'src/output/overlay/desktop_multi_window_service.dart';
export 'src/output/overlay/desktop_window_service.dart';
export 'src/output/overlay/display_enumerator.dart';
export 'src/output/overlay/display_enumerator_lease.dart';
export 'src/output/overlay/display_info.dart';
export 'src/output/overlay/external_display_status.dart';
export 'src/output/overlay/overlay_activity.dart';
export 'src/output/overlay/overlay_event.dart';
export 'src/output/overlay/overlay_method_router.dart';
export 'src/output/overlay/overlay_window_bridge.dart';
export 'src/output/overlay/overlay_window_controller.dart';
export 'src/output/overlay/overlay_window_entry.dart';
export 'src/output/overlay/overlay_window_host.dart';
export 'src/output/overlay/overlay_window_mode.dart';
export 'src/output/overlay/pop_out_availability.dart';
export 'src/output/overlay/pop_out_geometry.dart';
export 'src/output/overlay/screen_retriever_display_enumerator.dart';
export 'src/output/overlay/sub_window_closed_channel.dart';
export 'src/output/overlay/window_configurator.dart';
export 'src/output/overlay/window_configurator_export.dart';
export 'src/widgets/overlay_window_app.dart';
export 'src/widgets/pop_out_window_body.dart';
