import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/presence_snapshot.dart';
import 'package:zip_core/src/models/signaling_codec.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/signaling/session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';

/// Realtime-backed [SessionSignalingChannel] for `signaling:{session_id}`
/// (SR-02 §4).
///
/// Every peer (broadcaster or viewer) tracks its own (empty) presence entry
/// on open, which is what makes the viewer-count read possible. [role] is
/// carried for the caller's own bookkeeping only — RLS restricts the
/// `presence` read to `authenticated` callers (anon cannot read it), but
/// **not** to the broadcaster specifically (see `SessionSignalingChannel
/// .presence`'s doc comment for why: no persisted session-owner mapping
/// exists to check against, per FR-2.6). A viewer-opened instance does
/// receive `presence` events.
class SupabaseSessionSignalingChannel implements SessionSignalingChannel {
  /// Creates a [SupabaseSessionSignalingChannel] for [sessionId], opened in
  /// [role].
  SupabaseSessionSignalingChannel({
    required SupabaseClient client,
    required String sessionId,
    required this.role,
  }) : _channel = client.channel(
          'signaling:$sessionId',
          opts: const RealtimeChannelConfig(private: true),
        ) {
    _channel
      ..onBroadcast(
        event: _signalEvent,
        callback: (payload) {
          final message = SignalingCodec.decode(payload);
          if (message != null) _messagesController.add(message);
        },
      )
      ..onPresenceSync((_) {
        final states = _channel.presenceState();
        _presenceController.add(
          PresenceSnapshot(peerIds: states.map((s) => s.key).toList()),
        );
      });
  }

  static const String _signalEvent = 'signal';

  /// The role this channel was opened as. Carried for callers' own
  /// bookkeeping — RLS, not this field, is what enforces channel-level
  /// authorization; per-message-type authorization is Unit 5's concern.
  final SignalingRole role;

  final RealtimeChannel _channel;
  final _messagesController = StreamController<SignalingMessage>.broadcast();
  final _presenceController = StreamController<PresenceSnapshot>.broadcast();

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
    await _channel.track(const <String, Object?>{});
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
  Stream<PresenceSnapshot> get presence => _presenceController.stream;

  @override
  Future<void> close() async {
    await _channel.unsubscribe();
    await _messagesController.close();
    await _presenceController.close();
  }
}
