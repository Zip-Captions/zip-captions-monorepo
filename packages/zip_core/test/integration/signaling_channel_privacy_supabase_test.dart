/// Integration test for Signaling Channel Privacy (Unit 3.1, SR-04) against
/// a real local Supabase stack — covers exactly what NFR Requirements Q4
/// says fakes cannot demonstrate: that RLS actually isolates
/// `broadcast_join_requests` (and the Postgres Changes stream built on it)
/// to the real broadcast owner, and that distinct per-viewer channels never
/// cross-deliver messages.
///
/// **Revised 2026-10-06**: the join-request tests below were rewritten from
/// `SupabaseLobbyChannel.broadcaster`/`.viewer` (a Realtime Broadcast-
/// extension channel) to `SupabaseSignalingService.joinRequests`/
/// `submitJoinRequest` (table + RPC + Postgres Changes) — the original
/// mechanism was confirmed unworkable by this same test file: a `.viewer`
/// `open()` failed identically to a snooper's, since Realtime's
/// `subscribe()` rejects any client lacking SELECT regardless of receive
/// intent. See `audit.md`'s 2026-10-06 entries.
///
/// **Requires the local Supabase stack running first**:
/// ```sh
/// cd packages/zip_supabase
/// docker compose up -d
/// supabase db reset   # applies migrations, including
///                      # 20261006000000_signaling_channel_privacy.sql
/// ```
/// Not run by default or in CI (see `dart_test.yaml`). Run explicitly with:
/// ```sh
/// flutter test --tags integration-supabase --run-skipped \
///   test/integration/signaling_channel_privacy_supabase_test.dart
/// ```
@Tags(['integration-supabase'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/peer_id.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/services/signaling/supabase_session_signaling_channel.dart';
import 'package:zip_core/src/services/signaling/supabase_signaling_service.dart';

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
  group('Signaling Channel Privacy (local Supabase stack)', () {
    late SupabaseClient broadcasterClient;
    late SupabaseClient viewerAClient;
    late SupabaseClient viewerBClient;
    late SupabaseClient anonClient;
    late String broadcastId;

    setUpAll(() async {
      broadcasterClient = await _signedUpClient('privacy-broadcaster');
      viewerAClient = await _signedUpClient('privacy-viewer-a');
      viewerBClient = await _signedUpClient('privacy-viewer-b');
      anonClient = _newClient();

      broadcastId = await broadcasterClient
          .rpc<String>('get_or_create_my_broadcast_id');
    });

    tearDownAll(() async {
      await broadcasterClient.dispose();
      await viewerAClient.dispose();
      await viewerBClient.dispose();
      await anonClient.dispose();
    });

    test(
      'the real broadcast owner receives a join request submitted by a '
      'viewer via submit_join_request/Postgres Changes',
      () async {
        final ownerService = SupabaseSignalingService(
          client: broadcasterClient,
        );
        final ownerReceived = <JoinRequest>[];
        final subscription = ownerService
            .joinRequests(BroadcastId.parse(broadcastId))
            .listen(ownerReceived.add);
        addTearDown(subscription.cancel);

        // Postgres Changes subscriptions take a moment to register with
        // Realtime before CDC events for rows inserted afterward are
        // guaranteed to be delivered.
        await Future<void>.delayed(const Duration(seconds: 1));

        final myPeerId = peerId();
        await SupabaseSignalingService(client: viewerAClient).submitJoinRequest(
          BroadcastId.parse(broadcastId),
          myPeerId,
        );

        await Future<void>.delayed(const Duration(seconds: 1));

        expect(ownerReceived, [JoinRequest(fromPeerId: myPeerId)]);
      },
    );

    test(
      'a different authenticated user never receives join requests for '
      "someone else's broadcast — RLS filters the Postgres Changes stream, "
      'it does not reject the subscription',
      () async {
        final snooperReceived = <JoinRequest>[];
        final subscription = SupabaseSignalingService(client: viewerBClient)
            .joinRequests(BroadcastId.parse(broadcastId))
            .listen(snooperReceived.add);
        addTearDown(subscription.cancel);

        await Future<void>.delayed(const Duration(seconds: 1));

        await SupabaseSignalingService(client: viewerAClient).submitJoinRequest(
          BroadcastId.parse(broadcastId),
          peerId(),
        );

        await Future<void>.delayed(const Duration(seconds: 1));

        expect(
          snooperReceived,
          isEmpty,
          reason: "a non-owner must never receive another broadcast's "
              'join requests, even though its subscription succeeds',
        );
      },
    );

    test(
      'anon can still submit a join request (FR-7.6 — viewing requires no '
      'sign-in) — submit_join_request needs no subscription at all',
      () async {
        await expectLater(
          SupabaseSignalingService(
            client: anonClient,
          ).submitJoinRequest(BroadcastId.parse(broadcastId), peerId()),
          completes,
        );
      },
    );

    test(
      'two distinct per-viewer channels for the same sessionId never '
      'cross-deliver messages',
      () async {
        const sessionId = 'session-privacy-test';
        final peerIdA = peerId();
        final peerIdB = peerId();

        final channelA = SupabaseSessionSignalingChannel(
          client: viewerAClient,
          sessionId: sessionId,
          peerId: peerIdA,
        );
        final channelB = SupabaseSessionSignalingChannel(
          client: viewerBClient,
          sessionId: sessionId,
          peerId: peerIdB,
        );
        await channelA.open();
        await channelB.open();
        addTearDown(channelA.close);
        addTearDown(channelB.close);

        final receivedOnB = <SignalingMessage>[];
        channelB.messages.listen(receivedOnB.add);

        // Broadcaster-side instance for A's channel, simulating the real
        // flow — sends a message only A's channel should ever see.
        final broadcasterSideOfA = SupabaseSessionSignalingChannel(
          client: broadcasterClient,
          sessionId: sessionId,
          peerId: peerIdA,
        );
        await broadcasterSideOfA.open();
        addTearDown(broadcasterSideOfA.close);

        await broadcasterSideOfA.send(const Leave(fromPeerId: 'broadcaster'));
        await Future<void>.delayed(const Duration(seconds: 1));

        expect(
          receivedOnB,
          isEmpty,
          reason: "a message sent on peerId A's channel must never reach "
              "peerId B's channel, even for the same sessionId",
        );
      },
    );
  });
}
