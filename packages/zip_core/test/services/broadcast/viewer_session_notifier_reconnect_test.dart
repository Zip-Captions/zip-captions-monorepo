// F-7.4's reconnect matrix and the timer-ownership rules (Unit 7, S-19
// AC7): one test per expiry outcome and per cancel path, kept separate from
// the main example suite so the `fakeAsync`-only rows read on their own.
// `hide Timeout`: collides with `ConnectFailure`'s `Timeout`.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_core/src/models/broadcast_resolution.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/viewer_session_state.dart';
import 'package:zip_core/src/providers/broadcast_resolver_provider.dart';
import 'package:zip_core/src/providers/ice_server_provider_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/providers/viewer_transport_factory_provider.dart';
import 'package:zip_core/src/services/broadcast/viewer_session_notifier.dart';

import '../../helpers/fake_broadcast_session_collaborators.dart';

const _window = Duration(seconds: 120);

void main() {
  late FakeBroadcastResolver resolver;
  late FakeIceServerProvider iceProvider;
  late FakeStatusChannel statusChannel;
  late FakeBroadcastSignalingService signalingService;
  late FakeViewerTransport transport;
  late ProviderContainer container;

  setUp(() {
    resolver = FakeBroadcastResolver(
      defaultResolution: const BroadcastResolution.live(
        sessionId: 'session-1',
        sessionName: 'My Stream',
      ),
    );
    iceProvider = FakeIceServerProvider();
    statusChannel = FakeStatusChannel();
    signalingService = FakeBroadcastSignalingService(statusChannel);
    transport = FakeViewerTransport();
  });

  tearDown(() {
    // Rule 14: no notifier-owned retry loop, in any row.
    expect(transport.restartCalls, isZero);
    unawaited(transport.disposeControllers());
    // The container is created per test inside `run`; this guard keeps a
    // failed `run` from leaking one.
    container.dispose();
  });

  /// Runs [body] on a fake clock with a container built inside that zone.
  void run(
    void Function(FakeAsync async, ViewerSessionNotifier notifier) body,
  ) {
    fakeAsync((async) {
      container = ProviderContainer(
        overrides: [
          broadcastResolverProvider.overrideWithValue(resolver),
          iceServerProviderProvider.overrideWithValue(iceProvider),
          signalingServiceProvider.overrideWithValue(signalingService),
          viewerTransportFactoryProvider.overrideWithValue(() => transport),
        ],
      );
      final notifier = container.read(viewerSessionNotifierProvider.notifier);
      unawaited(notifier.join('k7m9x2'));
      async.flushMicrotasks();
      transport.emitStatus(const Connected(ConnectionType.p2pDirect));
      async.flushMicrotasks();
      body(async, notifier);
    });
  }

  /// Flushes the teardown awaits and then the delay, in the order a real
  /// clock would (the expiry callback itself is the timer under test).
  void expire(FakeAsync async) {
    async
      ..elapse(_window + const Duration(seconds: 1))
      ..flushMicrotasks()
      ..elapse(const Duration(milliseconds: 1))
      ..flushMicrotasks();
  }

  group('Rule 3: one timer per interruption, transport-owned retries', () {
    test('Interrupted starts exactly one timer', () {
      run((async, notifier) {
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        expect(notifier.state, isA<ViewerReconnectingState>());
        expect(async.pendingTimers, hasLength(1));
      });
    });

    test('a second Interrupted restarts a single timer, not a second one', () {
      run((async, notifier) {
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        expect(notifier.state, isA<ViewerReconnectingState>());
        expect(async.pendingTimers, hasLength(1));
      });
    });
  });

  group('Rule 3: every cancellation path', () {
    test('Connected cancels the window', () {
      run((async, notifier) {
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        transport.emitStatus(const Connected(ConnectionType.turnRelayed));
        async.flushMicrotasks();

        expect(notifier.state, isA<LiveViewState>());
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('leave cancels the window', () {
      run((async, notifier) {
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        unawaited(notifier.leave());
        async.flushMicrotasks();

        expect(notifier.state, isA<ViewerIdleState>());
        expect(async.pendingTimers, isEmpty);
      });
    });

    test('a terminal transition cancels the window', () {
      run((async, notifier) {
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        transport.emitMessage(const Ended());
        async.flushMicrotasks();

        expect(notifier.state, isA<EndedState>());
        expect(async.pendingTimers, isEmpty);
      });
    });
  });

  group('F-7.4 step 4: the three expiry outcomes', () {
    test('last status offline -> NotBroadcasting, watch stays open', () {
      run((async, notifier) {
        statusChannel.emitStatus(const BroadcastStatus.offline());
        async.flushMicrotasks();
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        expire(async);

        expect(notifier.state, isA<NotBroadcastingState>());
        expect(transport.disconnectCalls, isZero);
        expect(statusChannel.closeCalls, isZero);
      });
    });

    test('no emission ever -> ResolutionFailed', () {
      run((async, notifier) {
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        expire(async);

        expect(
          notifier.state,
          equals(
            const ViewerSessionState.cannotConnect(ResolutionFailed()),
          ),
        );
      });
    });

    test('last status live -> disconnect then IceFailed', () {
      run((async, notifier) {
        statusChannel.emitStatus(
          const BroadcastStatus.live(
            sessionId: 'session-1',
            sessionName: 'My Stream',
          ),
        );
        async.flushMicrotasks();
        transport.emitStatus(const Interrupted());
        async.flushMicrotasks();

        expire(async);

        expect(transport.disconnectCalls, greaterThanOrEqualTo(1));
        expect(
          notifier.state,
          equals(const ViewerSessionState.cannotConnect(IceFailed())),
        );
      });
    });
  });
}
