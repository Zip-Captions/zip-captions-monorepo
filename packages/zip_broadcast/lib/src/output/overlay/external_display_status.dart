import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';

/// The state the external display controls render.
///
/// Sealed so the controls' switch is exhaustive. The seven variants are the
/// state machine of the functional design (T1-T17).
sealed class ExternalDisplayStatus {
  /// Creates an [ExternalDisplayStatus].
  const ExternalDisplayStatus();
}

/// The platform cannot host a secondary window (web or unsupported).
///
/// The controls render nothing at all in this state (BR-U8-11).
final class Unsupported extends ExternalDisplayStatus {
  /// Creates an [Unsupported].
  const Unsupported();
}

/// No displays are connected.
final class NoDisplays extends ExternalDisplayStatus {
  /// Creates a [NoDisplays].
  const NoDisplays();
}

/// Capable and switched off. Always the launch state (D-6).
final class Off extends ExternalDisplayStatus {
  /// Creates an [Off].
  const Off();
}

/// The window is being created; the ready handshake is pending.
final class Opening extends ExternalDisplayStatus {
  /// Creates an [Opening].
  const Opening();
}

/// The window is open and showing [activity] on [displayId].
final class Open extends ExternalDisplayStatus {
  /// Creates an [Open].
  const Open({required this.activity, required this.displayId});

  /// What the window currently shows.
  final OverlayActivity activity;

  /// The resolved display id, or `null` for the primary display.
  final String? displayId;
}

/// The selected display disconnected; the window is closed and the output is
/// still on, waiting for it to return (D-4).
final class WaitingForDisplay extends ExternalDisplayStatus {
  /// Creates a [WaitingForDisplay].
  const WaitingForDisplay({required this.displayId, this.label});

  /// The saved display id being waited for.
  final String displayId;

  /// The display's last known label, captured when it disconnected.
  ///
  /// The display is no longer in the connected list, so the controls cannot
  /// look it up; without this the banner would name nothing.
  final String? label;
}

/// The window could not be opened.
final class Failed extends ExternalDisplayStatus {
  /// Creates a [Failed].
  const Failed({required this.reason});

  /// A short fixed code (`create_failed` or `ready_timeout`), never shown raw
  /// to the broadcaster.
  final String reason;
}
