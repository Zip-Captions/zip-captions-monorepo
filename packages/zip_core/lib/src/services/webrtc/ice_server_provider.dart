import 'package:zip_core/src/models/ice_server.dart';

/// Returns the ICE server list to configure a WebRTC peer connection with.
///
/// Fixed at Application Design (`phase2-component-methods.md`).
///
/// Deliberately a single-method interface (not a top-level function) so it
/// has a seam for test doubles, matching this project's other `Supabase*`
/// adapters.
// ignore: one_member_abstracts
abstract interface class IceServerProvider {
  /// Returns the [IceServer] list for [sessionId].
  ///
  /// Any failure (e.g. from the underlying `TurnCredentialService`)
  /// propagates uncaught — no retry, no STUN-only fallback (NFR Design
  /// Q1).
  Future<List<IceServer>> iceServersFor(String sessionId);
}
