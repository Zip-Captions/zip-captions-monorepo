import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/supabase_signaling_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

void main() {
  late _MockSupabaseClient client;
  late _MockRealtimeChannel channel;

  setUpAll(() {
    registerFallbackValue(const RealtimeChannelConfig());
  });

  setUp(() {
    client = _MockSupabaseClient();
    channel = _MockRealtimeChannel();
    when(() => client.channel(any(), opts: any(named: 'opts')))
        .thenReturn(channel);
    when(() => channel.onPresenceSync(any())).thenReturn(channel);
    when(
      () => channel.onBroadcast(
        event: any(named: 'event'),
        callback: any(named: 'callback'),
      ),
    ).thenReturn(channel);
  });

  group('SupabaseSignalingService', () {
    test('statusChannel opens a private channel named status:{id}', () {
      SupabaseSignalingService(client: client)
          .statusChannel(BroadcastId.parse('K7M9X2'));

      final captured = verify(
        () =>
            client.channel('status:K7M9X2', opts: captureAny(named: 'opts')),
      ).captured;
      expect((captured.single as RealtimeChannelConfig).private, isTrue);
    });

    test('sessionChannel opens a private channel named signaling:{id}', () {
      SupabaseSignalingService(
        client: client,
      ).sessionChannel('session-123', SignalingRole.viewer);

      final captured = verify(
        () => client.channel(
          'signaling:session-123',
          opts: captureAny(named: 'opts'),
        ),
      ).captured;
      expect((captured.single as RealtimeChannelConfig).private, isTrue);
    });
  });
}
