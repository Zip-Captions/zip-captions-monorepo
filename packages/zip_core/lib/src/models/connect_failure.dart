import 'package:meta/meta.dart';

/// Why a `ViewerTransport.connect()`/`restart()` attempt terminally failed
/// (FR-7.4 — "cannot connect, with a specific reason").
///
/// Exhaustive by design (`business-rules.md` Rule 3, extended by Unit 7's
/// Rule 5): every rejection/failure path a viewer can observe must resolve
/// to exactly one of these seven variants, never a generic fallback. The
/// original four are transport-scoped (Unit 5); the three added at Unit 7
/// are resolution-origin reasons.
@immutable
sealed class ConnectFailure {
  const ConnectFailure();
}

/// The broadcast is at its viewer capacity cap
/// (`SignalingMessage.JoinRejected(JoinRejection.full)`).
final class BroadcastFull extends ConnectFailure {
  /// Creates a [BroadcastFull] failure.
  const BroadcastFull();

  @override
  bool operator ==(Object other) => other is BroadcastFull;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The peer connection's own ICE state reports `failed` with no retry in
/// progress, or all reconnection retries were abandoned by a terminal
/// condition (`business-rules.md` Rule 2).
final class IceFailed extends ConnectFailure {
  /// Creates an [IceFailed] failure.
  const IceFailed();

  @override
  bool operator ==(Object other) => other is IceFailed;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Any `JoinRejected` not covered by [BroadcastFull] (e.g. the session no
/// longer exists).
final class SignalingRejected extends ConnectFailure {
  /// Creates a [SignalingRejected] failure.
  const SignalingRejected();

  @override
  bool operator ==(Object other) => other is SignalingRejected;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// No response reached the viewer from the broadcaster/signaling layer at
/// all within the connect window.
final class Timeout extends ConnectFailure {
  /// Creates a [Timeout] failure.
  const Timeout();

  @override
  bool operator ==(Object other) => other is Timeout;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Kong rejected the broadcast-resolution request (HTTP 429). Origin:
/// `BroadcastResolution.rateLimited` (`business-rules.md` Rule 5).
final class RateLimited extends ConnectFailure {
  /// Creates a [RateLimited] failure.
  const RateLimited();

  @override
  bool operator ==(Object other) => other is RateLimited;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The resolution or presence read itself errored, so the broadcast's
/// liveness is unknown rather than confirmed offline. Origin:
/// `BroadcastResolution.resolutionFailed`, and the reconnect window
/// expiring with no status emission ever observed
/// (`business-logic-model.md` F-7.4 step 4).
final class ResolutionFailed extends ConnectFailure {
  /// Creates a [ResolutionFailed] failure.
  const ResolutionFailed();

  @override
  bool operator ==(Object other) => other is ResolutionFailed;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// The broadcast code does not exist. Origin:
/// `BroadcastResolution.notFound`. Renders with no retry action — the ID
/// itself is the problem (`business-rules.md` Rule 5).
final class NotFound extends ConnectFailure {
  /// Creates a [NotFound] failure.
  const NotFound();

  @override
  bool operator ==(Object other) => other is NotFound;

  @override
  int get hashCode => runtimeType.hashCode;
}
