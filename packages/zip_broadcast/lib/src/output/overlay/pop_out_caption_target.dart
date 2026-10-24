import 'dart:async';
import 'dart:ui';

import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

/// The caption output target for the pop-out window (FD domain-entities §2.1).
///
/// A sibling of `CaptionOverlayTarget`, not a subclass: the two differ in
/// mode, in the frame they hand the controller, and in nothing else. The
/// duplication is the app-local bus adapter, which cannot be shared because it
/// reads this app's registry and this app's caption bus.
class PopOutCaptionTarget implements CaptionOutputTarget {
  /// Creates a [PopOutCaptionTarget].
  PopOutCaptionTarget({
    required OverlayWindowController controller,
    required CaptionOutputTargetRegistry registry,
    required DisplaySettings Function() displaySettings,
    required RecordingState Function() recordingState,
  })  : _controller = controller,
        _registry = registry,
        _displaySettings = displaySettings,
        _recordingState = recordingState;

  final OverlayWindowController _controller;
  final CaptionOutputTargetRegistry _registry;
  final DisplaySettings Function() _displaySettings;

  /// The app's session state, read when the window is shown.
  ///
  /// The target is registered only while a session is already active
  /// (BR-PIP-12), so the bus's `SessionStateEvent` was published before this
  /// target subscribed. Seeding from this value on [show] is what keeps the
  /// first frames `live` instead of the blank `standby` surface (review round
  /// 5, finding 2).
  final RecordingState Function() _recordingState;

  OverlayActivity _activity = OverlayActivity.standby;

  @override
  String get targetId => 'caption_pop_out';

  /// Whether the pop-out window is open.
  bool get isVisible => _controller.isWindowOpen;

  /// The controller's lifecycle events, for the shell.
  Stream<OverlayEvent> get events => _controller.events;

  /// Opens the pop-out.
  ///
  /// [frame] is the shell's geometry (R-M5): the shell has the context, the
  /// settings and the text scaler, the controller has none of them. A null
  /// frame means "no display known", and the platform's own placement stands.
  ///
  /// The activity is seeded from the live session state and pushed before the
  /// open, so the held snapshot the controller replays on ready already says
  /// `live` rather than the initial `standby`.
  Future<void> show(OverlayConfig config, {Rect? frame}) {
    _activity = _activityFor(_recordingState());
    _pushSnapshot();
    return _controller.open(config, frame: frame);
  }

  /// Closes the pop-out because the user switched it off.
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

  /// One frame from the on-screen captions and the current settings
  /// (BR-U8-12).
  ///
  /// Settings are read at each update, never cached, so a theme, font or size
  /// change reaches the next frame without reopening the window.
  void _pushSnapshot() {
    final entries = _visibleCaptions();
    final interim = entries.isNotEmpty && !entries.last.isFinal
        ? entries.last
        : null;
    final finals = interim == null
        ? entries
        : entries.sublist(0, entries.length - 1);

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
        return target.visibleCaptions;
      }
    }
    return const <CaptionDisplayEntry>[];
  }

  static OverlayActivity _activityFor(RecordingState state) => switch (state) {
        IdleState() => OverlayActivity.standby,
        StoppedState() => OverlayActivity.standby,
        PausedState() => OverlayActivity.paused,
        RecordingActiveState() => OverlayActivity.live,
        ReconnectingState() => OverlayActivity.live,
      };

  @override
  void dispose() {
    unawaited(_controller.close(reason: CloseReason.dispose));
  }
}
