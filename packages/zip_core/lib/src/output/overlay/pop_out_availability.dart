import 'package:flutter/foundation.dart';
import 'package:zip_broadcast/src/output/overlay/external_display_status.dart';
import 'package:zip_core/src/models/recording_state.dart';

/// Why the pop-out control is not enabled.
///
/// Rendered as visible text next to the disabled control (FD
/// frontend-components §3), never as a tooltip alone.
enum PopOutUnavailableReason {
  /// No session is capturing captions (BR-PIP-12).
  noSession,

  /// The app has no speech recognition engine to caption with (BR-PIP-13).
  noEngine,
}

/// What a caller renders for the pop-out control.
///
/// [visible] is false only when the platform cannot host a sub-window, in which
/// case nothing renders at all (UX-PIP-04, BR-U8.1-11). [reason] is non-null
/// exactly when [enabled] is false and [visible] is true.
@immutable
class PopOutAvailability {
  /// Creates an availability record.
  const PopOutAvailability({
    required this.visible,
    required this.enabled,
    this.reason,
  });

  /// Whether any part of the control renders.
  final bool visible;

  /// Whether the control can start the pop-out.
  final bool enabled;

  /// Why the control is disabled, or `null` when it is enabled or hidden.
  final PopOutUnavailableReason? reason;

  @override
  bool operator ==(Object other) =>
      other is PopOutAvailability &&
      other.visible == visible &&
      other.enabled == enabled &&
      other.reason == reason;

  @override
  int get hashCode => Object.hash(visible, enabled, reason);

  @override
  String toString() =>
      'PopOutAvailability(visible: $visible, enabled: $enabled, '
      'reason: $reason)';
}

/// Whether [state] is a session that is producing captions.
///
/// The three concrete active states, named deliberately rather than the
/// `ActiveSessionState` mixin: `StoppedState` carries the mixin too but is not
/// a session to pop out of (Q8 A), so a mixin check would enable the control
/// after the session ended.
bool popOutSessionActive(RecordingState state) =>
    state is RecordingActiveState ||
    state is PausedState ||
    state is ReconnectingState;

/// The one availability rule both apps render (FD frontend-components §6).
///
/// `visible` depends only on the platform's capability, `enabled` on the
/// session and the engine, and the reason prefers the engine when both are
/// missing: it is the cause the user can act on and BR-PIP-13 asks for it.
PopOutAvailability popOutAvailability({
  required ExternalDisplayStatus status,
  required RecordingState recording,
  required bool engineAvailable,
}) {
  if (status is Unsupported) {
    return const PopOutAvailability(visible: false, enabled: false);
  }

  final sessionActive = popOutSessionActive(recording);
  final enabled = sessionActive && engineAvailable;
  if (enabled) {
    return const PopOutAvailability(visible: true, enabled: true);
  }

  return PopOutAvailability(
    visible: true,
    enabled: false,
    reason: engineAvailable
        ? PopOutUnavailableReason.noSession
        : PopOutUnavailableReason.noEngine,
  );
}
