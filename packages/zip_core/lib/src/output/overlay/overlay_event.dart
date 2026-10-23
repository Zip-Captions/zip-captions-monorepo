/// A lifecycle event emitted by the external display window controller.
sealed class OverlayEvent {
  /// Creates an [OverlayEvent].
  const OverlayEvent();
}

/// The selected display disappeared while the window was open.
///
/// The controller has already closed and released the window and entered
/// `WaitingForDisplay`; `overlayEnabled` stays true (D-4).
final class DisplayLost extends OverlayEvent {
  /// Creates a [DisplayLost].
  const DisplayLost({required this.displayId});

  /// The opaque display id that vanished. Never a label or caption text.
  final String displayId;
}

/// The window is gone after a successful ready handshake.
///
/// Signalled only by `PlatformException` code `'-1'` (D-9, BR-U8-04). The
/// shell clears `overlayEnabled` in response (BR-U8-15).
final class WindowClosed extends OverlayEvent {
  /// Creates a [WindowClosed].
  const WindowClosed();
}

/// The window could not be opened.
final class OpenFailed extends OverlayEvent {
  /// Creates an [OpenFailed].
  const OpenFailed(this.reason);

  /// A short fixed code: `create_failed` or `ready_timeout`. Never a payload,
  /// a display label or caption text (BR-U8-18).
  final String reason;
}

/// The broadcaster asked to leave the pop-out from inside its window.
///
/// The sub-engine sends `popOutToggle` over the bridge and the shell reacts;
/// the controller does not toggle itself, because the shell owns the
/// popped-out flag (FD BLM §3.3).
final class PopOutToggled extends OverlayEvent {
  /// Creates a [PopOutToggled].
  const PopOutToggled();
}
