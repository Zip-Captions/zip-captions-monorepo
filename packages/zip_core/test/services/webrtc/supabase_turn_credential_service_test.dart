import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/services/webrtc/supabase_turn_credential_service.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

/// A `PostgrestFilterBuilder` stand-in that resolves immediately to a value
/// or throws an error when awaited — see
/// `test/services/broadcast/supabase_broadcast_resolver_test.dart` for why
/// a real builder instance can't be constructed in a unit test.
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
  late SupabaseTurnCredentialService service;

  setUp(() {
    client = _MockSupabaseClient();
    service = SupabaseTurnCredentialService(client: client);
  });

  void stubRpc(_ImmediateBuilder<List<dynamic>> builder) {
    when(() => client.rpc<List<dynamic>>('get_turn_credentials'))
        .thenAnswer((_) => builder);
  }

  group('SupabaseTurnCredentialService.fetch', () {
    test(
      'maps the single-row get_turn_credentials() result into '
      'TurnCredentials, deriving expiresAt from ttl',
      () async {
        stubRpc(
          _ImmediateBuilder<List<dynamic>>.value([
            {
              'username': '1735689600',
              'credential': 'abc123==',
              'ttl': 3600,
              'urls': ['turn:localhost:3478', 'stun:localhost:3478'],
            },
          ]),
        );

        final before = DateTime.now().toUtc();
        final result = await service.fetch('session-1');
        final after = DateTime.now().toUtc();

        expect(result.username, '1735689600');
        expect(result.credential, 'abc123==');
        expect(result.urls, ['turn:localhost:3478', 'stun:localhost:3478']);
        expect(
          result.expiresAt.isAfter(before.add(const Duration(seconds: 3599))),
          isTrue,
        );
        expect(
          result.expiresAt
              .isBefore(after.add(const Duration(seconds: 3601))),
          isTrue,
        );
      },
    );

    test(
      'propagates a PostgrestException uncaught (no retry, no fallback — '
      'NFR Design Q1)',
      () async {
        stubRpc(
          _ImmediateBuilder<List<dynamic>>.error(
            const PostgrestException(
              message: 'new row violates row-level security policy',
              code: '42501',
            ),
          ),
        );

        await expectLater(
          service.fetch('session-1'),
          throwsA(isA<PostgrestException>()),
        );
      },
    );
  });
}
