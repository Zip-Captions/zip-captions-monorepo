import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/services/signaling/supabase_signaling_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

/// `SupabaseClient.rpc` returns a `PostgrestFilterBuilder<T>` (which
/// implements `Future<T>`), not a plain `Future<T>` — mocktail's
/// `thenAnswer` must return that exact type, not just an awaitable one.
/// Same pattern as `supabase_broadcast_resolver_test.dart`.
class _ImmediateBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _ImmediateBuilder.value(T value) : _future = Future<T>.value(value);

  final Future<T> _future;

  @override
  Future<S> then<S>(FutureOr<S> Function(T) onValue, {Function? onError}) =>
      _future.then(onValue, onError: onError);
}

void main() {
  late _MockSupabaseClient client;
  late _MockRealtimeChannel channel;

  setUpAll(() {
    registerFallbackValue(const RealtimeChannelConfig());
    registerFallbackValue(PostgresChangeEvent.insert);
    registerFallbackValue(
      const PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'broadcast_id',
        value: '',
      ),
    );
  });

  setUp(() {
    client = _MockSupabaseClient();
    channel = _MockRealtimeChannel();
    when(() => client.channel(any(), opts: any(named: 'opts')))
        .thenReturn(channel);
    // Needed for StatusChannel's own construction (unaffected by this
    // unit) — SessionSignalingChannel no longer calls onPresenceSync at
    // all.
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

    test(
      'sessionChannel opens a private channel named '
      'signaling:{sessionId}:{peerId}',
      () {
        SupabaseSignalingService(
          client: client,
        ).sessionChannel('session-123', 'peer-abc');

        final captured = verify(
          () => client.channel(
            'signaling:session-123:peer-abc',
            opts: captureAny(named: 'opts'),
          ),
        ).captured;
        expect((captured.single as RealtimeChannelConfig).private, isTrue);
      },
    );

    test(
      'submitJoinRequest calls submit_join_request with broadcastId and '
      'peerId',
      () async {
        when(
          () => client.rpc<void>(
            'submit_join_request',
            params: any(named: 'params'),
          ),
        ).thenAnswer((_) => _ImmediateBuilder<void>.value(null));

        await SupabaseSignalingService(client: client)
            .submitJoinRequest(BroadcastId.parse('K7M9X2'), 'peer-abc');

        verify(
          () => client.rpc<void>(
            'submit_join_request',
            params: {'p_broadcast_id': 'K7M9X2', 'p_peer_id': 'peer-abc'},
          ),
        ).called(1);
      },
    );

    test(
      'joinRequests subscribes to Postgres Changes on '
      'broadcast_join_requests filtered by broadcastId',
      () {
        when(
          () => channel.onPostgresChanges(
            event: any(named: 'event'),
            schema: any(named: 'schema'),
            table: any(named: 'table'),
            filter: any(named: 'filter'),
            callback: any(named: 'callback'),
          ),
        ).thenReturn(channel);
        when(() => channel.subscribe()).thenReturn(channel);
        when(() => channel.unsubscribe()).thenAnswer((_) async => 'ok');

        final subscription = SupabaseSignalingService(client: client)
            .joinRequests(BroadcastId.parse('K7M9X2'))
            .listen((_) {});
        unawaited(subscription.cancel());

        verify(
          () => client.channel('broadcast_join_requests:K7M9X2'),
        ).called(1);
        final captured = verify(
          () => channel.onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'broadcast_join_requests',
            filter: captureAny(named: 'filter'),
            callback: any(named: 'callback'),
          ),
        ).captured;
        final filter = captured.single as PostgresChangeFilter;
        expect(filter.column, 'broadcast_id');
        expect(filter.value, 'K7M9X2');
      },
    );
  });
}
