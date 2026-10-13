// Example-based tests for `BroadcastSessionNotifier` (Unit 6): the
// sequencing and state-transition logic in `business-rules.md` Rules
// 1-6 and F-6.7. Every collaborator is a hand-written fake (NFR
// Requirements Q1) — this unit's own job is the orchestration, not
// re-verifying Units 2-5's already-tested collaborators.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/models/broadcast_failure.dart';
import 'package:zip_core/src/models/broadcast_settings.dart';
import 'package:zip_core/src/models/broadcaster_session_state.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/providers/auth_notifier.dart';
import 'package:zip_core/src/providers/broadcast_identity_repository_provider.dart';
import 'package:zip_core/src/providers/broadcast_transport_factory_provider.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/captioning_starter_provider.dart';
import 'package:zip_core/src/providers/ice_server_provider_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/broadcast/broadcast_session_notifier.dart';
import 'package:zip_core/src/services/broadcast/broadcast_settings_notifier.dart';

import '../../helpers/fake_broadcast_session_collaborators.dart';
import '../../helpers/fake_captioning_starter.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;

  // Named as a method, matching account_section_test.dart's identical
  // `_FakeAuthNotifier` precedent, not a setter.
  // ignore: use_setters_to_change_properties
  void setState(AuthState next) => state = next;
}

class _FixedBroadcastSettingsNotifier extends BroadcastSettingsNotifier {
  _FixedBroadcastSettingsNotifier(this._fixed);
  final BroadcastSettings _fixed;

  @override
  BroadcastSettings build() => _fixed;
}

