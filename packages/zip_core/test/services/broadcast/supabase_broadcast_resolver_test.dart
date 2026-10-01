import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_resolution.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/services/broadcast/supabase_broadcast_resolver.dart';
import 'package:zip_core/src/services/signaling/signaling_service.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockSignalingService extends Mock implements SignalingService {}

class _MockStatusChannel extends Mock implements StatusChannel {}

/// A `PostgrestFilterBuilder` stand-in that resolves immediately to a value
/// or throws an error when awaited — `client.rpc<T>()`'s real return type is
/// a builder, not a plain [Future], and PostgREST's PKCE-style
/// builder-chain generics can't be constructed as a real HTTP-backed
/// instance in a unit test. This fake only overrides `then` (the one method
/// `await` actually dispatches through), matching the technique already
/// used in this codebase for `signInWithOAuth`'s extension-method problem.
class _ImmediateBuilder<T> extends Fake implements PostgrestFilterBuilder<T> {
  _ImmediateBuilder.value(T value) : _future = Future<T>.value(value);
  _ImmediateBuilder.error(Object error) : _future = Future<T>.error(error);

  final Future<T> _future;

  @override
  Future<S> then<S>(
    FutureOr<S> Function(T) onValue, {
    Function? onError,
  }) =>
      _future.then(onValue, onError: onError);
}

void main() {
  late _MockSupabaseClient client;
  late _MockSignalingService signalingService;
  late _MockStatusChannel statusChannel;
  late SupabaseBroadcastResolver resolver;
  final id = BroadcastId.parse('K7M9X2');

  setUpAll(() {
    registerFallbackValue(BroadcastId.parse('AAAAAA'));
  });

  setUp(() {
    client = _MockSupabaseClient();
    signalingService = _MockSignalingService();
    statusChannel = _MockStatusChannel();
    when(() => signalingService.statusChannel(any()))
        .thenReturn(statusChannel);
    when(() => statusChannel.close()).thenAnswer((_) async {});
    resolver = SupabaseBroadcastResolver(
      client: client,
      signalingService: signalingService,
    );
  });

  void stubRpc(_ImmediateBuilder<bool> builder) {
    when(
      () => client.rpc<bool>(
        'resolve_broadcast_id',
        params: any(
          named: 'params',
          that: equals({'p_broadcast_id': 'K7M9X2'}),
        ),
      ),
    ).thenAnswer((_) => builder);
  }

  group('SupabaseBroadcastResolver.resolve', () {
    test('resolves to notFound when the RPC returns false', () async {
      stubRpc(_ImmediateBuilder<bool>.value(false));

      final result = await resolver.resolve(id);

      expect(result, isA<BroadcastNotFound>());
      verifyNever(() => signalingService.statusChannel(any()));
    });

    test('resolves to offline when presence has no entries', () async {
      stubRpc(_ImmediateBuilder<bool>.value(true));
      when(() => statusChannel.watch())
          .thenAnswer((_) => Stream.value(const BroadcastStatus.offline()));

      final result = await resolver.resolve(id);

      expect(result, isA<BroadcastOffline>());
    });

    test('resolves to live with the tracked session info', () async {
      stubRpc(_ImmediateBuilder<bool>.value(true));
      when(() => statusChannel.watch()).thenAnswer(
        (_) => Stream.value(
          const BroadcastStatus.live(sessionId: 's1', sessionName: 'Live!'),
        ),
      );

      final result = await resolver.resolve(id);

      expect(result, isA<BroadcastLive>());
      final live = result as BroadcastLive;
      expect(live.sessionId, 's1');
      expect(live.sessionName, 'Live!');
    });

    test(
      'resolves to resolutionFailed when the presence read errors, not '
      'offline',
      () async {
        stubRpc(_ImmediateBuilder<bool>.value(true));
        when(() => statusChannel.watch())
            .thenAnswer((_) => Stream.error(StateError('channel rejected')));

        final result = await resolver.resolve(id);

        expect(result, isA<BroadcastResolutionFailed>());
      },
    );

    test(
      'resolves to resolutionFailed when the presence read times out',
      () async {
        stubRpc(_ImmediateBuilder<bool>.value(true));
        when(() => statusChannel.watch()).thenAnswer(
          (_) => StreamController<BroadcastStatus>().stream, // never emits
        );

        final result = await resolver.resolve(
          id,
        ).timeout(const Duration(seconds: 10));

        expect(result, isA<BroadcastResolutionFailed>());
      },
    );

    test('resolves to rateLimited for a code-less rate-limit rejection',
        () async {
      stubRpc(
        _ImmediateBuilder<bool>.error(
          const PostgrestException(message: 'API rate limit exceeded'),
        ),
      );

      final result = await resolver.resolve(id);

      expect(result, isA<BroadcastRateLimited>());
    });

    test(
      'resolves to resolutionFailed for any other step-1 PostgrestException',
      () async {
        stubRpc(
          _ImmediateBuilder<bool>.error(
            const PostgrestException(
              message: 'connection reset',
              code: '08006',
            ),
          ),
        );

        final result = await resolver.resolve(id);

        expect(result, isA<BroadcastResolutionFailed>());
      },
    );

    test('resolves to resolutionFailed for a non-Postgrest step-1 failure',
        () async {
      stubRpc(_ImmediateBuilder<bool>.error(StateError('network down')));

      final result = await resolver.resolve(id);

      expect(result, isA<BroadcastResolutionFailed>());
    });

    test('closes the status channel after resolving', () async {
      stubRpc(_ImmediateBuilder<bool>.value(true));
      when(() => statusChannel.watch())
          .thenAnswer((_) => Stream.value(const BroadcastStatus.offline()));

      await resolver.resolve(id);

      verify(() => statusChannel.close()).called(1);
    });
  });
}
