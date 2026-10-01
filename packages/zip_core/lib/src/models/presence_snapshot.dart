/// A snapshot of currently-tracked peer ids on a session's
/// `signaling:{session_id}` presence channel.
///
/// Carries no per-viewer identity beyond the ephemeral peer id (never a
/// `viewerIdentity`, which is always `null` in Phase 2 — FR-3.5). [count] is
/// derived from [peerIds]' length, used by the broadcaster's dashboard
/// (Unit 6) against the capacity cap (FR-8.3) and by Unit 5's viewer
/// admission for capacity enforcement.
class PresenceSnapshot {
  /// Creates a snapshot of the given [peerIds].
  const PresenceSnapshot({required this.peerIds});

  /// The ephemeral peer ids currently tracked on the channel.
  final List<String> peerIds;

  /// The number of currently-tracked peers.
  int get count => peerIds.length;
}
