// Integration test for S-14, S-16, S-18 (webrtc-transport-remote-output-
// capacity, plan step 25 part 3): wires the *real*
// `WebRtcBroadcastTransport` + `WebRtcViewerTransport` (plus
// `RemoteBroadcastTarget`) against the two accepted fakes
// (`FakePeerConnectionFactory` / `FakeSignalingService`) — no mocks, no
// real network (NFR Requirements Q5) — and drives a join -> caption
// sequence end to end to confirm Business Rules 1, 2, 4, 5, 8 hold.
//
// Every test runs inside `fakeAsync` with a *synchronous* callback: the
// only real `Timer`s in the system under test are the broadcaster's 5s
// join-ack timer (Rule 1) and the viewer's backoff retry timer (Rule 2),
// and those fire only via `async.elapse(...)`. Everything else — the full
// join handshake, caption delivery — completes on microtasks and is
// driven to completion with `async.flushMicrotasks()`. Note the data
// channel's "open" transition fires in a microtask nested one level
// deeper than its delivery to the peer (`fake_peer_connection.dart`'s
// class doc), which is why a flush — not a plain `await` — is what makes
// it observable here.

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_limits.dart';
import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/signaling_message.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/viewer_transport_context.dart';
import 'package:zip_core/src/services/caption/remote_broadcast_target.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_factory.dart';
import 'package:zip_core/src/services/webrtc/peer_connection_handle.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';
import 'package:zip_core/src/services/webrtc/web_rtc_broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/web_rtc_viewer_transport.dart';

import '../helpers/fake_peer_connection.dart';
import '../helpers/fake_signaling_service.dart';

/// Wraps [FakePeerConnectionFactory], recording every created handle in
/// call order. Neither real transport exposes its underlying
/// [PeerConnectionHandle], but several tests below need one directly
/// (e.g. to call `emitIceState`, which only `FakePeerConnectionHandle`
/// has) — this is the only way to reach it.
class _TrackingPeerConnectionFactory implements PeerConnectionFactory {
  _TrackingPeerConnectionFactory(this._inner);
  final FakePeerConnectionFactory _inner;
  final handles = <FakePeerConnectionHandle>[];

  /// Called with every handle as it's created — lets a test observe each
  /// one (e.g. its `peer`'s `onDataChannel`) without having to predict in
  /// advance which of several racing attempts' call will end up paired
  /// with which.
  void Function(FakePeerConnectionHandle handle)? onCreated;

  @override
  Future<PeerConnectionHandle> create(List<IceServer> iceServers) async {
    final handle = await _inner.create(iceServers) as FakePeerConnectionHandle;
    handles.add(handle);
    onCreated?.call(handle);
    return handle;
  }
}

const _sessionId = 'session-1';

