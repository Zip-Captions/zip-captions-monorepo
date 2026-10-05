/// Integration test for `get_turn_credentials()` (Coturn Infrastructure,
/// Unit 4) against a real local Supabase stack — covers the one property
/// not exercisable by a mocked unit test: that the server-side HMAC-SHA1
/// computation is actually valid against the real shared secret configured
/// in the migration, and that the function requires authentication.
///
/// **Requires the local Supabase stack running first**:
/// ```sh
/// cd packages/zip_supabase
/// docker compose up -d
/// supabase db reset   # applies migrations, including
///                      # 20261003000000_coturn_turn_credentials.sql
/// ```
/// Not run by default or in CI (see `dart_test.yaml`). Run explicitly with:
/// ```sh
/// flutter test --tags integration-supabase --run-skipped \
///   test/integration/turn_credentials_supabase_test.dart
/// ```
@Tags(['integration-supabase'])
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Local-dev-only defaults, identical to packages/zip_supabase/.env.example —
// not secrets (the "supabase-demo" anon JWT is the standard, publicly
// documented default for every self-hosted Supabase quickstart).
const _supabaseUrl = 'http://localhost:54321';
const _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAg'
    'ICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0'
    '.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

// Matches the literal value the migration sets for
// app.settings.turn_shared_secret, and .env.example's TURN_SHARED_SECRET
// default. If you've changed either without updating the other, this test
// (and real credential issuance) will fail — the same failure mode
// 20261001000001_fix_jwt_secret_mismatch.sql documents for jwt_secret.
const _sharedSecret = 'your-super-secret-turn-shared-secret-change-me';

SupabaseClient _newClient() => SupabaseClient(
      _supabaseUrl,
      _anonKey,
      authOptions: const AuthClientOptions(authFlowType: AuthFlowType.implicit),
    );

void main() {
  group('get_turn_credentials() (local Supabase stack)', () {
    late SupabaseClient client;

    setUpAll(() async {
      client = _newClient();
      final suffix = DateTime.now().microsecondsSinceEpoch;
      await client.auth.signUp(
        email: 'turn-creds-$suffix@example.com',
        password: 'Test1234!Test1234!',
      );
    });

    test(
      'returns a well-formed row with an HMAC-SHA1-valid credential',
      () async {
        final rows =
            await client.rpc<List<dynamic>>('get_turn_credentials');
        final row = rows.single as Map<String, dynamic>;

        expect(row['username'], isA<String>());
        expect(row['credential'], isA<String>());
        expect(row['ttl'], 3600);
        expect(
          row['urls'],
          containsAll(['turn:localhost:3478', 'stun:localhost:3478']),
        );

        final expectedCredential = base64.encode(
          Hmac(sha1, utf8.encode(_sharedSecret))
              .convert(utf8.encode(row['username'] as String))
              .bytes,
        );
        expect(row['credential'], expectedCredential);
      },
    );

    test('rejects an unauthenticated (anon) caller', () async {
      final anonClient = _newClient();

      await expectLater(
        anonClient.rpc<List<dynamic>>('get_turn_credentials'),
        throwsA(isA<PostgrestException>()),
      );
    });
  });
}
