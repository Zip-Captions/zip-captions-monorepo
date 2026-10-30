// Example-based tests for `ViewerSessionNotifier` (Unit 7, S-19): the join,
// teardown and status-mapping rules in `business-rules.md` Rules 1-8 and
// `business-logic-model.md` F-7.2/F-7.5/F-7.7/F-7.8. Every collaborator is a
// hand-written fake (NFR Requirements Q1) — this unit's own job is the
// orchestration, not re-verifying Units 2-5's already-tested collaborators.
// `hide Timeout`: `flutter_test` re-exports `test_api`'s `Timeout`, which
// collides with `ConnectFailure`'s `Timeout` variant.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:logging/logging.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_resolution.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/viewer_session_state.dart';
import 'package:zip_core/src/providers/broadcast_resolver_provider.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/ice_server_provider_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/providers/viewer_transport_factory_provider.dart';
import 'package:zip_core/src/services/broadcast/viewer_session_notifier.dart';

import '../../helpers/fake_broadcast_session_collaborators.dart';

const _validInput = 'k7m9x2';
const _otherInput = 'abcdef';
const _window = Duration(seconds: 120);

void main() {
  late FakeBroadcastResolver resolver;
  late FakeIceServerProvider iceProvider;
  late FakeStatusChannel statusChannel;
  late FakeBroadcastSignalingService signalingService;
  late FakeViewerTransport transport;
  late ProviderContainer container;

  ProviderContainer buildContainer() => ProviderContainer(
    overrides: [
      broadcastResolverProvider.overrideWithValue(resolver),
      iceServerProviderProvider.overrideWithValue(iceProvider),
      signalingServiceProvider.overrideWithValue(signalingService),
      viewerTransportFactoryProvider.overrideWithValue(() => transport),
    ],
  );

  ViewerSessionNotifier notifier() =>
      container.read(viewerSessionNotifierProvider.notifier);
  ViewerSessionState state() => container.read(viewerSessionNotifierProvider);

  /// Rebuilds the container on the current zone's fake clock (the
  /// `fakeAsync` rows need the container created inside the zone).
  void rebuildContainer() {
    container.dispose();
    container = buildContainer();
    addTearDown(container.dispose);
  }

  Future<void> joinLive() async {
    resolver.defaultResolution = const BroadcastResolution.live(
      sessionId: 'session-1',
      sessionName: 'My Stream',
    );
    await notifier().join(_validInput);
  }

  /// Lets the broadcast-stream deliveries run.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  setUp(() {
    resolver = FakeBroadcastResolver();
    iceProvider = FakeIceServerProvider();
    statusChannel = FakeStatusChannel();
    signalingService = FakeBroadcastSignalingService(statusChannel);
    transport = FakeViewerTransport();
    container = buildContainer();
    addTearDown(() {
      // Rule 14: the session layer never drives the transport's retry loop.
      expect(transport.restartCalls, isZero);
    });
    addTearDown(transport.disposeControllers);
  });

  group('Rule 2: parse validity gates every network action', () {
    test('AC-2: invalid input with no session sets InvalidInputState '
        'without touching the network', () async {
      await notifier().join('not a link');

      expect(state(), isA<InvalidInputState>());
      expect(resolver.resolveCalls, isZero);
      expect(transport.connectCalls, isZero);
      expect(iceProvider.sessionIdsRequested, isEmpty);
    });

    test('AC-2: empty input is invalid', () async {
      await notifier().join('   ');
      expect(state(), isA<InvalidInputState>());
    });

    test('AC-1: a valid bare code resolves and connects', () async {
      await joinLive();

      expect(resolver.resolveIds.single, BroadcastId.parse(_validInput));
      expect(transport.connectCalls, 1);
      expect(transport.startedWith?.sessionId, 'session-1');
      expect(notifier().sessionName, 'My Stream');
      expect(state(), isA<ConnectingState>());
    });
  });

  group('Rule 1: idempotence per broadcast', () {
    test('invalid input with an active session is a no-op', () async {
      await joinLive();
      final before = state();

      await notifier().join('not a link');

      expect(state(), equals(before));
      expect(notifier().viewerBus, isNotNull);
      expect(resolver.resolveCalls, 1);
    });

    test('same-id join in a non-terminal state is a no-op', () async {
      await joinLive();

      await notifier().join(_validInput.toUpperCase());

      expect(resolver.resolveCalls, 1);
      expect(transport.connectCalls, 1);
    });

    test(
      'a repeated join for the same id while resolving resolves once',
      () async {
        final held = Completer<BroadcastResolution>();
        resolver.pending = held;

        final first = notifier().join(_validInput);
        expect(state(), isA<ResolvingState>());
        final second = notifier().join(_validInput);
        await settle();

        expect(resolver.resolveCalls, 1);
        expect(resolver.resolveIds, [BroadcastId.parse(_validInput)]);

        held.complete(
          const BroadcastResolution.live(
            sessionId: 'session-1',
            sessionName: 'My Stream',
          ),
        );
        await first;
        await second;

        expect(transport.connectCalls, 1);
        expect(state(), isA<ConnectingState>());
      },
    );

    test('a stale request does not release the in-flight id it lost', () async {
      final secondHeld = Completer<BroadcastResolution>();
      final firstHeld = Completer<BroadcastResolution>();
      resolver.pending = firstHeld;

      unawaited(notifier().join(_validInput));
      expect(state(), isA<ResolvingState>());

      // Supersede the first request after it has started: the different
      // id's join leaves first (nothing is allocated yet) and resolves
      // afresh, so the second request owns the in-flight slot.
      transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      await settle();
      resolver.pending = secondHeld;
      final second = notifier().join(_otherInput);
      await settle();
      expect(resolver.resolveCalls, 2);
      expect(notifier().resolvingBroadcastId, BroadcastId.parse(_otherInput));

      // The first request now completes in stale form: its cleanup must not
      // clear the newer request's in-flight id. (Its continuation also
      // aborts on the epoch check before it can allocate anything.)
      firstHeld.complete(const BroadcastResolution.offline());
      await settle();
      await settle();
      expect(notifier().resolvingBroadcastId, BroadcastId.parse(_otherInput));

      secondHeld.complete(const BroadcastResolution.offline());
      await settle();
      await second;
      expect(notifier().resolvingBroadcastId, isNull);
    });

    test(
      'a stale request for the same id does not release the newer slot',
      () async {
        // Leave() resets the slot, so a second join for the SAME id starts a
        // fresh request. The first request completing then must not clear the
        // slot the second one owns (CodeRabbit round 3).
        final firstHeld = Completer<BroadcastResolution>();
        final secondHeld = Completer<BroadcastResolution>();
        resolver.pending = firstHeld;

        final first = notifier().join(_validInput);
        await settle();
        expect(state(), isA<ResolvingState>());

        await notifier().leave();
        resolver.pending = secondHeld;
        final second = notifier().join(_validInput);
        await settle();
        expect(resolver.resolveCalls, 2);
        expect(notifier().resolvingBroadcastId, BroadcastId.parse(_validInput));

        firstHeld.complete(const BroadcastResolution.offline());
        await settle();
        await settle();

        // The stale request must not have released the newer request's slot:
        // a third join for the same id is still a no-op.
        expect(notifier().resolvingBroadcastId, BroadcastId.parse(_validInput));
        final callsBeforeThird = resolver.resolveCalls;
        await notifier().join(_validInput);
        await settle();
        expect(resolver.resolveCalls, callsBeforeThird);

        secondHeld.complete(const BroadcastResolution.offline());
        await settle();
        await second;
        await first;
        expect(notifier().resolvingBroadcastId, isNull);
      },
    );

    test('a different id leaves first, then resolves', () async {
      await joinLive();
      resolver.defaultResolution = const BroadcastResolution.offline();

      await notifier().join(_otherInput);

      expect(transport.disconnectCalls, 1);
      expect(resolver.resolveCalls, 2);
      expect(resolver.resolveIds.last, BroadcastId.parse(_otherInput));
      expect(state(), isA<NotBroadcastingState>());
    });
  });

  group('Rule 5 / F-7.2: the resolution table', () {
    test(
      'notFound maps to CannotConnect(NotFound) with no resources',
      () async {
        resolver.defaultResolution = const BroadcastResolution.notFound();

        await notifier().join(_validInput);

        expect(
          state(),
          equals(const ViewerSessionState.cannotConnect(NotFound())),
        );
        expect(notifier().viewerBus, isNull);
        expect(notifier().currentBroadcastId, isNull);
      },
    );

    test('rateLimited maps to CannotConnect(RateLimited)', () async {
      resolver.defaultResolution = const BroadcastResolution.rateLimited();
      await notifier().join(_validInput);
      expect(
        state(),
        equals(const ViewerSessionState.cannotConnect(RateLimited())),
      );
    });

    test('resolutionFailed maps to CannotConnect(ResolutionFailed)', () async {
      resolver.error = Exception('rpc down');
      await notifier().join(_validInput);
      expect(
        state(),
        equals(const ViewerSessionState.cannotConnect(ResolutionFailed())),
      );
    });

    test(
      'offline maps to NotBroadcasting and opens the status watch',
      () async {
        resolver.defaultResolution = const BroadcastResolution.offline();
        statusChannel.watchCalls = 0;

        await notifier().join(_validInput);

        expect(state(), isA<NotBroadcastingState>());
        expect(statusChannel.watchCalls, 1);
        expect(transport.connectCalls, isZero);
        expect(notifier().viewerBus, isNotNull);
      },
    );

    test('live maps to Connecting and connects', () async {
      await joinLive();
      expect(state(), isA<ConnectingState>());
      expect(notifier().viewerCaptionTarget, isNotNull);
    });

    test('iceServersFor throwing maps to CannotConnect(IceFailed)', () async {
      resolver.defaultResolution = const BroadcastResolution.live(
        sessionId: 'session-1',
        sessionName: 'My Stream',
      );
      iceProvider.error = Exception('turn down');

      await notifier().join(_validInput);

      expect(
        state(),
        equals(const ViewerSessionState.cannotConnect(IceFailed())),
      );
      expect(transport.connectCalls, isZero);
    });

    test(
      'connect() throwing maps to CannotConnect(IceFailed), never Timeout',
      () async {
        transport.connectError = Exception('channel open failed');

        await joinLive();

        expect(
          state(),
          equals(const ViewerSessionState.cannotConnect(IceFailed())),
        );
      },
    );

    for (final failure in const <ConnectFailure>[
      BroadcastFull(),
      IceFailed(),
      SignalingRejected(),
      Timeout(),
    ]) {
      test(
        'transport Failed(${failure.runtimeType}) maps per Rule 5',
        () async {
          await joinLive();
          transport.emitStatus(Failed(failure));
          await settle();

          expect(
            state(),
            equals(
              failure is BroadcastFull
                  ? const ViewerSessionState.full()
                  : ViewerSessionState.cannotConnect(failure),
            ),
          );
          // Every Failed outcome releases the connection (F-7.4 Rule 6).
          expect(transport.disconnectCalls, 1);
          expect(statusChannel.closeCalls, 1);
        },
      );
    }

    test(
      'transport Connected maps to LiveView with the routing type',
      () async {
        await joinLive();
        transport.emitStatus(const Connected(ConnectionType.turnRelayed));
        await settle();

        expect(
          state(),
          equals(
            const ViewerSessionState.liveView(
              captionActivity: CaptionActivity.inactive,
              connectionType: ConnectionType.turnRelayed,
            ),
          ),
        );
      },
    );
  });

  group('Rule 7: the viewer pipeline is isolated', () {
    test('viewer bus is a fresh instance distinct from the app bus', () async {
      final appBus = container.read(captionBusProvider);
      await joinLive();

      expect(notifier().viewerBus, isNotNull);
      expect(notifier().viewerBus, isNot(same(appBus)));
    });

    test(
      'a caption reaches the session target and no repository is set',
      () async {
        await joinLive();
        // Two emits, intentionally sequential (a busy broadcast).
        transport
          ..emitMessage(
            const CaptionActivityChanged(activity: CaptionActivity.active),
          )
          ..emitMessage(
            Caption(result: captionResult('hello viewer')),
          );
        await settle();
        // The target emits on a 50ms debounce.
        await Future<void>.delayed(const Duration(milliseconds: 80));

        final target = notifier().viewerCaptionTarget!;
        expect(
          target.visibleCaptions.map((e) => e.text),
          contains('hello viewer'),
        );
        expect(notifier().viewerBus!.stream.isBroadcast, isTrue);
      },
    );

    test('activity events update LiveView in place', () async {
      await joinLive();
      transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      await settle();

      transport.emitMessage(
        const CaptionActivityChanged(activity: CaptionActivity.paused),
      );
      await settle();

      final current = state();
      expect(current, isA<LiveViewState>());
      expect(
        (current as LiveViewState).captionActivity,
        equals(CaptionActivity.paused),
      );
    });
  });

  group('F-7.5 / Rule 6: ended is terminal', () {
    test(
      'ended maps to Ended, releases the transport, keeps the pipeline',
      () async {
        await joinLive();
        transport.emitStatus(const Connected(ConnectionType.p2pDirect));
        await settle();

        transport.emitMessage(const Ended());
        await settle();

        expect(state(), isA<EndedState>());
        expect(transport.disconnectCalls, 1);
        expect(statusChannel.closeCalls, 1);
        // F-7.5 step 3: the bus/registry/target stay alive until leave().
        expect(notifier().viewerBus, isNotNull);
        expect(notifier().viewerCaptionTarget, isNotNull);
      },
    );

    test(
      'no auto-rejoin after Ended once the same broadcaster goes live',
      () async {
        await joinLive();
        transport.emitMessage(const Ended());
        await settle();

        statusChannel.emitStatus(
          const BroadcastStatus.live(
            sessionId: 'session-2',
            sessionName: 'My Stream',
          ),
        );
        await settle();

        expect(state(), isA<EndedState>());
        expect(transport.connectCalls, 1);
      },
    );
  });

  group('F-7.7: leave', () {
    test(
      'leave from every state returns to Idle and releases resources',
      () async {
        await joinLive();

        await notifier().leave();

        expect(state(), isA<ViewerIdleState>());
        expect(notifier().viewerBus, isNull);
        expect(notifier().viewerCaptionTarget, isNull);
        expect(notifier().sessionName, isNull);
        expect(notifier().currentBroadcastId, isNull);
        expect(transport.disconnectCalls, 1);
        expect(statusChannel.closeCalls, 1);
      },
    );

    test('leave is idempotent', () async {
      await joinLive();

      await notifier().leave();
      await notifier().leave();

      expect(state(), isA<ViewerIdleState>());
      expect(transport.disconnectCalls, 1);
      expect(statusChannel.closeCalls, 1);
    });

    test('leave from Idle does nothing', () async {
      await notifier().leave();
      expect(state(), isA<ViewerIdleState>());
      expect(transport.disconnectCalls, isZero);
    });

    test('a stale join does not resurrect state after leave', () async {
      final held = Completer<BroadcastResolution>();
      resolver.pending = held;

      final joinFuture = notifier().join(_validInput);
      expect(state(), isA<ResolvingState>());
      await notifier().leave();
      held.complete(
        const BroadcastResolution.live(
          sessionId: 'session-1',
          sessionName: 'My Stream',
        ),
      );
      await joinFuture;

      expect(state(), isA<ViewerIdleState>());
      expect(transport.connectCalls, isZero);
      expect(notifier().viewerBus, isNull);
    });
  });

  group('F-7.8: auto-join from NotBroadcasting', () {
    test('a live status event auto-joins without re-resolving', () async {
      resolver.defaultResolution = const BroadcastResolution.offline();
      await notifier().join(_validInput);
      final resolveCalls = resolver.resolveCalls;

      statusChannel.emitStatus(
        const BroadcastStatus.live(
          sessionId: 'session-9',
          sessionName: 'Late Show',
        ),
      );
      await settle();

      expect(resolver.resolveCalls, resolveCalls);
      expect(transport.connectCalls, 1);
      expect(transport.startedWith?.sessionId, 'session-9');
      expect(notifier().sessionName, 'Late Show');
      expect(state(), isA<ConnectingState>());
    });

    test('offline while NotBroadcasting is a no-op', () async {
      resolver.defaultResolution = const BroadcastResolution.offline();
      await notifier().join(_validInput);

      statusChannel.emitStatus(const BroadcastStatus.offline());
      await settle();

      expect(state(), isA<NotBroadcastingState>());
      expect(transport.connectCalls, isZero);
    });
  });

  group('Rule 8: no caption content in state or logs', () {
    test(
      'state names and log records carry no join input or caption text',
      () async {
        final records = <LogRecord>[];
        final sub = Logger.root.onRecord.listen(records.add);
        addTearDown(sub.cancel);

        await joinLive();
        transport.emitMessage(
          Caption(result: captionResult('SENTINEL caption')),
        );
        // Delivery to the viewer bus target is asynchronous (and the target
        // debounces): without this the caption under test never reaches the
        // receiver before the assertions, and the redaction checks below
        // would pass vacuously.
        await settle();
        await Future<void>.delayed(const Duration(milliseconds: 80));
        expect(
          notifier().viewerCaptionTarget!.visibleCaptions.map((e) => e.text),
          contains('SENTINEL caption'),
        );

        expect(state().toString(), isNot(contains('SENTINEL')));
        expect(state().toString(), isNot(contains(_validInput)));
        for (final record in records) {
          final message = record.message.toLowerCase();
          expect(message, isNot(contains('sentinel')));
          // The parsed join input must never appear, in any case: the screen
          // uppercases the code before it reaches join().
          expect(message, isNot(contains(_validInput.toLowerCase())));
        }
        expect(records, isNotEmpty);
      },
    );
  });

  group('F-7.4: the reconnect window rows (fakeAsync)', () {
    // Expiry teardown awaits subscription cancellations and disconnect(),
    // which fakeAsync settles on the next flush. Kept as one helper so the
    // three flush calls are not mistaken for chainable duplicate receivers.
    void settleExpiry(FakeAsync async, {Duration delay = Duration.zero}) {
      if (delay > Duration.zero) async.elapse(delay);
      async
        ..flushMicrotasks()
        ..elapse(const Duration(milliseconds: 1))
        ..flushMicrotasks();
    }

    void inFakeAsync(void Function(FakeAsync async) body) => fakeAsync((async) {
      rebuildContainer();
      body(async);
      async.flushMicrotasks();
    });

    test('Interrupted enters Reconnecting with one timer and no restart', () {
      inFakeAsync((async) {
        unawaited(joinLive());
        async.flushMicrotasks();

        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        expect(state(), isA<ViewerReconnectingState>());
        expect(async.pendingTimers, hasLength(1));
      });
    });

    test('Connected before expiry cancels the window', () {
      inFakeAsync((async) {
        unawaited(joinLive());
        async.flushMicrotasks();

        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        transport.emitStatus(const Connected(ConnectionType.p2pDirect));
        async.flushMicrotasks();

        expect(state(), isA<LiveViewState>());
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('expiry with the last status live disconnects then IceFailed', () {
      inFakeAsync((async) {
        unawaited(joinLive());
        async.flushMicrotasks();

        statusChannel.emitStatus(
          const BroadcastStatus.live(
            sessionId: 'session-1',
            sessionName: 'My Stream',
          ),
        );
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        // Expiry teardown awaits subscription cancellations and
        // disconnect(), which fakeAsync settles on the next flush.
        settleExpiry(async, delay: _window + const Duration(seconds: 1));

        expect(
          state(),
          equals(const ViewerSessionState.cannotConnect(IceFailed())),
        );
        expect(transport.disconnectCalls, greaterThanOrEqualTo(1));
      });
    });

    test('expiry with the last status offline lands in NotBroadcasting', () {
      inFakeAsync((async) {
        unawaited(joinLive());
        async.flushMicrotasks();

        statusChannel.emitStatus(const BroadcastStatus.offline());
        transport.emitStatus(const Interrupted());

        // The extra flush processes the status emission before expiry
        // reads lastStatus (F-7.4 step 4); settleExpiry covers teardown's
        // own awaits.
        async.flushMicrotasks();
        settleExpiry(async, delay: _window + const Duration(seconds: 1));

        expect(state(), isA<NotBroadcastingState>());
      });
    });

    test('expiry with no status emission ever lands in ResolutionFailed', () {
      inFakeAsync((async) {
        unawaited(joinLive());
        async.flushMicrotasks();

        transport.emitStatus(const Interrupted());

        // The extra flush processes the status emission before expiry
        // reads lastStatus (F-7.4 step 4); settleExpiry covers teardown's
        // own awaits.
        async.flushMicrotasks();
        settleExpiry(async, delay: _window + const Duration(seconds: 1));

        expect(
          state(),
          equals(const ViewerSessionState.cannotConnect(ResolutionFailed())),
        );
      });
    });

    test('offline while Reconnecting moves to NotBroadcasting immediately', () {
      inFakeAsync((async) {
        unawaited(joinLive());
        async.flushMicrotasks();

        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        statusChannel.emitStatus(const BroadcastStatus.offline());
        async.flushMicrotasks();

        expect(state(), isA<NotBroadcastingState>());
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  test(
    'AC: iceServersForBroadcast receives the resolved broadcast id, and the '
    'authenticated session-scoped call is never made (Unit 9, B2: the viewer '
    'is anonymous)',
    () async {
      await joinLive();
      expect(
        iceProvider.broadcastIdsRequested,
        equals([_validInput.toUpperCase()]),
      );
      expect(iceProvider.sessionIdsRequested, isEmpty);
    },
  );
}

/// An `SttResult` carrying [text], for the caption-path rows.
SttResult captionResult(String text) => SttResult(
  text: text,
  isFinal: true,
  confidence: 1,
  timestamp: DateTime.utc(2026),
  sourceId: 'default',
);
