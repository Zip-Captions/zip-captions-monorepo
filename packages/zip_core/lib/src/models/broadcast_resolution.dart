/// The outcome of resolving a broadcast id to a live/offline status.
///
/// Exactly one variant per `resolve()` call (`domain-entities.md`). Note the
/// deliberate distinction between [BroadcastOffline] (the presence read
/// completed and found nothing — a confirmed, stable result) and
/// [BroadcastResolutionFailed] (the presence read itself errored or timed
/// out — status is genuinely unknown, added at NFR Design 2026-09-30 to
/// avoid misreporting a transient glitch as the broadcast having ended).
sealed class BroadcastResolution {
  const BroadcastResolution();

  /// `resolve_broadcast_id` returned `false` — the code doesn't exist.
  const factory BroadcastResolution.notFound() = BroadcastNotFound;

  /// The code exists; the presence read completed and found no live
  /// broadcaster.
  const factory BroadcastResolution.offline() = BroadcastOffline;

  /// The code exists and a broadcaster is currently publishing. Carries only
  /// the session's own id and display name — never an account identifier
  /// (NFR-3.5).
  const factory BroadcastResolution.live({
    required String sessionId,
    required String sessionName,
  }) = BroadcastLive;

  /// Kong rejected the resolution request. Unreachable until Kong's rate
  /// limit is configured (Infrastructure Design); the variant is kept
  /// regardless so callers don't need a later breaking change.
  const factory BroadcastResolution.rateLimited() = BroadcastRateLimited;

  /// The code exists (step 1 succeeded) but the presence read (step 2)
  /// itself failed or timed out — live/offline status is unknown, not
  /// confirmed offline. Callers may retry; unlike [BroadcastOffline], this
  /// is not a stable result.
  const factory BroadcastResolution.resolutionFailed() =
      BroadcastResolutionFailed;
}

/// {@macro broadcast_resolution.notFound}
final class BroadcastNotFound extends BroadcastResolution {
  /// Creates the not-found resolution.
  const BroadcastNotFound();
}

/// {@macro broadcast_resolution.offline}
final class BroadcastOffline extends BroadcastResolution {
  /// Creates the offline resolution.
  const BroadcastOffline();
}

/// {@macro broadcast_resolution.live}
final class BroadcastLive extends BroadcastResolution {
  /// Creates the live resolution for the given [sessionId]/[sessionName].
  const BroadcastLive({required this.sessionId, required this.sessionName});

  /// The live session's own id. Never an account identifier.
  final String sessionId;

  /// The live session's display name.
  final String sessionName;
}

/// {@macro broadcast_resolution.rateLimited}
final class BroadcastRateLimited extends BroadcastResolution {
  /// Creates the rate-limited resolution.
  const BroadcastRateLimited();
}

/// {@macro broadcast_resolution.resolutionFailed}
final class BroadcastResolutionFailed extends BroadcastResolution {
  /// Creates the resolution-failed outcome.
  const BroadcastResolutionFailed();
}
