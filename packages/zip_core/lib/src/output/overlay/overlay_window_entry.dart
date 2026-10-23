import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/overlay_window_bridge.dart';
import 'package:zip_core/src/output/overlay/overlay_window_bridge_io.dart'
    if (dart.library.html) 'package:zip_core/src/output/overlay/overlay_window_bridge_stub.dart';
import 'package:zip_core/src/output/overlay/window_configurator.dart';
import 'package:zip_core/src/widgets/overlay_window_app.dart';

final Logger _log = Logger('zip_core.OverlayWindowEntry');

/// The stand-in copy for the "window unavailable" frame.
///
/// `zip_core` has no ARB (FD BLM §7 shape change 1), so the default is the
/// external display's shipped English wording; the app that pumps the window
/// passes its own localized string through [OverlayWindowUnavailableApp].
const String overlayWindowUnavailableMessage = 'Window unavailable';

/// Whether this process is an overlay window rather than the main app.
///
/// `desktop_multi_window` starts the sub-engine with
/// `['multi_window', <windowId>, <arguments>]` (ID-1).
bool isOverlayWindowLaunch(List<String> args) =>
    args.length >= 3 && args.first == 'multi_window';

/// Runs the external display window instead of the main app (ID-1).
///
/// A payload that does not decode becomes a fixed "Window unavailable" frame:
/// the window still appears, so the broadcaster can see that something is
/// wrong, but it never signals ready, so the main engine times the open out and
/// reports it. Nothing about the payload is logged beyond a fixed code
/// (BR-U8-18).
Future<void> overlayWindowMain(
  List<String> args, {
  OverlayWindowBridge? bridge,
  WindowConfigurator? windowConfigurator,
  Future<void> Function(Widget widget)? pump,
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;

  final windowId = int.tryParse(args.length >= 2 ? args[1] : '');
  final launch = decodeLaunch(args.length >= 3 ? args[2] : '');
  if (launch == null || windowId == null) {
    _log.warning('invalid_window_arguments');
    const unavailable = OverlayWindowUnavailableApp(
      message: overlayWindowUnavailableMessage,
    );
    if (pump != null) {
      await pump(unavailable);
    } else {
      runApp(unavailable);
    }
    return;
  }

  // The window applies its own properties before it signals ready, so it is
  // floating, decorated and minimum-sized the first time it is shown
  // (FD BLM §3.2 step 6). A failure is logged by the configurator and never
  // stops the window.
  final configurator = windowConfigurator ?? MethodChannelWindowConfigurator();
  await configurator.configure(windowId, launch.config.windowConfig);

  final entry = OverlayWindowEntry(
    launch: launch,
    bridge: bridge ?? DesktopMultiWindowBridge(),
  );
  if (pump != null) {
    await pump(ProviderScope(child: entry));
  } else {
    runApp(ProviderScope(child: entry));
  }
}

/// Installs the window's method handler and reports readiness to the main
/// engine (ID-2, BR-U8-19).
///
/// The handler is installed before `overlayReady` is sent, so the first
/// `captionUpdate` that follows cannot arrive before there is somewhere to put
/// it. A `captionUpdate` that does not decode is dropped and the last frame
/// stays on screen; nothing thrown here escapes into the plugin.
class OverlayWindowEntry extends StatefulWidget {
  /// Creates an [OverlayWindowEntry].
  const OverlayWindowEntry({
    required this.launch,
    required this.bridge,
    super.key,
  });

  /// The decoded launch configuration and first frame.
  final OverlayWindowLaunch launch;

  /// The channel to the main engine.
  final OverlayWindowBridge bridge;

  @override
  State<OverlayWindowEntry> createState() => _OverlayWindowEntryState();
}

class _OverlayWindowEntryState extends State<OverlayWindowEntry> {
  late final ValueNotifier<CaptionOverlaySnapshot> _snapshot =
      ValueNotifier<CaptionOverlaySnapshot>(widget.launch.snapshot);

  @override
  void initState() {
    super.initState();
    widget.bridge.listen(_onWindowCall);
    widget.bridge.send(null);
  }

  void _onWindowCall(String method, Object? arguments) {
    if (!mounted) return;
    if (method != 'captionUpdate') {
      _log.warning('unknown_window_method');
      return;
    }
    if (arguments is! String) {
      _log.warning('overlay caption update dropped');
      return;
    }
    final next = decodeSnapshot(arguments);
    if (next == null) {
      _log.warning('overlay caption update dropped');
      return;
    }
    _snapshot.value = next;
  }

  @override
  void dispose() {
    _snapshot.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      OverlayWindowApp(launch: widget.launch, snapshot: _snapshot);
}
