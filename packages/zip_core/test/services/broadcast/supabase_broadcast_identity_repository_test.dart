import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/broadcast/supabase_broadcast_identity_repository.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

void main() {
  late _MockSupabaseClient client;
  late SupabaseBroadcastIdentityRepository repository;

  setUp(() {
    client = _MockSupabaseClient();
    repository = SupabaseBroadcastIdentityRepository(client: client);
  });

  group('SupabaseBroadcastIdentityRepository.getOrCreateMine', () {
    // The success path (actual id allocation, idempotence, collision
    // handling) is a database/RLS behavior implemented entirely inside the
    // `get_or_create_my_broadcast_id` Postgres function (SR-02 §3) — it is
    // covered by the integration tests against the local Supabase stack
    // (testable-properties.md's "Stateful / Integration-Level Properties"),
    // not here. This unit test covers only the one piece of real
    // client-side logic: mapping a permission-denied rejection to
    // `BroadcastAuthorizationException` while leaving every other failure
    // to propagate unmapped.

    test(
      'maps a 42501 (insufficient privilege) PostgrestException to '
      'BroadcastAuthorizationException',
      () async {
        when(() => client.rpc<String>('get_or_create_my_broadcast_id'))
            .thenThrow(
          const PostgrestException(
            message: 'new row violates row-level security policy',
            code: '42501',
          ),
        );

        await expectLater(
          repository.getOrCreateMine(),
          throwsA(isA<BroadcastAuthorizationException>()),
        );
      },
    );

    test(
      'rethrows a PostgrestException with any other code unmapped',
      () async {
        when(() => client.rpc<String>('get_or_create_my_broadcast_id'))
            .thenThrow(
          const PostgrestException(message: 'connection reset', code: '08006'),
        );

        await expectLater(
          repository.getOrCreateMine(),
          throwsA(isA<PostgrestException>()),
        );
      },
    );

    test('rethrows a non-Postgrest failure unmapped', () async {
      when(() => client.rpc<String>('get_or_create_my_broadcast_id'))
          .thenThrow(const SocketExceptionStub());

      await expectLater(
        repository.getOrCreateMine(),
        throwsA(isA<SocketExceptionStub>()),
      );
    });
  });
}

/// A stand-in for a plain network failure (e.g. `SocketException`), without
/// pulling in `dart:io` just for this one test.
class SocketExceptionStub implements Exception {
  const SocketExceptionStub();
}