void main() {
  late FakeBroadcastIdentityRepository identityRepo;
  late FakeIceServerProvider iceProvider;
  late FakeStatusChannel statusChannel;
  late FakeBroadcastSignalingService signalingService;
  late FakeBroadcastTransport transport;
  late FakeCaptioningStarter captioningStarter;
  late _FakeAuthNotifier authNotifier;
  late ProviderContainer container;

  ProviderContainer buildContainer({
    String sessionName = 'My Stream',
    AuthNotifier Function()? authNotifierFactory,
  }) => ProviderContainer(
    overrides: [
      authNotifierProvider.overrideWith(
        authNotifierFactory ?? () => authNotifier,
      ),
      broadcastSettingsNotifierProvider.overrideWith(
        () => _FixedBroadcastSettingsNotifier(
          BroadcastSettings(sessionName: sessionName),
        ),
      ),
      broadcastIdentityRepositoryProvider.overrideWithValue(identityRepo),
      iceServerProviderProvider.overrideWithValue(iceProvider),
      signalingServiceProvider.overrideWithValue(signalingService),
      broadcastTransportFactoryProvider.overrideWithValue(() => transport),
      captioningStarterProvider.overrideWithValue(captioningStarter),
    ],
  );

  BroadcastSessionNotifier notifier() =>
      container.read(broadcastSessionNotifierProvider.notifier);
  BroadcasterSessionState state() =>
      container.read(broadcastSessionNotifierProvider);

  setUp(() {
    identityRepo = FakeBroadcastIdentityRepository();
    iceProvider = FakeIceServerProvider();
    statusChannel = FakeStatusChannel();
    signalingService = FakeBroadcastSignalingService(statusChannel);
    transport = FakeBroadcastTransport();
    captioningStarter = FakeCaptioningStarter();
    authNotifier = _FakeAuthNotifier(const AuthState.signedIn(userId: 'u1'));
    container = buildContainer()
      // Forces `_FakeAuthNotifier.build()` to run now — `setState` (used
      // by several tests below) sets `state` on the notifier instance
      // directly, which Riverpod only allows once the notifier has
      // actually been built via a first read.
      ..read(authNotifierProvider);
    addTearDown(container.dispose);
    addTearDown(transport.disposeControllers);
  });

  group('Rule 1: acceptance and concurrency', () {
    test('goLive from OfflineState succeeds', () async {
      await notifier().goLive();
      expect(state(), isA<LiveState>());
    });

    test(
      'a second goLive while the first is still in flight is a no-op',
      () async {
        final f1 = notifier().goLive();
        final f2 = notifier().goLive();
        await Future.wait([f1, f2]);

        expect(state(), isA<LiveState>());
        expect(identityRepo.getOrCreateMineCalls, 1);
      },
    );

    test('goLive from LiveState is a no-op', () async {
      await notifier().goLive();
      final liveBroadcastId = (state() as LiveState).broadcast.broadcastId;

      await notifier().goLive();

      expect(identityRepo.getOrCreateMineCalls, 1);
      expect((state() as LiveState).broadcast.broadcastId, liveBroadcastId);
    });

    test('goLive from BroadcastFailedState is accepted (retry)', () async {
      authNotifier.setState(const AuthState.signedOut());
      await notifier().goLive();
      expect(state(), isA<BroadcastFailedState>());

      authNotifier.setState(const AuthState.signedIn(userId: 'u1'));
      await notifier().goLive();
      expect(state(), isA<LiveState>());
    });

    test('an invalid session name is a silent no-op', () async {
      final emptyNameContainer = buildContainer(
        sessionName: '',
        authNotifierFactory: () =>
            _FakeAuthNotifier(const AuthState.signedIn(userId: 'u1')),
      );
      addTearDown(emptyNameContainer.dispose);

      await emptyNameContainer
          .read(broadcastSessionNotifierProvider.notifier)
          .goLive();

      expect(
        emptyNameContainer.read(broadcastSessionNotifierProvider),
        isA<OfflineState>(),
      );
      expect(identityRepo.getOrCreateMineCalls, 0);
    });
  });

  group('Rule 2: failure mapping', () {
    test('signedOut: F2-1 fails before any collaborator is called', () async {
      authNotifier.setState(const AuthState.signedOut());
      await notifier().goLive();

      expect(
        state(),
        const BroadcasterSessionState.failed(BroadcastFailure.signedOut),
      );
      expect(identityRepo.getOrCreateMineCalls, 0);
    });

    test('identityUnavailable: F2-2 fails, no unwind needed', () async {
      identityRepo.error = const BroadcastAuthorizationException('denied');
      await notifier().goLive();

      expect(
        state(),
        const BroadcasterSessionState.failed(
          BroadcastFailure.identityUnavailable,
        ),
      );
      expect(iceProvider.sessionIdsRequested, isEmpty);
    });

    test('relayUnavailable: F2-3 fails, no unwind needed', () async {
      iceProvider.error = Exception('relay down');
      await notifier().goLive();

      expect(
        state(),
        const BroadcasterSessionState.failed(
          BroadcastFailure.relayUnavailable,
        ),
      );
      expect(transport.startedWith, isNull);
    });

    test('unknown: F2-5 (transport.start) fails, no unwind', () async {
      transport.startError = Exception('start failed');
      await notifier().goLive();

      expect(
        state(),
        const BroadcasterSessionState.failed(BroadcastFailure.unknown),
      );
      expect(transport.stopCalls, 0);
    });

    test(
      'unknown: F2-6 (target create/register/prime) fails, unwinds '
      'transport.stop() (CodeRabbit PR #34 review — correcting '
      "business-rules.md's literal 'no unwind' text, which would "
      'otherwise leave the transport running and violate the '
      '"no session resources in BroadcastFailedState" invariant)',
      () async {
        captioningStarter.currentActivityError = Exception('boom');
        await notifier().goLive();

        expect(
          state(),
          const BroadcasterSessionState.failed(BroadcastFailure.unknown),
        );
        expect(transport.stopCalls, 1);
      },
    );

    test(
      'signalingUnavailable: F2-7 (publishLive) fails, unwinds '
      'registry.remove(target) -> transport.stop()',
      () async {
        statusChannel.publishLiveError = Exception('publish down');
        await notifier().goLive();

        expect(
          state(),
          const BroadcasterSessionState.failed(
            BroadcastFailure.signalingUnavailable,
          ),
        );
        expect(transport.stopCalls, 1);
      },
    );

    test(
      'signalingUnavailable unwind resolves to BroadcastFailedState even '
      'if transport.stop() itself throws (CodeRabbit PR #34 review — an '
      'escaping exception here would otherwise strand the notifier in '
      'StartingState, where both retry and sign-out are refused)',
      () async {
        statusChannel.publishLiveError = Exception('publish down');
        transport.stopError = Exception('stop also failed');

        await notifier().goLive();

        expect(
          state(),
          const BroadcasterSessionState.failed(
            BroadcastFailure.signalingUnavailable,
          ),
        );
        expect(transport.stopCalls, 1);
      },
    );
  });

  group('Rule 3: auto-start captioning is best-effort', () {
    // A dedicated container per test, each with its own fresh
    // `_FakeAuthNotifier` — reusing the outer `authNotifier` instance
    // across two independently-built containers trips Riverpod's
    // "already initialized" guard, since each container tries to build
    // the same notifier object a second time.
    ProviderContainer buildAutoStartContainer() {
      final c = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(
            () => _FakeAuthNotifier(const AuthState.signedIn(userId: 'u1')),
          ),
          broadcastSettingsNotifierProvider.overrideWith(
            () => _FixedBroadcastSettingsNotifier(
              const BroadcastSettings(
                sessionName: 'My Stream',
                autoStartCaptioning: true,
              ),
            ),
          ),
          broadcastIdentityRepositoryProvider.overrideWithValue(identityRepo),
          iceServerProviderProvider.overrideWithValue(iceProvider),
          signalingServiceProvider.overrideWithValue(signalingService),
          broadcastTransportFactoryProvider.overrideWithValue(
            () => transport,
          ),
          captioningStarterProvider.overrideWithValue(captioningStarter),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('autoStartCaptioning + currently idle calls start()', () async {
      captioningStarter.currentActivity = CaptionActivity.inactive;
      final c = buildAutoStartContainer();

      await c.read(broadcastSessionNotifierProvider.notifier).goLive();

      expect(captioningStarter.startCalls, 1);
      expect(
        (c.read(broadcastSessionNotifierProvider) as LiveState)
            .broadcast
            .captionActivity,
        CaptionActivity.active,
      );
    });

    test('autoStartCaptioning + already active never calls start()', () async {
      captioningStarter.currentActivity = CaptionActivity.active;
      final c = buildAutoStartContainer();

      await c.read(broadcastSessionNotifierProvider.notifier).goLive();

      expect(captioningStarter.startCalls, 0);
    });

    test('autoStartCaptioning false never calls start()', () async {
      await notifier().goLive();
      expect(captioningStarter.startCalls, 0);
    });

    test('a failing start() never fails goLive()', () async {
      captioningStarter.startError = Exception('audio device busy');
      final c = buildAutoStartContainer();

      await c.read(broadcastSessionNotifierProvider.notifier).goLive();

      expect(c.read(broadcastSessionNotifierProvider), isA<LiveState>());
    });
  });

  group('Rule 4: caption activity single source of truth', () {
    test(
      'LiveBroadcast.captionActivity is seeded, then only the owned '
      'subscription updates it',
      () async {
        captioningStarter.currentActivity = CaptionActivity.active;
        await notifier().goLive();
        expect(
          (state() as LiveState).broadcast.captionActivity,
          CaptionActivity.active,
        );

        container
            .read(captionBusProvider)
            .publish(
              const SessionStateEvent(PausedState(sessionId: 's1')),
            );
        await Future<void>.delayed(Duration.zero);

        expect(
          (state() as LiveState).broadcast.captionActivity,
          CaptionActivity.paused,
        );
      },
    );
  });

  group('Rule 5: endBroadcast is idempotent and only valid from LiveState', () {
    test('endBroadcast from LiveState tears down exactly once', () async {
      await notifier().goLive();
      await notifier().endBroadcast();

      expect(state(), isA<OfflineState>());
      expect(transport.stopCalls, 1);
      expect(transport.sendBroadcastEndedCalls, 1);
      expect(transport.sentToAll, [const Ended()]);
    });

    test('endBroadcast from OfflineState is a safe no-op', () async {
      await notifier().endBroadcast();
      expect(state(), isA<OfflineState>());
      expect(transport.stopCalls, 0);
    });

    test(
      'endBroadcast called again after it already completed is a no-op',
      () async {
        await notifier().goLive();
        await notifier().endBroadcast();
        await notifier().endBroadcast();

        expect(transport.stopCalls, 1);
      },
    );

    test('two overlapping endBroadcast calls dispose exactly once', () async {
      await notifier().goLive();
      final f1 = notifier().endBroadcast();
      final f2 = notifier().endBroadcast();
      await Future.wait([f1, f2]);

      expect(state(), isA<OfflineState>());
      expect(transport.stopCalls, 1);
    });
  });

  group('Rule 6: status channel lifetime', () {
    test('stays open for the whole LiveState lifetime', () async {
      await notifier().goLive();
      expect(statusChannel.closeCalls, 0);
    });

    test('closes on endBroadcast', () async {
      await notifier().goLive();
      await notifier().endBroadcast();
      expect(statusChannel.closeCalls, 1);
    });

    test('is never closed on a goLive failure before F2-7', () async {
      iceProvider.error = Exception('relay down');
      await notifier().goLive();
      expect(statusChannel.closeCalls, 0);
      expect(statusChannel.publishOfflineCalls, 0);
    });
  });

  group('F-6.7: end and restart', () {
    test(
      'a fresh goLive after endBroadcast reuses broadcastId, gets a '
      'fresh sessionId',
      () async {
        await notifier().goLive();
        final firstBroadcast = (state() as LiveState).broadcast;
        await notifier().endBroadcast();

        await notifier().goLive();
        final secondBroadcast = (state() as LiveState).broadcast;

        expect(secondBroadcast.broadcastId, firstBroadcast.broadcastId);
        expect(secondBroadcast.sessionId, isNot(firstBroadcast.sessionId));
        expect(identityRepo.getOrCreateMineCalls, 2);
      },
    );
  });
}
