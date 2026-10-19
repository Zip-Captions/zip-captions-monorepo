import 'package:zip_core/src/constants/broadcast_limits_default.dart';

/// The session layer's give-up window for a reconnecting viewer
/// (`domain-entities.md`, NFR Design Q4).
///
/// The shipped `WebRtcViewerTransport` already owns the retry cadence
/// (`business-rules.md` Rule 3); this policy is a window check, not a
/// scheduler. It has no clock, no `Timer` and no I/O — the notifier owns the
/// single timer per interruption and consults this policy only to decide
/// when to stop waiting.
class ReconnectPolicy {
  /// Creates a [ReconnectPolicy].
  const ReconnectPolicy();

  /// Returns the time left before the reconnect window closes, or `null`
  /// once `elapsed` reaches [defaultBroadcastLimits]'s `reconnectWindow`.
  ///
  /// [attempt] is part of the fixed signature and deliberately unconsulted:
  /// the window is a single deadline per interruption, and an attempt-based
  /// schedule would belong to the transport if it ever defers retries here
  /// (`domain-entities.md`).
  Duration? nextDelay(int attempt, Duration elapsed) {
    final remaining = defaultBroadcastLimits.reconnectWindow - elapsed;
    // A non-positive remaining time means the window has closed; callers
    // treat `null` as "give up", not as "retry immediately".
    if (remaining <= Duration.zero) return null;
    return remaining;
  }
}
