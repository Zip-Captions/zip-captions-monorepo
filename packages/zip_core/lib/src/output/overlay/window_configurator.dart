import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/overlay_window_config.dart';

/// Applies a window's own properties from inside the engine that owns it.
///
/// The pop-out sub-engine calls [configure] once, before it signals ready, so
/// the window is floating, decorated and minimum-sized before it is shown
/// (FD BLM §3.2 step 6; BR-U8.1-05). The production implementation is a
/// `MethodChannel` that every runner implements (NFR Design §5.1).
///
/// A failure is caught by the implementation and never thrown: a window that
/// is not on top is still a usable pop-out, while an `OpenFailed` for a working
/// window is worse (NFR-R §3.1).
// A one-method interface is the point: the sub-engine takes a seam it can
// replace in tests, and the two implementations (channel, no-op) are what make
// the export conditional. Collapsing it to a function would remove the seam
// the NFR-R §1.4 fake stands in for.
// ignore: one_member_abstracts
abstract interface class WindowConfigurator {
  /// Applies [config] to the window [windowId] names.
  ///
  /// [windowId] only tags the window for the later native close event, because
  /// the native handler addresses the window whose view created the callback.
  Future<void> configure(int windowId, OverlayWindowConfig config);
}

/// The channel and method every runner implements. Fixed for both apps.
abstract final class WindowConfiguratorChannel {
  /// The sub-engine channel name.
  static const String name = 'zip_core/overlay_window_configure';

  /// The only method the channel carries.
  static const String method = 'configure';
}

/// The production configurator, over the per-runner `configure` channel.
class MethodChannelWindowConfigurator implements WindowConfigurator {
  /// Creates the configurator.
  MethodChannelWindowConfigurator({
    MethodChannel? channel,
    Logger? log,
  })  : _channel =
            channel ?? const MethodChannel(WindowConfiguratorChannel.name),
        _log = log ?? Logger('zip_core.WindowConfigurator');

  final MethodChannel _channel;
  final Logger _log;

  @override
  Future<void> configure(int windowId, OverlayWindowConfig config) async {
    try {
      await _channel.invokeMethod<void>(
        WindowConfiguratorChannel.method,
        <String, Object?>{
          'windowId': windowId,
          'floating': config.floating,
          'decorated': config.decorated,
          'minWidth': config.minWidth,
          'minHeight': config.minHeight,
        },
      );
    } on Object catch (error) {
      // One fixed text at FINE, then the error's runtimeType: release logs stay
      // unchanged and no argument (the window id included) is echoed
      // (BR-PIP-11, SECURITY-03).
      _log.fine('window configure failed: ${error.runtimeType}');
    }
  }
}

/// The no-op configurator for platforms that cannot host a sub-window.
///
/// The overlay engine never starts there, so [configure] does nothing
/// (BR-U8.1-11).
class NoopWindowConfigurator implements WindowConfigurator {
  /// Creates the stub.
  const NoopWindowConfigurator();

  /// Nothing to apply.
  @override
  Future<void> configure(int windowId, OverlayWindowConfig config) async {}
}
