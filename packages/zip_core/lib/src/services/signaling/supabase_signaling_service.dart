import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
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
  SessionSignalingChannel sessionChannel(
    String sessionId,
    SignalingRole role,
  ) =>
      SupabaseSessionSignalingChannel(
        client: _client,
        sessionId: sessionId,
        role: role,
      );
}
