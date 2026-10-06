import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';
import 'package:zip_core/src/services/signaling/supabase_session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/supabase_status_channel.dart';

/// Realtime-backed [SignalingService].
///
/// A thin factory: every channel it creates is `private: true` (SR-02 §4's
/// precondition for RLS to apply at all) — callers get a fresh channel
/// instance per call, never a cached/shared one, since a status channel and
/// a session channel are each owned by exactly one caller's lifecycle.
///
/// [submitJoinRequest]/[joinRequests] are RPC/Postgres-Changes-backed, not
/// channel-backed (SR-04 §3, revised 2026-10-06) — the original
/// `LobbyChannel` design is gone; see `signaling_service.dart`'s doc
/// comment for why.
class SupabaseSignalingService implements SignalingService {
  /// Creates a [SupabaseSignalingService] backed by [client].
  const SupabaseSignalingService({required SupabaseClient client})
      : _client = client;

  final SupabaseClient _client;

  @override
  StatusChannel statusChannel(BroadcastId id) => SupabaseStatusChannel(
        client: _client,
        broadcastIdValue: id.value,
      );

  @override
  Future<void> submitJoinRequest(BroadcastId broadcastId, String peerId) =>
      _client.rpc<void>(
        'submit_join_request',
        params: {'p_broadcast_id': broadcastId.value, 'p_peer_id': peerId},
      );

  @override
  Stream<JoinRequest> joinRequests(BroadcastId broadcastId) =>
      Stream<JoinRequest>.multi((controller) {
        final channel = _client.channel(
          'broadcast_join_requests:${broadcastId.value}',
        );
        channel
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'broadcast_join_requests',
              filter: PostgresChangeFilter(
                type: PostgresChangeFilterType.eq,
                column: 'broadcast_id',
                value: broadcastId.value,
              ),
              callback: (payload) {
                final row = payload.newRecord;
                final requestId = row['id'] as String;
                final peerId = row['peer_id'] as String;
                controller.add(JoinRequest(fromPeerId: peerId));
                unawaited(
                  _client.rpc<void>(
                    'consume_join_request',
                    params: {'p_request_id': requestId},
                  ),
                );
              },
            )
            .subscribe();
        controller.onCancel = channel.unsubscribe;
      });

  @override
  SessionSignalingChannel sessionChannel(String sessionId, String peerId) =>
      SupabaseSessionSignalingChannel(
        client: _client,
        sessionId: sessionId,
        peerId: peerId,
      );
}
