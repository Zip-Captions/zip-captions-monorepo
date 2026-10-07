/// Manual verification for Signaling Channel Privacy (Unit 3.1), NFR
/// Requirements Q1: does a single `supabase_flutter` client's one WebSocket
/// connection silently drop any private channel subscriptions once the
/// broadcaster holds 51 of them concurrently (the interim `maxViewers=50`
/// cap, plus the broadcaster's own `joinRequests` subscription)?
///
/// Not assumed from `supabase_flutter`'s documented multiplexing-over-one-
/// WebSocket behavior alone — run directly against the real local stack,
/// per this project's established pattern (Q1's own text).
///
/// **Requires the local Supabase stack running first**:
/// ```sh
/// cd packages/zip_supabase
/// docker compose up -d
/// supabase db reset
/// ```
/// Not run by default or in CI. Run explicitly with:
/// ```sh
/// flutter test --tags integration-supabase --run-skipped \
///   test/integration/signaling_channel_capacity_supabase_test.dart
/// ```
@Tags(['integration-supabase'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/peer_id.dart';
import 'package:zip_core/src/services/signaling/supabase_session_signaling_channel.dart';

const _supabaseUrl = 'http://localhost:54321';
const _anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9'
    '.eyAgCiAgICAicm9sZSI6ICJhbm9uIiwKICAgICJpc3MiOiAic3VwYWJhc2UtZGVtbyIsCiAg'
    'ICAiaWF0IjogMTY0MTc2OTIwMCwKICAgICJleHAiOiAxNzk5NTM1NjAwCn0'
    '.dc_X5iR_VP_qT0zsiyj_I_OZ2T9FtRU2BBNWN8Bu4GE';

void main() {
  test(
    'a single client can hold 51 concurrent private channel subscriptions '
    'without any being silently dropped',
    () async {
      final client = SupabaseClient(
        _supabaseUrl,
        _anonKey,
        authOptions:
            const AuthClientOptions(authFlowType: AuthFlowType.implicit),
      );
      addTearDown(client.dispose);

      const sessionId = 'session-capacity-test';
      final channels = List.generate(
        51,
        (_) => SupabaseSessionSignalingChannel(
          client: client,
          sessionId: sessionId,
          peerId: peerId(),
        ),
      );
      addTearDown(() async {
        for (final channel in channels) {
          await channel.close();
        }
      });

      // If any subscription is silently dropped rather than reaching
      // `subscribed`, its open() either throws or never completes — await
      // all 51 concurrently and let a hang or an exception fail the test.
      await Future.wait(channels.map((c) => c.open()));

      expect(channels, hasLength(51));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
