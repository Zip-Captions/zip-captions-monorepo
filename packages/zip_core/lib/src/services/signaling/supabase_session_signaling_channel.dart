import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/signaling_codec.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';

/// Realtime-backed [SessionSignalingChannel] for
/// `signaling:{session_id}:{peerId}` (SR-04 §3).
///
/// Opened identically by both the broadcaster (once per accepted viewer)
/// and that one viewer — unlike Unit 3's original, this channel's topic
/// name is scoped to exactly two participants, so RLS stays deliberately
/// symmetric (no ownership check, see the migration's own comments). No
/// presence tracking (dropped entirely, SR-04 §4) — this class never calls
/// `track()` or wires `onPresenceSync`.
class SupabaseSessionSignalingChannel implements SessionSignalingChannel {
  /// Creates a [SupabaseSessionSignalingChannel] for [sessionId] and
  /// [peerId].
  SupabaseSessionSignalingChannel({
    required SupabaseClient client,
    required String sessionId,
    required String peerId,
  }) : _channel = client.channel(
          'signaling:$sessionId:$peerId',
          opts: const RealtimeChannelConfig(private: true),
        ) {
    _channel.onBroadcast(
      event: _signalEvent,
      callback: (payload) {
        final message = SignalingCodec.decode(payload);
        if (message != null) _messagesController.add(message);
      },
    );
  }

  static const String _signalEvent = 'signal';

  final RealtimeChannel _channel;
  final _messagesController = StreamController<SignalingMessage>.broadcast();

  @override
  Future<void> open() async {
    final completer = Completer<void>();
    _channel.subscribe((status, error) {
      if (completer.isCompleted) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          completer.complete();
        case RealtimeSubscribeStatus.channelError:
          completer.completeError(
            BroadcastAuthorizationException(
              error?.toString() ??
                  'signaling channel subscription rejected',
            ),
          );
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          completer.completeError(
            StateError('signaling channel subscription $status'),
          );
      }
    });
    await completer.future;
  }

  @override
  Future<void> send(SignalingMessage message) async {
    await _channel.sendBroadcastMessage(
      event: _signalEvent,
      payload: SignalingCodec.encode(message),
    );
  }

  @override
  Stream<SignalingMessage> get messages => _messagesController.stream;

  @override
  Future<void> close() async {
    await _channel.unsubscribe();
    await _messagesController.close();
  }
}
