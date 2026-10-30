import 'package:zip_core/src/models/turn_credentials.dart';

/// Fetches a short-term TURN credential for the given session.
///
/// Fixed at Application Design (`phase2-component-methods.md`).
///
/// Deliberately a single-method interface (not a top-level function) so it
/// has a seam for test doubles, matching this project's other `Supabase*`
/// adapters.
abstract interface class TurnCredentialService {
  /// Returns a fresh [TurnCredentials] for [sessionId].
  ///
  /// Any failure (network, timeout, RLS/permission rejection) propagates
  /// uncaught — no retry, no fallback (NFR Design Q1). The caller (Unit 5's
  /// transport layer) owns surfacing a session-start failure.
  Future<TurnCredentials> fetch(String sessionId);

  /// Returns a fresh [TurnCredentials] for a viewer joining
  /// [broadcastId].
  ///
  /// Added by Unit 9 (B2). A viewer has no account and therefore no
  /// `auth.uid()`, so it cannot use [fetch]; and it has no
  /// `broadcastId`-to-session mapping to hand over either, since session
  /// ids are ephemeral and never persisted (FR-2.6, SR-02 §1). The broadcast
  /// id is the one identifier both the viewer and the server already know.
  ///
  /// Failure propagates uncaught, exactly as [fetch] — no retry, no
  /// downgrade to the authenticated path.
  Future<TurnCredentials> fetchBroadcast(String broadcastId);
}
