import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_multi_window_service.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/services/caption/caption_output_target.dart';

/// Caption output target that renders captions in a separate desktop window.
///
/// Delegates all platform-window calls to [DesktopWindowService], which is
/// injectable for testing (Pattern 7, TEST-U3.2). On unsupported platforms
/// (mobile, web), [show] is a no-op.
class CaptionOverlayTarget implements CaptionOutputTarget {
  /// Creates a [CaptionOverlayTarget].
  ///
  /// Defaults to [DesktopMultiWindowService] in production.
  CaptionOverlayTarget({
    DesktopWindowService? windowService,
  }) : _windowService = windowService ?? DesktopMultiWindowService();

  final DesktopWindowService _windowService;

  int? _windowId;
  bool _isVisible = false;

  static final _log = Logger('zip_broadcast.CaptionOverlayTarget');

  @override
  String get targetId => 'caption_overlay';

  /// Whether the overlay window is currently visible.
  bool get isVisible => _isVisible;

  /// Opens (or refreshes) the overlay window with [config].
  ///
  /// No-op if the platform does not support multi-window APIs.
  Future<void> show(OverlayConfig config) async {
    if (!_windowService.isSupported) {
      _log.fine('show: platform not supported; no-op');
      return;
    }

    if (_isVisible && _windowId != null) {
      _log.fine('show: already visible; sending config update');
      unawaited(
        _windowService.invokeMethod(
          _windowId!,
          'updateConfig',
          _encodeConfig(config),
        ),
      );
      return;
    }

    _log.fine('show: creating overlay window');
    _windowId = await _windowService.createWindow(_encodeConfig(config));
    _isVisible = true;
    _log.fine('show: windowId=$_windowId');
  }

  /// Hides and destroys the overlay window.
  Future<void> hide() async {
    if (!_isVisible || _windowId == null) return;
    _log.fine('hide: closing windowId=$_windowId');
    await _windowService.closeWindow(_windowId!);
    _isVisible = false;
    _windowId = null;
  }

  @override
  void onCaptionEvent(CaptionEvent event) {
    if (!_isVisible || _windowId == null) return;
    if (event case SttResultEvent(:final result)) {
      unawaited(
        _windowService.invokeMethod(
          _windowId!,
          'captionUpdate',
          json.encode({'text': result.text, 'isFinal': result.isFinal}),
        ),
      );
    }
  }

  @override
  Future<void> dispose() async => hide();

  static String _encodeConfig(OverlayConfig config) {
    final posMap = switch (config.position) {
      OverlayPositionTop() => {'type': 'top'},
      OverlayPositionBottom() => {'type': 'bottom'},
      OverlayPositionCustom(:final x, :final y) => {
          'type': 'custom',
          'x': x,
          'y': y,
        },
    };
    return json.encode({
      'targetDisplayId': config.targetDisplayId,
      'position': posMap,
      'opacity': config.opacity,
    });
  }
}
