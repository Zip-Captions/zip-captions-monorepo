// PBT-04: `leave()` is idempotent — f(f(x)) = f(x) over every reachable
// state. Kept separate from the PBT-06 transition suite because the property
// is about teardown idempotence, not the transition table, so a failure
// points at one rule (Unit 7).
import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_core/src/models/broadcast_resolution.dart';
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

void main() {
  Glados(arbitraryViewerSessionCommandSequence).test(
    'PBT-04: leave() twice equals leave() once from any reached state',
    (commands) {
      fakeAsync((async) {
        final resolver = FakeBroadcastResolver();
        final iceProvider = FakeIceServerProvider();
        final statusChannel = FakeStatusChannel();
        final signalingService = FakeBroadcastSignalingService(statusChannel);
        final transport = FakeViewerTransport();
        final container = ProviderContainer(
          overrides: [
            broadcastResolverProvider.overrideWithValue(resolver),
            iceServerProviderProvider.overrideWithValue(iceProvider),
            signalingServiceProvider.overrideWithValue(signalingService),
            viewerTransportFactoryProvider.overrideWithValue(() => transport),
          ],
        );
        final notifier = container.read(
          viewerSessionNotifierProvider.notifier,
        );

        void settle() => async.flushMicrotasks();

        for (final command in commands) {
          switch (command) {
            case JoinCommand(:final differentBroadcast, :final invalid):
              resolver.defaultResolution = differentBroadcast
                  ? const BroadcastResolution.offline()
                  : const BroadcastResolution.live(
                      sessionId: 'session-1',
                      sessionName: 'My Stream',
                    );
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
            case StatusChannelEventCommand(:final live):
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
              transport.emitMessage(
                CaptionActivityChanged(activity: activity),
              );
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

        final stateBeforeLeave = container.read(viewerSessionNotifierProvider);
        final closesBefore = statusChannel.closeCalls;

        unawaited(notifier.leave());
        settle();
        final afterOnce = container.read(viewerSessionNotifierProvider);
        final closesAfterOnce = statusChannel.closeCalls;
        final disconnectsAfterOnce = transport.disconnectCalls;

        unawaited(notifier.leave());
        settle();

        expect(
          container.read(viewerSessionNotifierProvider),
          equals(afterOnce),
          reason: 'second leave changed state (from $stateBeforeLeave)',
        );
        expect(afterOnce, isA<ViewerIdleState>());
        expect(statusChannel.closeCalls, closesAfterOnce);
        expect(transport.disconnectCalls, disconnectsAfterOnce);
        // The final teardown closes the last session's channel exactly once
        // (5 REFINEMENT) and never re-closes an already-released one; the
        // second leave() above changed no counter.
        expect(closesAfterOnce, greaterThanOrEqualTo(closesBefore));
        expect(notifier.viewerBus, isNull);
        expect(notifier.viewerCaptionTarget, isNull);
        expect(notifier.currentBroadcastId, isNull);
        expect(notifier.sessionName, isNull);
        expect(transport.restartCalls, isZero);

        unawaited(transport.disposeControllers());
        container.dispose();
      });
    },
  );
}
