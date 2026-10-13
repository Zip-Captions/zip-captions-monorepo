// PBT-06 stateful property: BroadcastSessionNotifier's state machine,
// driven by generated BroadcastSessionCommand sequences, always matches a
// simplified reference model — `domain-entities.md`'s own transition
// diagram, `business-rules.md` Rule 1's no-op-from-non-idle-states
// invariant, Rule 2's exhaustive failure-to-state mapping, and Rule 5's
// idempotent `endBroadcast()` (Unit 6).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/models/broadcast_failure.dart';
import 'package:zip_core/src/models/broadcast_settings.dart';
import 'package:zip_core/src/models/broadcaster_session_state.dart';
import 'package:zip_core/src/providers/auth_notifier.dart';
import 'package:zip_core/src/providers/broadcast_identity_repository_provider.dart';
import 'package:zip_core/src/providers/broadcast_transport_factory_provider.dart';
import 'package:zip_core/src/providers/captioning_starter_provider.dart';
import 'package:zip_core/src/providers/ice_server_provider_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/broadcast/broadcast_session_notifier.dart';
import 'package:zip_core/src/services/broadcast/broadcast_settings_notifier.dart';

import '../helpers/fake_broadcast_session_collaborators.dart';
import '../helpers/fake_captioning_starter.dart';
import '../helpers/generators.dart';
import '../helpers/pbt.dart';

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
  @override
  BroadcastSettings build() =>
      const BroadcastSettings(sessionName: 'My Stream');
}

void main() {
  Glados(arbitraryBroadcastSessionCommandSequence).test(
    'BroadcastSessionNotifier matches the reference model for any command '
    'sequence',
    (commands) async {
      final identityRepo = FakeBroadcastIdentityRepository();
      final iceProvider = FakeIceServerProvider();
      final statusChannel = FakeStatusChannel();
      final signalingService = FakeBroadcastSignalingService(statusChannel);
      final transport = FakeBroadcastTransport();
      final captioningStarter = FakeCaptioningStarter();
      final authNotifier = _FakeAuthNotifier(
        const AuthState.signedIn(userId: 'u1'),
      );

      final container = ProviderContainer(
        overrides: [
          authNotifierProvider.overrideWith(() => authNotifier),
          broadcastSettingsNotifierProvider.overrideWith(
            _FixedBroadcastSettingsNotifier.new,
          ),
          broadcastIdentityRepositoryProvider.overrideWithValue(identityRepo),
          iceServerProviderProvider.overrideWithValue(iceProvider),
          signalingServiceProvider.overrideWithValue(signalingService),
          broadcastTransportFactoryProvider.overrideWithValue(() => transport),
          captioningStarterProvider.overrideWithValue(captioningStarter),
        ],
      );
      // A cascade can't apply here — the second read's return value is
      // used, unlike the first (a plain build-trigger).
      // ignore: cascade_invocations
      container.read(authNotifierProvider); // build the fake notifier
      final notifier = container.read(
        broadcastSessionNotifierProvider.notifier,
      );

      for (final command in commands) {
        final before = container.read(broadcastSessionNotifierProvider);

        switch (command) {
          case GoLiveCommand(
            :final signedOut,
            :final identityError,
            :final iceError,
            :final publishError,
          ):
            authNotifier.setState(
              signedOut
                  ? const AuthState.signedOut()
                  : const AuthState.signedIn(userId: 'u1'),
            );
            if (identityError) {
              identityRepo.error = const BroadcastAuthorizationException(
                'denied',
              );
            }
            if (iceError) iceProvider.error = Exception('relay down');
            if (publishError) {
              statusChannel.publishLiveError = Exception('publish down');
            }
            await notifier.goLive();
            identityRepo.error = null;
            iceProvider.error = null;
            statusChannel.publishLiveError = null;
          case EndBroadcastCommand():
            await notifier.endBroadcast();
        }

        final after = container.read(broadcastSessionNotifierProvider);

        switch (command) {
          case GoLiveCommand(
            :final signedOut,
            :final identityError,
            :final iceError,
            :final publishError,
          ):
            final acceptedStart =
                before is OfflineState || before is BroadcastFailedState;
            if (!acceptedStart) {
              expect(
                after,
                equals(before),
                reason: 'goLive from $before must be a no-op, got $command',
              );
            } else if (signedOut) {
              expect(
                after,
                const BroadcasterSessionState.failed(
                  BroadcastFailure.signedOut,
                ),
              );
            } else if (identityError) {
              expect(
                after,
                const BroadcasterSessionState.failed(
                  BroadcastFailure.identityUnavailable,
                ),
              );
            } else if (iceError) {
              expect(
                after,
                const BroadcasterSessionState.failed(
                  BroadcastFailure.relayUnavailable,
                ),
              );
            } else if (publishError) {
              expect(
                after,
                const BroadcasterSessionState.failed(
                  BroadcastFailure.signalingUnavailable,
                ),
              );
            } else {
              expect(after, isA<LiveState>());
            }
          case EndBroadcastCommand():
            if (before is! LiveState) {
              expect(
                after,
                equals(before),
                reason: 'endBroadcast from $before must be a no-op',
              );
            } else {
              expect(after, isA<OfflineState>());
            }
        }
      }

      // Rule 5's idempotence: one more explicit endBroadcast from whatever
      // state the sequence ended in behaves exactly like the invariant
      // above already checked for every EndBroadcastCommand in the loop.
      final finalBefore = container.read(broadcastSessionNotifierProvider);
      await notifier.endBroadcast();
      final finalAfter = container.read(broadcastSessionNotifierProvider);
      if (finalBefore is LiveState) {
        expect(finalAfter, isA<OfflineState>());
      } else {
        expect(finalAfter, equals(finalBefore));
      }

      container.dispose();
    },
  );
}
