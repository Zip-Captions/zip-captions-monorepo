import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:logging/logging.dart';
// The handler typedefs live with the controller, which owns them; importing
// them here lets a caller type a handler without reaching into it.
import 'package:zip_core/src/output/overlay/overlay_window_controller.dart'
    show OverlayMethodHandler, OverlayMethodHandlerInstaller;

/// One controller's claim on the engine's single method-handler slot.
///
/// Opaque by design: it carries identity only, so a controller cannot forge
/// another's token or inspect the router's internals (NFR Design §4).
final class OverlayHandlerToken {
  /// Creates a token. Only [OverlayMethodRouter] should construct one.
  OverlayHandlerToken();
}

/// Multiplexes `desktop_multi_window`'s single static method-handler slot
/// between the controllers that share one engine (BR-U8.1-04, FD BLM §4.1).
///
/// `DesktopMultiWindow.setMethodHandler` holds exactly one handler. The main
/// engine hosts two controllers (external display and pop-out), so each
/// registers here instead. Dispatch is by **window id**, which the handler
/// already receives as `fromWindowId`: a handler whose `windowIdOf()` is
/// `null` never matches, so a controller without a window receives nothing.
///
/// Lifecycle: the first registration installs one dispatch function;
/// unregistering the last handler clears the slot; [dispose] clears it
/// unconditionally because the container is going away. A duplicate
/// [unregister] is a no-op.
class OverlayMethodRouter {
  /// Creates a router that has not installed anything yet.
  OverlayMethodRouter({
    Logger? log,
    OverlayMethodHandlerInstaller? installSlot,
  })  : _log = log ?? Logger('zip_core.OverlayMethodRouter'),
        _installSlot = installSlot ?? _installedSlot;

  final Logger _log;

  /// The production slot is `desktop_multi_window`'s. Tests inject a recorder
  /// so no plugin object is constructed.
  final OverlayMethodHandlerInstaller _installSlot;

  final List<_Registration> _registrations = <_Registration>[];

  /// Registers [handler] for the window [windowIdOf] reports.
  ///
  /// The handler is called only when `windowIdOf()` is non-null **and** equal
  /// to the message's `fromWindowId`. `windowIdOf` is consulted at dispatch,
  /// never at registration, so a controller may register from its constructor
  /// before it has a window.
  OverlayHandlerToken register(
    int? Function() windowIdOf,
    OverlayMethodHandler handler,
  ) {
    final token = OverlayHandlerToken();
    _registrations.add(
      _Registration(token: token, windowIdOf: windowIdOf, handler: handler),
    );
    // First registration installs the dispatch function; later ones reuse it,
    // so the slot is written once per engine (NFR Design §4).
    if (_registrations.length == 1) _installSlot.call(_dispatch);
    return token;
  }

  /// Removes [token]'s handler. A duplicate call is a no-op; removing the last
  /// registration uninstalls the slot.
  void unregister(OverlayHandlerToken token) {
    final before = _registrations.length;
    _registrations.removeWhere((r) => identical(r.token, token));
    if (_registrations.length != before && _registrations.isEmpty) {
      _installSlot.call(null);
    }
  }

  /// Returns the installer a controller keeps as its `handlerInstaller`.
  ///
  /// The controller's `dispose()` calls it with `null`, which this maps to
  /// `unregister(token)` — the unchanged Unit 8 call site (deviation 5).
  OverlayMethodHandlerInstaller installerFor(OverlayHandlerToken token) =>
      (handler) {
        if (handler == null) {
          unregister(token);
        } else {
          for (final registration in _registrations) {
            if (identical(registration.token, token)) {
              registration.handler = handler;
            }
          }
        }
      };

  /// Clears the slot and drops every registration.
  void dispose() {
    _registrations.clear();
    _installSlot.call(null);
  }

  Future<void> _dispatch(String method, int fromWindowId) async {
    for (final registration in List<_Registration>.of(_registrations)) {
      final windowId = registration.windowIdOf();
      // Null never matches: a controller without a window receives nothing
      // (this closes the shipped `_windowId == null` hole).
      if (windowId == null || windowId != fromWindowId) continue;
      await registration.handler(method, fromWindowId);
      return;
    }
    _log.fine('overlay window method matched no handler');
  }
}

class _Registration {
  _Registration({
    required this.token,
    required this.windowIdOf,
    required this.handler,
  });

  final OverlayHandlerToken token;
  final int? Function() windowIdOf;
  OverlayMethodHandler handler;
}

/// The production slot: `desktop_multi_window`'s single static handler.
///
/// Its signature is `Future<dynamic> Function(MethodCall, int)` at the plugin
/// boundary; the controller's handler returns `Future<void>`, so the adapter
/// discards the (always `null`) result. One function, so the router is the
/// only place that writes the plugin's single static slot.
void _installedSlot(OverlayMethodHandler? handler) {
  DesktopMultiWindow.setMethodHandler(
    handler == null
        ? null
        : (call, fromWindowId) async {
            await handler(call.method, fromWindowId);
            return null;
          },
  );
}
