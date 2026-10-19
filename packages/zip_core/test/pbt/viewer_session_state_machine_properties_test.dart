// PBT-06 stateful property: `ViewerSessionNotifier`'s state machine, driven
// by generated `ViewerSessionCommand` sequences, always matches a simplified
// reference model — `business-logic-model.md`'s transition table and its
// invariants 1-5 (Unit 7). No shrinking (the in-tree shim has none,
// PBT-08): any counterexample is hand-reduced into the example suites.
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/viewer_session_state.dart';
import 'package:zip_core/src/providers/broadcast_resolver_provider.dart';
import 'package:zip_core/src/providers/ice_server_provider_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/providers/viewer_transport_factory_provider.dart';
import 'package:zip_core/src/services/broadcast/viewer_session_notifier.dart';

import '../helpers/fake_broadcast_session_collaborators.dart';
import '../helpers/generators.dart';
import '../helpers/pbt.dart';

const _window = Duration(seconds: 120);

/// One realized world per Glados trial.
class _World {
  _World(this.async) {
    container = ProviderContainer(
      overrides: [
        broadcastResolverProvider.overrideWithValue(resolver),
        iceServerProviderProvider.overrideWithValue(iceProvider),
        signalingServiceProvider.overrideWithValue(signalingService),
        viewerTransportFactoryProvider.overrideWithValue(() => transport),
      ],
    );
    notifier = container.read(viewerSessionNotifierProvider.notifier);
  }

  final FakeAsync async;
  final resolver = FakeBroadcastResolver();
  final iceProvider = FakeIceServerProvider();
  final statusChannel = FakeStatusChannel();
  late final signalingService = FakeBroadcastSignalingService(statusChannel);
  final transport = FakeViewerTransport();
  late final ProviderContainer container;
  late final ViewerSessionNotifier notifier;

  ViewerSessionState get state => container.read(viewerSessionNotifierProvider);

  void settle() => async.flushMicrotasks();

  /// F-7.8 auto-joins: live status emissions that reached `connect()` without
  /// a resolve of their own.
  int autoJoins = 0;

  void run(ViewerSessionCommand command) {
    final wasNotBroadcasting = state is NotBroadcastingState;
    switch (command) {
      case JoinCommand(
        :final invalid,
        :final differentBroadcast,
        :final throwsOnConnect,
      ):
        transport.connectError = throwsOnConnect
            ? Exception('connect failed')
            : null;
        unawaited(
          notifier.join(
            invalid
                ? 'not a link'
                : differentBroadcast
                ? 'abcdef'
                : 'k7m9x2',
          ),
        );
        settle();
        transport.connectError = null;
      case StatusChannelEventCommand(:final live):
        if (live && wasNotBroadcasting) autoJoins++;
        statusChannel.emitStatus(
          live
              ? const BroadcastStatus.live(
                  sessionId: 'session-1',
                  sessionName: 'My Stream',
                )
              : const BroadcastStatus.offline(),
        );
        settle();
      case TransportStatusCommand(:final status):
        transport.emitStatus(status);
        settle();
      case ActivityCommand(:final activity):
        transport.emitMessage(CaptionActivityChanged(activity: activity));
        settle();
      case EndedCommand():
        transport.emitMessage(const Ended());
        settle();
      case WindowExpiryCommand():
        async
          ..elapse(_window + const Duration(seconds: 1))
          ..flushMicrotasks()
          ..elapse(const Duration(milliseconds: 1))
          ..flushMicrotasks();
      case LeaveCommand():
        unawaited(notifier.leave());
        settle();
    }
  }

  void close() {
    unawaited(notifier.leave());
    async.flushMicrotasks();
    unawaited(transport.disposeControllers());
    container.dispose();
  }
}

/// Whether [state] may own viewer resources: everything except the two
/// pre-allocation states (`logical-components.md`'s documented
/// `ResolvingState` exemption).
bool _ownsResources(ViewerSessionState state) =>
    state is! ViewerIdleState &&
    state is! InvalidInputState &&
    state is! ResolvingState;

void main() {
  Glados(arbitraryViewerSessionCommandSequence).test(
    'PBT-06: the transition table and invariants hold for any sequence',
    (commands) {
      fakeAsync((async) {
        final world = _World(async);
        for (final command in commands) {
          world.run(command);

          final state = world.state;

          // Invariant 1: the holder outlives the transport for terminal
          // states (F-7.5 step 3), so the caption pipeline is present
          // exactly when resources should exist.
          if (_ownsResources(state)) {
            expect(
              world.notifier.viewerBus,
              isNotNull,
              reason: '$state after $command',
            );
          } else {
            expect(
              world.notifier.viewerBus,
              isNull,
              reason: '$state after $command',
            );
          }

          // Invariant 2 (observable form): while resources are owned the
          // target is available; the holder's identity is stable until a
          // terminal release. Every connect follows either a resolve or an
          // F-7.8 auto-join (a live status emission from `NotBroadcasting`,
          // which connects without re-resolving by design).
          expect(
            world.transport.connectCalls,
            lessThanOrEqualTo(world.resolver.resolveCalls + world.autoJoins),
            reason: 'connect count after $command',
          );

          // Invariant 4: no state carries caption content.
          expect(state.toString(), isNot(contains('Caption(')));

          // Rule 14: never a notifier-owned retry.
          expect(world.transport.restartCalls, isZero);
        }

        // Invariant 5: leave() twice equals leave() once.
        unawaited(world.notifier.leave());
        async.flushMicrotasks();
        final disconnects = world.transport.disconnectCalls;
        expect(world.state, isA<ViewerIdleState>());
        unawaited(world.notifier.leave());
        async.flushMicrotasks();
        expect(world.state, isA<ViewerIdleState>());
        expect(
          world.transport.disconnectCalls,
          disconnects,
          reason: 'second leave must not disconnect again',
        );
        expect(world.notifier.viewerBus, isNull);

        world.close();
      });
    },
  );
}
