/// Integration test for the `broadcast_identities` registry (Unit 3, S-11)
/// against a real local Supabase stack — covers exactly the
/// "Stateful / Integration-Level Properties" `testable-properties.md`
/// carries forward from PBT (not exercisable by the in-process PBT shim,
/// which has no database): `get_or_create_my_broadcast_id()`'s
/// per-user idempotence and cross-user uniqueness, and the anonymous
/// `resolve_broadcast_id` RLS boundary.
///
/// **Requires the local Supabase stack running first**:
/// ```sh
/// cd packages/zip_supabase
/// docker compose up -d
/// supabase db reset   # applies migrations, including
///                      # 20261001000000_broadcast_identity_signaling.sql
/// ```
/// Not run by default or in CI (see `dart_test.yaml`). Run explicitly with:
/// ```sh
/// flutter test --tags integration-supabase --run-skipped \
///   test/integration/broadcast_identity_supabase_test.dart
/// ```
@Tags(['integration-supabase'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/services/broadcast/supabase_broadcast_identity_repository.dart';

// Local-dev-only defaults, identical to packages/zip_supabase/.env.example —
// not secrets (the "supabase-demo" anon JWT is the standard, publicly
// documented default for every self-hosted Supabase quickstart).
const _supabaseUrl = 'http://localhost:54321';
const _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAg'
    'ICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0'
    '.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

SupabaseClient _newClient() => SupabaseClient(
      _supabaseUrl,
      _anonKey,
      // Implicit flow: a bare SupabaseClient (not Supabase.initialize) has
      // no asyncStorage for PKCE's code-verifier persistence, which this
      // test harness has no use for anyway (no real OAuth redirect).
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );

Future<SupabaseClient> _signedUpClient(String emailLocalPart) async {
  final client = _newClient();
  final suffix = DateTime.now().microsecondsSinceEpoch;
  final email = '$emailLocalPart+$suffix@example.com';
  await client.auth.signUp(email: email, password: 'Test1234!Test1234!');
  return client;
}

void main() {
  group('broadcast_identities (local Supabase stack)', () {
    late SupabaseClient clientA;
    late SupabaseClient clientB;
    late SupabaseClient anonClient;

    setUpAll(() async {
      clientA = await _signedUpClient('broadcaster-a');
      clientB = await _signedUpClient('broadcaster-b');
      anonClient = _newClient();
    });

    tearDownAll(() async {
      await clientA.dispose();
      await clientB.dispose();
      await anonClient.dispose();
    });

    test(
      'getOrCreateMine() is idempotent for the same authenticated user',
      () async {
        final repository = SupabaseBroadcastIdentityRepository(
          client: clientA,
        );

        final first = await repository.getOrCreateMine();
        final second = await repository.getOrCreateMine();

        expect(first, equals(second));
      },
    );

    test('two different users never collide on the same broadcast id',
        () async {
      final repositoryA = SupabaseBroadcastIdentityRepository(
        client: clientA,
      );
      final repositoryB = SupabaseBroadcastIdentityRepository(
        client: clientB,
      );

      final idA = await repositoryA.getOrCreateMine();
      final idB = await repositoryB.getOrCreateMine();

      expect(idA, isNot(equals(idB)));
    });

    test(
      'resolve_broadcast_id returns true for an existing id and false for '
      "one that doesn't exist, callable anonymously",
      () async {
        final repository = SupabaseBroadcastIdentityRepository(
          client: clientA,
        );
        final id = await repository.getOrCreateMine();

        final exists = await anonClient.rpc<bool>(
          'resolve_broadcast_id',
          params: {'p_broadcast_id': id.value},
        );
        final doesNotExist = await anonClient.rpc<bool>(
          'resolve_broadcast_id',
          params: {'p_broadcast_id': 'ZZZZZZ'},
        );

        expect(exists, isTrue);
        expect(doesNotExist, isFalse);
      },
    );

    test(
      'anon cannot read broadcast_identities directly (no anon SELECT '
      'policy)',
      () async {
        final rows = await anonClient.from('broadcast_identities').select();

        expect(rows, isEmpty);
      },
    );

    test(
      "one authenticated user cannot read another user's row",
      () async {
        final repositoryA = SupabaseBroadcastIdentityRepository(
          client: clientA,
        );
        await repositoryA.getOrCreateMine();

        final rowsVisibleToB =
            await clientB.from('broadcast_identities').select();

        // Each test user calls getOrCreateMine() across this file's other
        // tests too, so clientB may legitimately see its own row — the
        // property under test is that it never sees clientA's.
        final ownerIds = rowsVisibleToB.map((row) => row['owner_id']);
        expect(
          ownerIds,
          isNot(contains(clientA.auth.currentUser!.id)),
        );
      },
    );
  });
}
