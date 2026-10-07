import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';

/// Factory for the Realtime/RPC mechanisms this project defines:
/// `status:{broadcast_id}` (Unit 3), the `broadcast_join_requests`
/// table/RPC join-request handshake, and `signaling:{session_id}:{peerId}`
/// (Unit 3.1, SR-04 §3 — replacing Unit 3's original single shared
/// `signaling:{session_id}` channel).
///
/// **Revised 2026-10-06**: the join-request step was originally a
/// `LobbyChannel` wrapping a Realtime Broadcast-extension channel —
/// confirmed unworkable by testing (Realtime's `subscribe()` rejects any
/// client lacking a SELECT grant, regardless of receive intent, so a
/// send-only viewer could never open it). Replaced below with a plain RPC
/// call and a Postgres Changes stream — no channel object for this step at
/// all.
abstract interface class SignalingService {
  /// Opens the status channel for [id].
  StatusChannel statusChannel(BroadcastId id);

  /// Submits a join request for [broadcastId] as [peerId] — viewer-only. A
  /// thin wrapper over the `submit_join_request` RPC; never subscribes to
  /// anything (SR-04 §3).
  Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId);

  /// Incoming join requests for [broadcastId] — broadcaster-only. Wraps a
  /// Postgres Changes subscription on `broadcast_join_requests`, governed by
  /// that table's own RLS (the `broadcast_identities` ownership check,
  /// SR-04 §3) rather than Broadcast-extension RLS.
  Stream<JoinRequest> joinRequests(BroadcastId broadcastId);

  /// Opens the per-viewer signaling channel for [sessionId] and [peerId].
  SessionSignalingChannel sessionChannel(String sessionId, String peerId);
}
