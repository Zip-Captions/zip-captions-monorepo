import 'package:meta/meta.dart';
import 'package:zip_core/src/models/connect_failure.dart';

/// How a viewer's peer connection is currently routed (FR-4.6). Derived from
/// the peer connection's own candidate-pair selection, never inferred from
/// network heuristics.
enum ConnectionType {
  /// A direct host-candidate peer-to-peer path.
  p2pDirect,

  /// Routed through Coturn's TURN relay.
  turnRelayed,

  /// Negotiation is still in progress.
  connecting,

  /// No usable candidate pair currently exists.
  disconnected,
}

/// A viewer's own connection health, as surfaced by `ViewerTransport.status`
/// (FR-7.4's fixed set of viewer-visible states).
@immutable
sealed class ConnectionStatus {
  const ConnectionStatus();
}

/// Negotiating — no `JoinAccepted`/`JoinRejected` received yet.
final class Connecting extends ConnectionStatus {
  /// Creates a [Connecting] status.
  const Connecting();

  @override
  bool operator ==(Object other) => other is Connecting;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Connected, with the current routing [connectionType].
final class Connected extends ConnectionStatus {
  /// Creates a [Connected] status for [connectionType].
  const Connected(this.connectionType);

  /// How this connection is currently routed.
  final ConnectionType connectionType;

  @override
  bool operator ==(Object other) =>
      other is Connected && other.connectionType == connectionType;

  @override
  int get hashCode => connectionType.hashCode;
}

/// The FR-7.4 "reconnecting" state — a stable, non-failing state a viewer
/// may remain in indefinitely while `WebRtcViewerTransport`'s backoff retry
/// loop runs (`business-rules.md` Rule 2). Never times out into [Failed] on
/// its own.
final class Interrupted extends ConnectionStatus {
  /// Creates an [Interrupted] status.
  const Interrupted();

  @override
  bool operator ==(Object other) => other is Interrupted;

  @override
  int get hashCode => runtimeType.hashCode;
}

/// Terminally failed, for [failure]. Reachable only via an explicit
/// `disconnect()` or the broadcast itself ending — never via retry-count
/// exhaustion alone.
final class Failed extends ConnectionStatus {
  /// Creates a [Failed] status for [failure].
  const Failed(this.failure);

  /// Why the connection terminally failed.
  final ConnectFailure failure;

  @override
  bool operator ==(Object other) =>
      other is Failed && other.failure == failure;

  @override
  int get hashCode => failure.hashCode;
}
