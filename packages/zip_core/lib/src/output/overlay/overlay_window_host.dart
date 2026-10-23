import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zip_core/src/output/overlay/desktop_multi_window_service.dart';
import 'package:zip_core/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/output/overlay/display_enumerator.dart';
import 'package:zip_core/src/output/overlay/display_enumerator_lease.dart';
import 'package:zip_core/src/output/overlay/overlay_method_router.dart';
import 'package:zip_core/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/output/overlay/screen_retriever_display_enumerator_factory.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel_factory.dart';

/// One owner for the three resources that exist once per engine: the method
/// handler slot, the display observer and the native close channel
/// (NFR Design §2).
///
/// Both window controllers are built here, so the engine has exactly one
/// router, one `screen_retriever` subscription and one `MethodChannel`. The
/// apps read [displays] instead of the controller's enumerator, and dispose
/// this object once when their container goes away.
///
/// Nothing here imports a plugin: the enumerator and the channel are behind
/// their platform-conditional factories (NFR Design §2).
class OverlayWindowHost {
  /// Creates a host.
  ///
  /// Every collaborator is injectable so a test can build a host on fakes; the
  /// defaults are the production objects for this platform.
  OverlayWindowHost({
    OverlayMethodRouter? router,
    DisplayEnumerator? enumerator,
    SubWindowClosedChannel? closeChannel,
    DesktopWindowService Function(DisplayEnumerator lease)? windowService,
    Logger? log,
  })  : _windowService = windowService ?? _defaultWindowService,
        _router = router ??
            OverlayMethodRouter(log: _child(log, 'OverlayMethodRouter')),
        _log = log ?? Logger('zip_core.OverlayWindowHost'),
        _enumeratorHost = DisplayEnumeratorHost(
          enumerator ??
              createScreenRetrieverDisplayEnumerator(
                log: _child(log, 'ScreenRetrieverDisplayEnumerator'),
              ),
          log: _child(log, 'DisplayEnumeratorHost'),
        ) {
    _closeChannel = closeChannel ??
        createMethodChannelSubWindowClosedChannel(log: _log);
    _closeChannel.install();
  }

  /// Derives a child logger from an optional parent.
  static Logger? _child(Logger? parent, String name) =>
      parent == null ? null : Logger('${parent.name}.$name');

  /// The production window service: the plugin behind the conditional export,
  /// built over the controller's display lease.
  static DesktopWindowService _defaultWindowService(
    DisplayEnumerator lease,
  ) =>
      DesktopMultiWindowService.withEnumerator(lease);

  final DesktopWindowService Function(DisplayEnumerator lease) _windowService;
  final Logger _log;
  final OverlayMethodRouter _router;
  final DisplayEnumeratorHost _enumeratorHost;
  late final SubWindowClosedChannel _closeChannel;
  final List<OverlayWindowController> _controllers =
      <OverlayWindowController>[];
  bool _disposed = false;

  /// The display list both controllers see, for the apps' watch lists.
  Stream<List<DisplayInfo>> get displays => _enumeratorHost.shared.changes;

  /// Whether [dispose] has run.
  bool get isDisposed => _disposed;

  /// The one router, exposed for the host's own tests.
  OverlayMethodRouter get router => _router;

  /// The one close channel, exposed for the host's own tests.
  SubWindowClosedChannel get closeChannel => _closeChannel;

  /// Builds a controller of [mode] wired to this host's shared resources.
  ///
  /// [prefix] names the controller's logger (`zip_core.<prefix>`), so a log
  /// line still says which window produced it without either app importing
  /// the other's name. The returned controller is owned by the caller, which
  /// must dispose it; this host only tracks it for logs.
  ///
  /// The controller registers with the router **before** it is built, so the
  /// token it receives names a live registration (review round 5, finding 1).
  /// `windowIdOf` is read at dispatch, never at registration, so closing over
  /// the not-yet-assigned controller is safe. The controller's own
  /// `_bootstrap` then replaces the placeholder handler through
  /// `installerFor`, and its `dispose()`'s `call(null)` maps to
  /// `unregister(token)`.
  OverlayWindowController createController({
    required OverlayWindowMode mode,
    required String prefix,
  }) {
    late final OverlayWindowController controller;
    final token = _router.register(
      () => controller.windowId,
      (_, _) async {},
    );
    final lease = _enumeratorHost.lease();
    controller = OverlayWindowController(
      windowService: _windowService(lease),
      enumerator: lease,
      handlerInstaller: _router.installerFor(token),
      log: Logger('zip_core.$prefix'),
      mode: mode,
      closeChannel: _closeChannel,
    );
    _controllers.add(controller);
    return controller;
  }

  /// Releases the shared resources. Idempotent.
  ///
  /// The controllers are disposed by their owners; this may run either before
  /// or after them (NFR Design §5): the lease release that follows finds the
  /// shared instance already disposed and does nothing.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _controllers.clear();
    try {
      _router.dispose();
    } on Object catch (error) {
      _log.info('router dispose failed: ${error.runtimeType}');
    }
    try {
      _closeChannel.dispose();
    } on Object catch (error) {
      _log.info('close channel dispose failed: ${error.runtimeType}');
    }
    await _enumeratorHost.dispose();
  }
}
