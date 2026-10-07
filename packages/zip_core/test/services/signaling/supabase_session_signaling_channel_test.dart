import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/signaling_codec.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/signaling/supabase_session_signaling_channel.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

void main() {
  late _MockSupabaseClient client;
  late _MockRealtimeChannel channel;
  late void Function(Map<String, dynamic>) broadcastCallback;

  setUpAll(() {
    registerFallbackValue(const RealtimeChannelConfig());
  });

  setUp(() {
    client = _MockSupabaseClient();
    channel = _MockRealtimeChannel();
    when(() => client.channel(any(), opts: any(named: 'opts')))
        .thenReturn(channel);
    when(
      () => channel.onBroadcast(
        event: any(named: 'event'),
        callback: any(named: 'callback'),
      ),
    ).thenAnswer((invocation) {
      broadcastCallback = invocation.namedArguments[#callback]
          as void Function(Map<String, dynamic>);
      return channel;
    });
    when(() => channel.sendBroadcastMessage(
          event: any(named: 'event'),
          payload: any(named: 'payload'),
        )).thenAnswer((_) async => ChannelResponse.ok);
  });

  group('SupabaseSessionSignalingChannel.messages', () {
    test('decodes a valid incoming payload', () async {
      final sessionChannel = SupabaseSessionSignalingChannel(
        client: client,
        sessionId: 'session-1',
        peerId: 'peer-1',
      );

      final received = <SignalingMessage>[];
      sessionChannel.messages.listen(received.add);

      const message = Leave(fromPeerId: 'peer-1');
      broadcastCallback(SignalingCodec.encode(message));

      await Future<void>.delayed(Duration.zero);
      expect(received, [message]);
    });

    test('drops a malformed incoming payload instead of throwing', () async {
      final sessionChannel = SupabaseSessionSignalingChannel(
        client: client,
        sessionId: 'session-1',
        peerId: 'peer-1',
      );

      final received = <SignalingMessage>[];
      sessionChannel.messages.listen(received.add);

      expect(
        () => broadcastCallback(
          {'messageType': 'totallyUnknown', 'version': 1},
        ),
        returnsNormally,
      );

      await Future<void>.delayed(Duration.zero);
      expect(received, isEmpty);
    });
  });

  group('SupabaseSessionSignalingChannel.send', () {
    test('encodes the message onto the signal broadcast event', () async {
      final sessionChannel = SupabaseSessionSignalingChannel(
        client: client,
        sessionId: 'session-1',
        peerId: 'peer-1',
      );

      const message = Leave(fromPeerId: 'peer-1');
      await sessionChannel.send(message);

      final captured = verify(
        () => channel.sendBroadcastMessage(
          event: 'signal',
          payload: captureAny(named: 'payload'),
        ),
      ).captured;
      expect(captured.single, SignalingCodec.encode(message));
    });
  });
}
