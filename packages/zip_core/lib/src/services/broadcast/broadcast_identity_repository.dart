import 'package:zip_core/src/models/broadcast_id.dart';

/// Allocates and retrieves a broadcaster's permanent [BroadcastId].
///
/// Lives in `zip_core` (not `zip_broadcast`) mirroring Unit 2's
/// `AuthService` placement — the identity concept is not inherently
/// broadcast-app-specific even though only `zip_broadcast` uses it in
/// Phase 2.
///
/// Deliberately a single-method interface (not a top-level function) so it
/// has a seam for test doubles, matching this unit's other `Supabase*`
/// adapters.
// ignore: one_member_abstracts
abstract interface class BroadcastIdentityRepository {
  /// Returns the calling authenticated user's [BroadcastId], allocating one
  /// on first call. Idempotent: subsequent calls for the same user return
  /// the same id (SR-02 §3, business-rules.md Rule 1).
  ///
  /// Throws `BroadcastAuthorizationException` if the server rejects the
  /// call as a permission-denied/RLS violation (e.g. called while signed
  /// out). Any other failure (network, timeout) propagates as the
  /// underlying exception.
  Future<BroadcastId> getOrCreateMine();
}
