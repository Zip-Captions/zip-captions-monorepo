import 'package:meta/meta.dart';

/// Why a `ViewerTransport.connect()`/`restart()` attempt terminally failed
/// (FR-7.4 — "cannot connect, with a specific reason").
///
/// Exhaustive by design (`business-rules.md` Rule 3): every rejection/
/// failure path a viewer can observe must resolve to exactly one of these
/// four variants, never a generic fallback.
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
