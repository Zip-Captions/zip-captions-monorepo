import 'package:zip_core/src/models/turn_credentials.dart';

/// Fetches a short-term TURN credential for the given session.
///
/// Fixed at Application Design (`phase2-component-methods.md`).
///
/// Deliberately a single-method interface (not a top-level function) so it
/// has a seam for test doubles, matching this project's other `Supabase*`
/// adapters.
// ignore: one_member_abstracts
abstract interface class TurnCredentialService {
  /// Returns a fresh [TurnCredentials] for [sessionId].
  ///
  /// Any failure (network, timeout, RLS/permission rejection) propagates
  /// uncaught — no retry, no fallback (NFR Design Q1). The caller (Unit 5's
  /// transport layer) owns surfacing a session-start failure.
  Future<TurnCredentials> fetch(String sessionId);
}
