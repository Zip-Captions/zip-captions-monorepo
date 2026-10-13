/// Why `goLive()` failed (fixed shape, Application Design). The
/// step→variant mapping is `business-rules.md` Rule 2.
enum BroadcastFailure {
  /// The caller is not signed in (F2-1).
  signedOut,

  /// `StatusChannel.publishLive` failed (F2-7).
  signalingUnavailable,

  /// `IceServerProvider.iceServersFor` failed (F2-3).
  relayUnavailable,

  /// `BroadcastIdentityRepository.getOrCreateMine` failed (F2-2).
  identityUnavailable,

  /// Any other failure (transport start, target registration) — treated
  /// as a programming/environment error, not a specific user-facing cause.
  unknown,
}
