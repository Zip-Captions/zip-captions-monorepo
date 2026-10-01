/// The value a `StatusChannel` watch emits: live or offline.
///
/// The same shape as `BroadcastResolution`'s `live`/`offline` variants minus
/// `notFound`/`rateLimited`, since a `StatusChannel` is only ever opened for
/// a code already known to exist. Presence-expiry (Realtime's own platform
/// behavior, Spike 2.1's 60s interim timeout) transitions a stale `live` to
/// `offline` automatically — this type does not implement a parallel
/// heartbeat (Rule 6, `business-rules.md`).
sealed class BroadcastStatus {
  const BroadcastStatus();

  /// A broadcaster is currently publishing.
  const factory BroadcastStatus.live({
    required String sessionId,
    required String sessionName,
  }) = BroadcastStatusLive;

  /// No broadcaster is currently publishing (including after presence
  /// expiry).
  const factory BroadcastStatus.offline() = BroadcastStatusOffline;
}

/// {@macro broadcast_status.live}
final class BroadcastStatusLive extends BroadcastStatus {
  /// Creates the live status for the given [sessionId]/[sessionName].
  const BroadcastStatusLive({
    required this.sessionId,
    required this.sessionName,
  });

  /// The live session's own id. Never an account identifier.
  final String sessionId;

  /// The live session's display name.
  final String sessionName;
}

/// {@macro broadcast_status.offline}
final class BroadcastStatusOffline extends BroadcastStatus {
  /// Creates the offline status.
  const BroadcastStatusOffline();
}
