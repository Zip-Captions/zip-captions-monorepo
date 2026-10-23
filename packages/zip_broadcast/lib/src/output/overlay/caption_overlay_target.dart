import 'dart:async';

import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

/// The caption output target for the external display window.
///
/// A thin delegator to [OverlayWindowController] plus a caption-bus adapter
/// (B-9). The controller owns the window, the state machine and the
/// handshake; this class only turns caption events into snapshots and forwards
/// show/hide. It holds no visibility flag of its own: [isVisible] reads the
/// controller's window id, so there is one writer for that invariant.
class CaptionOverlayTarget implements CaptionOutputTarget {
  /// Creates a [CaptionOverlayTarget].
  CaptionOverlayTarget({
    required OverlayWindowController controller,
    required CaptionOutputTargetRegistry registry,
    required DisplaySettings Function() displaySettings,
  })  : _controller = controller,
        _registry = registry,
        _displaySettings = displaySettings;

  final OverlayWindowController _controller;
  final CaptionOutputTargetRegistry _registry;
  final DisplaySettings Function() _displaySettings;

  /// The recognition activity, updated by session-state events.
  ///
  /// Activity is an attribute of the open window, not a lifecycle event: a
  /// recognition change never opens, closes or re-frames anything (D-5).
  OverlayActivity _activity = OverlayActivity.standby;

  @override
  String get targetId => 'caption_overlay';

  /// Whether the external display window is open.
  bool get isVisible => _controller.isWindowOpen;

  /// The controller's lifecycle events, for the shell.
  Stream<OverlayEvent> get events => _controller.events;

  /// Opens (or re-targets) the window.
  ///
  /// [persistedDisplayId] is the broadcaster's saved selection; the controller
  /// resolves it against the connected displays and never writes it (BR-U8-07,
  /// D-4). The controller refuses a concurrent open; this call is not itself
  /// awaited by the shell's caption path.
  Future<void> show(
    OverlayConfig config, {
    String? persistedDisplayId,
  }) =>
      _controller.open(config, persistedDisplayId: persistedDisplayId);

  /// Closes the window because the output was switched off.
  Future<void> hide() => _controller.close(reason: CloseReason.toggleOff);

  @override
  void onCaptionEvent(CaptionEvent event) {
    switch (event) {
      case SessionStateEvent(:final state):
        _activity = _activityFor(state);
      case SttResultEvent():
        break;
    }
    _pushSnapshot();
  }

  /// Builds the snapshot from the on-screen target's visible captions and the
  /// current display settings (BR-U8-12).
  ///
  /// The settings are read from the provider's value at each update, never a
  /// cached copy, so a theme, font, size, direction or max-lines change reaches
  /// the next snapshot without reopening the window.
  void _pushSnapshot() {
    final entries = _visibleCaptions();
    final interim = entries.isNotEmpty && !entries.last.isFinal
        ? entries.last
        : null;
    final finals = interim == null ? entries : entries.sublist(0, entries.length - 1);

    _controller.push(
      CaptionOverlaySnapshot(
        activity: _activity,
        entries: finals,
        interim: interim,
        settings: _displaySettings(),
      ),
    );
  }

  List<CaptionDisplayEntry> _visibleCaptions() {
    for (final target in _registry.activeTargets) {
      if (target is OnScreenCaptionTarget) {
        // Final buffer entries followed by the trailing interim.
        return target.visibleCaptions;
      }
    }
    return const <CaptionDisplayEntry>[];
  }

  /// Maps the recognition state onto the window's activity (D-5).
  static OverlayActivity _activityFor(RecordingState state) => switch (state) {
        IdleState() => OverlayActivity.standby,
        StoppedState() => OverlayActivity.standby,
        PausedState() => OverlayActivity.paused,
        RecordingActiveState() => OverlayActivity.live,
        // Reconnecting is a transport concern; recognition itself is not
        // paused (D-5).
        ReconnectingState() => OverlayActivity.live,
      };

  @override
  void dispose() {
    // Fire-and-forget: the registry's `dispose()` is synchronous and must not
    // block on a window close.
    unawaited(_controller.close(reason: CloseReason.dispose));
  }
}
