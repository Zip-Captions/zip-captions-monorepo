import 'package:zip_core/src/models/ice_server.dart';

/// Returns the ICE server list to configure a WebRTC peer connection with.
///
/// Fixed at Application Design (`phase2-component-methods.md`).
///
/// Deliberately a single-method interface (not a top-level function) so it
/// has a seam for test doubles, matching this project's other `Supabase*`
/// adapters.
abstract interface class IceServerProvider {
  /// Returns the [IceServer] list for [sessionId].
  ///
  /// Any failure (e.g. from the underlying `TurnCredentialService`)
  /// propagates uncaught — no retry, no STUN-only fallback (NFR Design
  /// Q1).
  Future<List<IceServer>> iceServersFor(String sessionId);

  /// Returns the [IceServer] list for a viewer joining [broadcastId].
  ///
  /// Added by Unit 9 (B2): the viewer is anonymous, so it cannot use the
  /// authenticated credential path. Same failure contract as
  /// [iceServersFor].
  Future<List<IceServer>> iceServersForBroadcast(String broadcastId);
}
