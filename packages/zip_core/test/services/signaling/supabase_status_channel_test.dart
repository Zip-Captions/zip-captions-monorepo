import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/signaling/supabase_status_channel.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockRealtimeChannel extends Mock implements RealtimeChannel {}

typedef _SubscribeCallback = void Function(
  RealtimeSubscribeStatus status,
  Object? error,
);

void main() {
  late _MockSupabaseClient client;
  late _MockRealtimeChannel channel;
  late void Function(RealtimePresenceSyncPayload) presenceSyncCallback;

  setUpAll(() {
    registerFallbackValue(const RealtimeChannelConfig());
  });

  setUp(() {
    client = _MockSupabaseClient();
    channel = _MockRealtimeChannel();
    when(() => client.channel(any(), opts: any(named: 'opts')))
        .thenReturn(channel);
    when(() => channel.onPresenceSync(any())).thenAnswer((invocation) {
      presenceSyncCallback =
          invocation.positionalArguments[0] as void Function(
        RealtimePresenceSyncPayload,
      );
      return channel;
    });
    when(() => channel.presenceState()).thenReturn(const []);
    when(() => channel.untrack(any()))
        .thenAnswer((_) async => ChannelResponse.ok);
    when(() => channel.track(any(), any()))
        .thenAnswer((_) async => ChannelResponse.ok);
  });

  void subscribeSucceeds() {
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      final callback =
          invocation.positionalArguments[0] as _SubscribeCallback;
      callback(RealtimeSubscribeStatus.subscribed, null);
      // Real Realtime servers send the presence snapshot once on join,
      // separately from (and not necessarily bundled with) the `subscribed`
      // callback — simulate that here so `watch()`'s wait for the initial
      // sync doesn't hang in tests.
      presenceSyncCallback(
        const RealtimePresenceSyncPayload(event: PresenceEvent.sync),
      );
      return channel;
    });
  }

  void subscribeRejected() {
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      final callback =
          invocation.positionalArguments[0] as _SubscribeCallback;
      callback(RealtimeSubscribeStatus.channelError, 'denied');
      return channel;
    });
  }

  /// Captures `subscribe()`'s callback instead of invoking it immediately,
  /// so a test can simulate the real channel's lifecycle: a first failure,
  /// then a later, separate invocation of the *same* callback (the
  /// channel's own automatic rejoin) — `subscribe()` itself must only ever
  /// be called once.
  _SubscribeCallback captureSubscribeCallback() {
    late _SubscribeCallback captured;
    when(() => channel.subscribe(any())).thenAnswer((invocation) {
      captured = invocation.positionalArguments[0] as _SubscribeCallback;
      return channel;
    });
    return (status, error) => captured(status, error);
  }

  group('SupabaseStatusChannel', () {
    test('publishLive throws BroadcastAuthorizationException when the '
        'subscription is rejected', () async {
      subscribeRejected();
      final statusChannel = SupabaseStatusChannel(
        client: client,
        broadcastIdValue: 'K7M9X2',
      );

      await expectLater(
        statusChannel.publishLive(sessionId: 's1', sessionName: 'My Stream'),
        throwsA(isA<BroadcastAuthorizationException>()),
      );
    });

    test(
      "recovers after a transient subscribe failure via the channel's own "
      'automatic rejoin, without calling subscribe() twice',
      () async {
        final deliver = captureSubscribeCallback();
        final statusChannel = SupabaseStatusChannel(
          client: client,
          broadcastIdValue: 'K7M9X2',
        );

        // Starting (not awaiting) the call synchronously drives
        // `_ensureSubscribed()` into calling `subscribe()`, which is what
        // captures `deliver`'s target callback.
        final firstAttempt = statusChannel.publishLive(
          sessionId: 's1',
          sessionName: 'Stream',
        );
        deliver(RealtimeSubscribeStatus.timedOut, null);
        await expectLater(firstAttempt, throwsA(isA<StateError>()));

        // The channel's own client recovers on its own and re-invokes the
        // same callback with `subscribed` — this must resolve the *next*
        // call, not replay the earlier failure forever.
        deliver(RealtimeSubscribeStatus.subscribed, null);
        presenceSyncCallback(
          const RealtimePresenceSyncPayload(event: PresenceEvent.sync),
        );
        await expectLater(
          statusChannel.publishLive(sessionId: 's2', sessionName: 'Stream 2'),
          completes,
        );

        verify(() => channel.subscribe(any())).called(1);
      },
    );

    test('watch() emits offline when presence state is empty', () async {
      subscribeSucceeds();
      final statusChannel = SupabaseStatusChannel(
        client: client,
        broadcastIdValue: 'K7M9X2',
      );

      final first = statusChannel.watch().first;
      expect(await first, isA<BroadcastStatusOffline>());
    });

    test(
      'watch() waits for the presence sync even when it arrives after '
      'subscribed, instead of reading a stale empty snapshot',
      () async {
        // subscribed fires without a presence sync yet — simulating the
        // real protocol's separate, not-necessarily-bundled messages.
        when(() => channel.subscribe(any())).thenAnswer((invocation) {
          final callback = invocation.positionalArguments[0]
              as _SubscribeCallback;
          callback(RealtimeSubscribeStatus.subscribed, null);
          return channel;
        });
        when(() => channel.presenceState()).thenReturn(const []);
        final statusChannel = SupabaseStatusChannel(
          client: client,
          broadcastIdValue: 'K7M9X2',
        );

        final firstValue = statusChannel.watch().first;

        // The presence sync (carrying the live payload) arrives later.
        await Future<void>.delayed(Duration.zero);
        when(() => channel.presenceState()).thenReturn([
          const SinglePresenceState(
            key: 'broadcaster',
            presences: [
              Presence(
                presenceRef: 'ref-1',
                payload: {'sessionId': 's1', 'sessionName': 'Late Sync'},
              ),
            ],
          ),
        ]);
        presenceSyncCallback(
          const RealtimePresenceSyncPayload(event: PresenceEvent.sync),
        );

        expect(await firstValue, isA<BroadcastStatusLive>());
      },
    );

    test('watch() emits live with the tracked session info', () async {
      subscribeSucceeds();
      when(() => channel.presenceState()).thenReturn([
        const SinglePresenceState(
          key: 'broadcaster',
          presences: [
            Presence(
              presenceRef: 'ref-1',
              payload: {'sessionId': 's1', 'sessionName': 'My Stream'},
            ),
          ],
        ),
      ]);
      final statusChannel = SupabaseStatusChannel(
        client: client,
        broadcastIdValue: 'K7M9X2',
      );

      final status = await statusChannel.watch().first;
      expect(status, isA<BroadcastStatusLive>());
      final live = status as BroadcastStatusLive;
      expect(live.sessionId, 's1');
      expect(live.sessionName, 'My Stream');
    });

    test('a later presence sync updates watchers', () async {
      subscribeSucceeds();
      final statusChannel = SupabaseStatusChannel(
        client: client,
        broadcastIdValue: 'K7M9X2',
      );

      final stream = statusChannel.watch();
      final expectation = expectLater(
        stream,
        emitsInOrder([
          isA<BroadcastStatusOffline>(),
          isA<BroadcastStatusLive>(),
        ]),
      );

      // Let the first (offline) emission land before changing the stub,
      // so the second emission is unambiguously the presence-sync update.
      await Future<void>.delayed(Duration.zero);
      when(() => channel.presenceState()).thenReturn([
        const SinglePresenceState(
          key: 'broadcaster',
          presences: [
            Presence(
              presenceRef: 'ref-1',
              payload: {'sessionId': 's2', 'sessionName': 'Live Now'},
            ),
          ],
        ),
      ]);
      presenceSyncCallback(
        const RealtimePresenceSyncPayload(event: PresenceEvent.sync),
      );

      await expectation;
    });
  });
}
