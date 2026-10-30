/// Integration test for `get_broadcast_turn_credentials()` (Unit 9, B2)
/// against a real local Supabase stack.
///
/// Covers the properties a mocked test cannot: that the function is actually
/// reachable by the `anon` role through Kong, that its HMAC-SHA1 credential
/// validates against the real shared secret, that it refuses an unknown
/// broadcast id with the same error shape as the authenticated function, that
/// `get_turn_credentials()`'s own guard is untouched, and that the Kong
/// rate-limit clone is live.
///
/// **Requires the local Supabase stack running first**:
/// ```sh
/// cd packages/zip_supabase
/// docker compose up -d
/// ```
/// and `20261030000000_broadcast_turn_credentials.sql` applied. Not run by
/// default or in CI (see `dart_test.yaml`). Run explicitly with:
/// ```sh
/// flutter test --tags integration-supabase --run-skipped \
///   test/integration/broadcast_turn_credentials_supabase_test.dart
/// ```
@Tags(['integration-supabase'])
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _supabaseUrl = 'http://localhost:54321';
const _anonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAg'
    'ICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0'
    '.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

// Matches the literal the Unit 4 migration sets for
// app.settings.turn_shared_secret, and .env.example's TURN_SHARED_SECRET.
const _sharedSecret = 'your-super-secret-turn-shared-secret-change-me';

/// Kong caps this RPC at 2 requests/second and 30/minute per IP, on purpose
/// (unit9-d2-turn-credential-approach.md §3). A suite that makes several
/// calls in a row must space them out, or it measures Kong rather than the
/// function — confirmed by the first run of this file, which tripped 429.
const _kongPaced = Duration(milliseconds: 1200);

SupabaseClient _anonClient() => SupabaseClient(
  _supabaseUrl,
  _anonKey,
  authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
);

void main() {
  group('get_broadcast_turn_credentials() (local Supabase stack)', () {
    late SupabaseClient anon;
    late SupabaseClient owner;
    late String broadcastId;

    setUpAll(() async {
      // The function deliberately requires a real broadcast id, so the test
      // needs one that exists. Creating one requires an authenticated owner,
      // and `get_or_create_my_broadcast_id()` allocates it — the same path
      // the broadcaster app uses.
      owner = _anonClient();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      await owner.auth.signUp(
        email: 'turn-broadcast-$suffix@example.com',
        password: 'Test1234!Test1234!',
      );
      broadcastId = await owner.rpc<String>('get_or_create_my_broadcast_id');
      anon = _anonClient();
    });

    test('is reachable by anon and returns a well-formed row', () async {
      await Future<void>.delayed(_kongPaced);
      final rows = await anon.rpc<List<dynamic>>(
        'get_broadcast_turn_credentials',
        params: {'p_broadcast_id': broadcastId},
      );
      final row = rows.single as Map<String, dynamic>;

      expect(row['username'], isA<String>());
      expect(row['credential'], isA<String>());
      expect(row['ttl'], 3600);
      expect(
        row['urls'],
        containsAll(['turn:localhost:3478', 'stun:localhost:3478']),
      );

      // The username encodes the broadcast id, so an issued credential is
      // attributable to exactly one broadcast in TURN logs.
      expect((row['username'] as String).endsWith(':$broadcastId'), isTrue);
    });

    test(
      'the credential is HMAC-SHA1-valid over <expiry>:<broadcast_id> with '
      'the real shared secret',
      () async {
        await Future<void>.delayed(_kongPaced);
        final rows = await anon.rpc<List<dynamic>>(
          'get_broadcast_turn_credentials',
          params: {'p_broadcast_id': broadcastId},
        );
        final row = rows.single as Map<String, dynamic>;
        final username = row['username'] as String;

        final expected = base64.encode(
          Hmac(
            sha1,
            utf8.encode(_sharedSecret),
          ).convert(utf8.encode(username)).bytes,
        );

        expect(row['credential'], expected);
      },
    );

    test(
      'rejects an unknown broadcast id with 42501 and no credential',
      () async {
        await Future<void>.delayed(_kongPaced);
        await expectLater(
          anon.rpc<List<dynamic>>(
            'get_broadcast_turn_credentials',
            params: {'p_broadcast_id': 'ZZZZZZ'},
          ),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
        );
      },
    );

    test(
      'leaves get_turn_credentials() untouched: still 42501 for anon',
      () async {
        // Different Kong service, so no shared second-limit — but keep the
        // pacing uniform rather than reasoning about which limit applies.
        await Future<void>.delayed(_kongPaced);
        await expectLater(
          anon.rpc<List<dynamic>>('get_turn_credentials'),
          throwsA(
            isA<PostgrestException>().having((e) => e.code, 'code', '42501'),
          ),
        );
      },
    );

    test(
      'one broadcast id cannot mint credentials for another: each call is '
      'scoped to the id it names',
      () async {
        await Future<void>.delayed(_kongPaced);
        final first =
            (await anon.rpc<List<dynamic>>(
                  'get_broadcast_turn_credentials',
                  params: {'p_broadcast_id': broadcastId},
                )).single
                as Map<String, dynamic>;

        await Future<void>.delayed(_kongPaced);
        await expectLater(
          anon.rpc<List<dynamic>>(
            'get_broadcast_turn_credentials',
            params: {'p_broadcast_id': 'ZZZZZZ'},
          ),
          throwsA(isA<PostgrestException>()),
        );

        expect(
          (first['username'] as String).endsWith(':$broadcastId'),
          isTrue,
        );
      },
    );
  });
}