void main() {
  late FakeSignalingService signaling;
  late _TrackingPeerConnectionFactory factory;
  late BroadcastId broadcastId;
  late ViewerAdmission admission;
  late WebRtcBroadcastTransport broadcastTransport;
  late RemoteBroadcastTarget remoteBroadcastTarget;
  late WebRtcViewerTransport viewerTransport;

  BroadcastTransportContext broadcastContext() => BroadcastTransportContext(
    sessionId: _sessionId,
    broadcastId: broadcastId,
    signalingService: signaling,
    iceServers: const [],
    admission: admission,
  );

  ViewerTransportContext viewerContext() => ViewerTransportContext(
    sessionId: _sessionId,
    broadcastId: broadcastId,
    signalingService: signaling,
    iceServers: const [],
  );

  setUp(() {
    signaling = FakeSignalingService();
    factory = _TrackingPeerConnectionFactory(FakePeerConnectionFactory());
    broadcastId = BroadcastId.parse('K7M9X2');
    // maxViewers: 2, not 1 — Test 4 (Rule 2 reconnect) creates a *second*
    // peer connection pair for the same logical viewer without the first
    // one's admission slot ever being released (nothing in this test
    // simulates the old connection's ICE state failing on the
    // broadcaster's side), so the reconnect's fresh `tryAdmit` call needs
    // a free slot alongside the still-held old one.
    admission = ViewerAdmission(
      const BroadcastLimits(
        maxViewers: 2,
        presenceTimeout: Duration(seconds: 60),
        reconnectWindow: Duration(seconds: 120),
      ),
    );
    broadcastTransport = WebRtcBroadcastTransport(
      peerConnectionFactory: factory,
    );
    viewerTransport = WebRtcViewerTransport(peerConnectionFactory: factory);
    // `remoteBroadcastTarget` is deliberately NOT constructed here — its
    // constructor eagerly calls `.listen()` on `broadcastTransport
    // .viewerJoined`, which binds that subscription to whichever `Zone`
    // is current *at construction time*. `setUp()` runs outside every
    // test's `fakeAsync` zone, so a subscription captured here would stay
    // bound to the real zone forever: `fakeAsync`'s broadcast-stream
    // dispatch to a differently-zoned listener still runs that listener's
    // callback synchronously, but *inside that listener's own zone* (via
    // `zone.runUnaryGuarded`) — so anything *that* callback itself
    // schedules asynchronously (here: the eventual data-channel
    // `.add()` a few hops downstream in `sendTo`) escapes into the real,
    // unfaked microtask queue instead of `FakeAsync`'s own, and
    // `async.flushMicrotasks()` can never see it. Each test constructs
    // `remoteBroadcastTarget` itself, as the first line inside its own
    // `fakeAsync` callback, so its subscription is captured in the same
    // zone as everything else.
  });

  tearDown(() async {
    remoteBroadcastTarget.dispose();
    await viewerTransport.disconnect();
    await broadcastTransport.stop();
    await signaling.dispose();
  });

  group(
    'happy path: join confirms, one activity snapshot, in-order captions',
    () {
      test('Rules 1, 5, 8 hold end to end', () {
        fakeAsync((async) {
          remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
          final receivedMessages = <CaptionWireMessage>[];
          final statuses = <ConnectionStatus>[];
          final messagesSub = viewerTransport.messages.listen(
            receivedMessages.add,
          );
          final statusSub = viewerTransport.status.listen(statuses.add);
          addTearDown(messagesSub.cancel);
          addTearDown(statusSub.cancel);

          unawaited(broadcastTransport.start(broadcastContext()));
          async.flushMicrotasks();

          // Set `currentActivity` to `active` *before* any join, so the
          // snapshot the viewer receives is a live signal, not the
          // target's own constructor default.
          remoteBroadcastTarget.onCaptionEvent(
            const SessionStateEvent(
              RecordingState.recording(sessionId: 'rec-1'),
            ),
          );

          unawaited(viewerTransport.connect(viewerContext()));
          async.flushMicrotasks();

          // The full join handshake (SDP exchange, data-channel open,
          // join-ack) ran entirely on microtasks — no `elapse` needed,
          // which is itself Rule 1's happy path (confirmed well inside
          // the 5s window).
          final activityMessages = receivedMessages
              .whereType<CaptionActivityChanged>()
              .toList();
          expect(activityMessages, hasLength(1));
          expect(
            activityMessages.single,
            const CaptionActivityChanged(activity: CaptionActivity.active),
          );

          // The viewer's own ICE connection succeeding is independent of
          // the join-ack signal — the fakes never emit ICE state
          // automatically, so drive it manually.
          factory.handles[0].emitIceState(
            RTCIceConnectionState.RTCIceConnectionStateConnected,
          );
          async.flushMicrotasks();
          expect(statuses.last, const Connected(ConnectionType.p2pDirect));

          for (final text in ['one', 'two', 'three']) {
            remoteBroadcastTarget.onCaptionEvent(
              SttResultEvent(
                SttResult(
                  text: text,
                  isFinal: true,
                  confidence: 1,
                  timestamp: DateTime.utc(2026),
                  sourceId: 'default',
                ),
              ),
            );
            async.flushMicrotasks();
          }

          // Rule 5: captions arrive in exactly the order sent.
          expect(
            receivedMessages
                .whereType<Caption>()
                .map((message) => message.result.text)
                .toList(),
            ['one', 'two', 'three'],
          );
          // Rule 8: still exactly one snapshot total — the captions sent
          // above did not duplicate the join-time snapshot.
          expect(
            receivedMessages.whereType<CaptionActivityChanged>(),
            hasLength(1),
          );
        });
      });
    },
  );

  group('Rule 1: no ack within 5 seconds tears the connection down', () {
    test('a silent viewer is torn down by the 5s ack timeout', () {
      fakeAsync((async) {
        // Not used by this test, but `tearDown` disposes it unconditionally.
        remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
        unawaited(broadcastTransport.start(broadcastContext()));
        async.flushMicrotasks();

        const fakePeerId = 'silent-viewer';

        // Create the peer connection *before* submitting the join request
        // — the real, invariant call order `FakePeerConnectionFactory`'s
        // odd/even pairing depends on (the viewer always calls `create()`
        // first, the broadcaster only after receiving the `JoinRequest`).
        FakePeerConnectionHandle? viewerSideHandle;
        unawaited(
          factory
              .create(const [])
              .then(
                (handle) =>
                    viewerSideHandle = handle as FakePeerConnectionHandle,
              ),
        );
        async.flushMicrotasks();

        // Open this peer's own signaling channel and capture whatever data
        // channel gets delivered to it.
        final viewerChannel = signaling.sessionChannel(_sessionId, fakePeerId);
        unawaited(viewerChannel.open());
        RTCDataChannel? delivered;
        final dataChannelSub = viewerSideHandle!.onDataChannel.listen(
          (channel) => delivered = channel,
        );
        addTearDown(dataChannelSub.cancel);

        // Drive the broadcaster's entire `_handleJoinRequest`: admission,
        // its own `create()` (paired with the one above), data channel
        // creation, SDP offer send.
        unawaited(signaling.submitJoinRequest(broadcastId, fakePeerId));
        async.flushMicrotasks();

        // The data channel opened — deliberately never send a join-ack on
        // it.
        expect(delivered, isNotNull);
        expect(delivered!.state, RTCDataChannelState.RTCDataChannelOpen);

        final joined = <String>[];
        final joinedSub = broadcastTransport.viewerJoined.listen(joined.add);
        addTearDown(joinedSub.cancel);

        // Still inside the 5s window.
        async.elapse(const Duration(seconds: 4));
        expect(joined, isEmpty);

        // Past 5s total: the ack timer has fired and torn the viewer down
        // on the broadcaster's own side. Rule 1's core guarantee is that
        // the join is never confirmed — that's `joined` staying empty,
        // checked at both 4s and past 6s. (`_teardownViewer` only closes
        // the *broadcaster's* own peer connection and data channel half
        // — it never reaches across the link to close `delivered`, the
        // fake peer's own received half; the fakes don't simulate a real
        // WebRTC connection's ICE-mediated teardown propagating to the
        // other side, so that's not independently observable here.)
        async.elapse(const Duration(seconds: 2));
        expect(joined, isEmpty);
      });
    });
  });

  group('Rule 4: an out-of-role message from a viewer is dropped silently', () {
    test('a bystander JoinAccepted on the shared topic leaves the session '
        'unaffected', () {
      fakeAsync((async) {
        remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
        final left = <String>[];
        final leftSub = broadcastTransport.viewerLeft.listen(left.add);
        addTearDown(leftSub.cancel);

        // Test 1 steps 2-4 (start broadcaster, set activity, connect the
        // real viewer, flush) — with the real viewer's generated peer id
        // captured from the join-request stream *before* connecting.
        String? realPeerId;
        final joinReqSub = signaling
            .joinRequests(broadcastId)
            .listen(
              (request) => realPeerId = request.fromPeerId,
            );
        unawaited(broadcastTransport.start(broadcastContext()));
        remoteBroadcastTarget.onCaptionEvent(
          const SessionStateEvent(
            RecordingState.recording(sessionId: 'rec-1'),
          ),
        );
        unawaited(viewerTransport.connect(viewerContext()));
        async.flushMicrotasks();
        unawaited(joinReqSub.cancel());

        // Collect the viewer's messages from this point on.
        final receivedMessages = <CaptionWireMessage>[];
        final messagesSub = viewerTransport.messages.listen(
          receivedMessages.add,
        );
        addTearDown(messagesSub.cancel);

        // A *third*, "bystander" channel object on the exact same
        // `(sessionId, realPeerId)` topic the real viewer and broadcaster
        // are using (`FakeSignalingService.sessionChannel` returns a fresh
        // object sharing the same underlying topic).
        final bystander = signaling.sessionChannel(_sessionId, realPeerId!);

        // `JoinAccepted` is broadcaster-only-origin, so the broadcaster
        // must drop it (Rule 4 — the thing under test); it also happens
        // to be a complete no-op on the viewer side (`case JoinAccepted():
        // break;`), so the viewer receiving it on the same shared topic
        // cannot muddy what's being tested here.
        unawaited(bystander.send(const JoinAccepted(toPeerId: 'anyone')));
        async.flushMicrotasks();

        // Nothing broke: no viewer left...
        expect(left, isEmpty);

        // ...and the session is still fully functional — a caption sent
        // now still arrives in the viewer's message list.
        remoteBroadcastTarget.onCaptionEvent(
          SttResultEvent(
            SttResult(
              text: 'still-alive',
              isFinal: true,
              confidence: 1,
              timestamp: DateTime.utc(2026),
              sourceId: 'default',
            ),
          ),
        );
        async.flushMicrotasks();
        expect(
          receivedMessages
              .whereType<Caption>()
              .map((message) => message.result.text)
              .toList(),
          ['still-alive'],
        );
      });
    });
  });

  group('Rule 2: an ICE interruption retries with backoff and reconnects', () {
    // Deliberately a plain `async` test, not `fakeAsync`, unlike every
    // other test in this file. `WebRtcViewerTransport.restart()`'s own
    // teardown step (`_teardownConnectionState`) awaits cancelling several
    // `StreamSubscription`s on broadcast streams — and a broadcast
    // subscription's `cancel()` Future does not resolve through
    // `fakeAsync`'s intercepted microtask queue in this Dart SDK (verified
    // directly: a minimal repro of "subscribe, then `await sub.cancel()`
    // inside `fakeAsync`, then `flushMicrotasks()`" leaves the cancel
    // still pending after the flush returns, completing only later via
    // the real event loop) — so a `fakeAsync` version of this test would
    // hang waiting for the reconnect's own teardown to finish. A real
    // ~1-second wait for the one backoff `Timer` this test needs is a
    // small, acceptable cost to sidestep that limitation entirely.
    test('an interrupted viewer backs off, reconnects, and reaches '
        'Connected', () async {
      remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
      final statuses = <ConnectionStatus>[];
      final statusSub = viewerTransport.status.listen(statuses.add);
      addTearDown(statusSub.cancel);
      final joined = <String>[];
      final joinedSub = broadcastTransport.viewerJoined.listen(joined.add);
      addTearDown(joinedSub.cancel);

      // Test 1 steps 2-4 (start, set activity, connect) to get a
      // confirmed join.
      await broadcastTransport.start(broadcastContext());
      remoteBroadcastTarget.onCaptionEvent(
        const SessionStateEvent(RecordingState.recording(sessionId: 'rec-1')),
      );
      await viewerTransport.connect(viewerContext());
      await pumpEventQueue();

      // Simulate the viewer's own connection dropping. The fakes never
      // emit ICE state automatically — and only the viewer's own handle
      // matters here: the broadcaster reacts to its own handle's ICE
      // state, and only to `failed`/`closed`.
      factory.handles[0].emitIceState(
        RTCIceConnectionState.RTCIceConnectionStateDisconnected,
      );
      await pumpEventQueue();
      expect(statuses.last, const Interrupted());

      // A real wait past the 1s backoff: the retry `Timer` fires, calling
      // `restart()`, which tears down the old connection and runs a
      // brand-new `_attemptConnect()` (a fresh peer id, a fresh signaling
      // channel, two fresh `create()` calls).
      await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 100));
      await pumpEventQueue();
      expect(factory.handles.length, 4);

      // The reconnect's own join handshake ran the same way Test 1's did.
      // The two joins may have different peer ids; that's expected and
      // not asserted on.
      expect(joined.length, 2);

      // Simulate the new connection's own ICE succeeding — Rule 2's
      // point: an interruption never reached `Failed` on its own, and
      // recovery succeeded.
      factory.handles[2].emitIceState(
        RTCIceConnectionState.RTCIceConnectionStateConnected,
      );
      await pumpEventQueue();
      expect(statuses.last, const Connected(ConnectionType.p2pDirect));
    });
  });

  // Regression coverage added 2026-10-10 for 3 CodeRabbit PR #31 findings
  // that none of the tests above happened to exercise (all 477 existing
  // tests still passed with the bugs in place).

  group(
    'Rule 2: an immediate ICE failure (no prior retry) still retries, '
    'never fails',
    () {
      // Plain `async`, not `fakeAsync` — same reason as the Rule 2
      // reconnect test above: this goes through `restart()`'s own
      // `_teardownConnectionState()`, which awaits cancelling broadcast
      // `StreamSubscription`s that don't resolve through `fakeAsync`'s
      // intercepted queue in this Dart SDK.
      test(
        'emitting Failed directly behaves exactly like Disconnected',
        () async {
          remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
          final statuses = <ConnectionStatus>[];
          final statusSub = viewerTransport.status.listen(statuses.add);
          addTearDown(statusSub.cancel);

          await broadcastTransport.start(broadcastContext());
          remoteBroadcastTarget.onCaptionEvent(
            const SessionStateEvent(
              RecordingState.recording(sessionId: 'rec-1'),
            ),
          );
          await viewerTransport.connect(viewerContext());
          await pumpEventQueue();

          // ICE reports `failed` directly — no prior `disconnected` event
          // ever set `_retryIndex` above 0. The old `_retryIndex > 0`
          // terminal test read this as "already mid-retry" and jumped
          // straight to `Failed(IceFailed())`, breaking Rule 2's
          // "indefinite retries ... never via retry-count exhaustion
          // alone" on the very first ICE failure.
          factory.handles[0].emitIceState(
            RTCIceConnectionState.RTCIceConnectionStateFailed,
          );
          await pumpEventQueue();
          expect(statuses.last, const Interrupted());
          expect(statuses, isNot(contains(isA<Failed>())));

          // The backoff retry actually runs, exactly as Disconnected's
          // would (Test 4 above).
          await Future<void>.delayed(
            const Duration(seconds: 1, milliseconds: 100),
          );
          await pumpEventQueue();
          expect(factory.handles.length, 4);
        },
      );
    },
  );

  group(
    'a duplicate JoinRequest for an already-tracked peerId tears down '
    'the stale session',
    () {
      test(
        "cancels the stale session's ack timer so the replacement isn't "
        'incorrectly torn down once it would have fired',
        () {
          fakeAsync((async) {
            // Not used by this test, but `tearDown` disposes it
            // unconditionally — must be assigned here, not relied on
            // from a preceding test, so this test also passes run in
            // isolation (CodeRabbit PR #31 review, round 2).
            remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
            unawaited(broadcastTransport.start(broadcastContext()));
            async.flushMicrotasks();
            const fakePeerId = 'reconnecting-viewer';

            // First join attempt: data channel opens, deliberately never
            // acked — its ack timer is left running.
            FakePeerConnectionHandle? handle1;
            unawaited(
              factory
                  .create(const [])
                  .then(
                    (h) => handle1 = h as FakePeerConnectionHandle,
                  ),
            );
            async.flushMicrotasks();
            RTCDataChannel? delivered1;
            handle1!.onDataChannel.listen((c) => delivered1 = c);
            unawaited(signaling.submitJoinRequest(broadcastId, fakePeerId));
            async.flushMicrotasks();
            expect(delivered1, isNotNull);
            expect(
              delivered1!.state,
              RTCDataChannelState.RTCDataChannelOpen,
            );

            // 3s in — well inside the first attempt's 5s ack window.
            async.elapse(const Duration(seconds: 3));

            // A second `JoinRequest` for the *same* peerId (e.g. a
            // reconnecting viewer whose first attempt stalled before
            // acking). This must tear down the first session — including
            // cancelling its now-orphaned ack timer — before admitting
            // the replacement.
            FakePeerConnectionHandle? handle2;
            unawaited(
              factory
                  .create(const [])
                  .then(
                    (h) => handle2 = h as FakePeerConnectionHandle,
                  ),
            );
            async.flushMicrotasks();
            RTCDataChannel? delivered2;
            handle2!.onDataChannel.listen((c) => delivered2 = c);
            unawaited(signaling.submitJoinRequest(broadcastId, fakePeerId));
            async.flushMicrotasks();
            expect(delivered2, isNotNull);
            expect(
              delivered2!.state,
              RTCDataChannelState.RTCDataChannelOpen,
            );

            final joined = <String>[];
            final joinedSub = broadcastTransport.viewerJoined.listen(
              joined.add,
            );
            addTearDown(joinedSub.cancel);
            final left = <String>[];
            final leftSub = broadcastTransport.viewerLeft.listen(left.add);
            addTearDown(leftSub.cancel);

            // Ack the replacement session right away.
            unawaited(
              delivered2!.send(RTCDataChannelMessage(joinAckSentinel)),
            );
            async.flushMicrotasks();
            expect(joined, [fakePeerId]);

            // Advance to exactly 5s after the *first* attempt's own
            // data-channel-open — when its now-stale ack timer would
            // have fired, had it not been cancelled. An uncancelled
            // timer would tear down whatever is currently tracked for
            // this peerId (the confirmed replacement session),
            // incorrectly emitting `viewerLeft` for a viewer that is
            // very much still connected.
            async.elapse(const Duration(seconds: 2));
            expect(left, isEmpty);
          });
        },
      );
    },
  );

  group(
    'two JoinRequests for the same peerId overlapping before either '
    'installs a session',
    () {
      test(
        "only one attempt's join actually completes; the superseded one "
        'releases cleanly, however far it got',
        () {
          fakeAsync((async) {
            remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
            unawaited(broadcastTransport.start(broadcastContext()));
            async.flushMicrotasks();
            const fakePeerId = 'racing-viewer';

            // Watch every peer connection as it's created, from *either*
            // racing attempt — not just one predicted in advance. The
            // identity guard is checked after `create()` too, not only
            // after `channel.open()`, so the superseded attempt may
            // still consume one pairing slot (creating a connection)
            // before discovering it's stale and releasing/closing it;
            // which attempt reaches which checkpoint first isn't
            // something this test should have to predict exactly.
            final allDelivered = <RTCDataChannel>[];
            factory.onCreated = (handle) =>
                handle.peer.onDataChannel.listen(allDelivered.add);

            // A real viewer-side peer connection, matching the actual
            // system's call order: exactly one viewer submits (possibly
            // duplicate) `JoinRequest`s, so there is exactly one
            // viewer-side `create()` call before any broadcaster-side
            // one. Without this, the two *broadcaster-side* attempts
            // below would end up paired with *each other* instead of
            // with a viewer — an artifact of the fake's simplified
            // sequential-pairing scheme, not representative of the real
            // race this test exists to cover.
            unawaited(factory.create(const []));
            async.flushMicrotasks();

            // Two `JoinRequest`s for the same peerId, submitted
            // back-to-back with *no* flush between them, so both
            // `_handleJoinRequest` calls start before either has
            // installed a session. Without the per-attempt identity
            // guard, this could install two sessions, or let the first
            // attempt's late continuation corrupt the second's.
            unawaited(signaling.submitJoinRequest(broadcastId, fakePeerId));
            unawaited(signaling.submitJoinRequest(broadcastId, fakePeerId));
            async.flushMicrotasks();

            // Exactly one attempt ever gets far enough to open a data
            // channel — the real, observable proof that only one
            // session is actually live, regardless of how many
            // connections were created and discarded along the way.
            expect(allDelivered, hasLength(1));
            expect(
              allDelivered.single.state,
              RTCDataChannelState.RTCDataChannelOpen,
            );

            final joined = <String>[];
            final joinedSub = broadcastTransport.viewerJoined.listen(
              joined.add,
            );
            addTearDown(joinedSub.cancel);
            unawaited(
              allDelivered.single.send(
                RTCDataChannelMessage(joinAckSentinel),
              ),
            );
            async.flushMicrotasks();
            expect(joined, [fakePeerId]);

            // And the superseded attempt didn't leak its admission
            // reservation — exactly one reservation is held overall.
            expect(admission.count, 1);
          });
        },
      );
    },
  );

  group(
    "stop() doesn't emit viewerLeft for a viewer that never joined",
    () {
      // Plain `async`: `stop()` itself awaits cancelling a broadcast
      // `StreamSubscription` (`_joinRequestsSub`), which doesn't resolve
      // through `fakeAsync`'s intercepted queue — same limitation as the
      // other plain-`async` tests above.
      test(
        'a silent, never-acked viewer is torn down silently by stop()',
        () async {
          // Not used by this test, but `tearDown` disposes it
          // unconditionally — must be assigned here, not relied on from
          // a preceding test, so this test also passes run in isolation
          // (CodeRabbit PR #31 review, round 2).
          remoteBroadcastTarget = RemoteBroadcastTarget(broadcastTransport);
          await broadcastTransport.start(broadcastContext());
          const fakePeerId = 'silent-viewer-stop';

          final handle =
              await factory.create(const []) as FakePeerConnectionHandle;
          RTCDataChannel? delivered;
          handle.onDataChannel.listen((c) => delivered = c);
          await signaling.submitJoinRequest(broadcastId, fakePeerId);
          await pumpEventQueue();
          expect(delivered, isNotNull);
          expect(delivered!.state, RTCDataChannelState.RTCDataChannelOpen);
          // Deliberately never ack — this viewer never reaches `joined`.

          final left = <String>[];
          final leftSub = broadcastTransport.viewerLeft.listen(left.add);
          addTearDown(leftSub.cancel);

          // `stop()` used to pass `confirmedBefore: true` for every
          // tracked session regardless of whether it was ever
          // ack-confirmed, so a never-joined viewer would wrongly emit
          // `viewerLeft` without ever having emitted `viewerJoined` —
          // breaking the `BroadcastTransport` join/leave contract.
          await broadcastTransport.stop();
          expect(left, isEmpty);
        },
      );
    },
  );
}
