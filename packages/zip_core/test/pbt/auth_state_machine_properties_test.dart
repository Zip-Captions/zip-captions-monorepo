// PBT-06 stateful property: AuthNotifier's state machine, driven by
// generated AuthCommand sequences, always matches a simplified reference
// model — AuthFailed is reached only immediately after a SignInCommand that
// specifies a failure outcome, never after a PassiveSessionLossCommand or a
// SignOutCommand (Rule 3), and SignedOut is always reachable and stays
// idempotence-safe once reached (testable-properties.md row 3).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/providers/auth_notifier.dart';
import 'package:zip_core/src/providers/auth_service_provider.dart';

import '../helpers/fake_auth_service.dart';
import '../helpers/generators.dart';
import '../helpers/pbt.dart';

void main() {
  Glados(arbitraryAuthCommandSequence).test(
    'AuthNotifier matches the reference model for any command sequence',
    (commands) async {
      final fake = FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);

      fake
        ..onSignIn = (providerId) async {
          fake.emit(AuthState.signingIn(providerId: providerId));
        }
        ..onSignOut = () async {
          fake.emit(const AuthState.signedOut());
        };

      container.read(authNotifierProvider); // build the notifier
      final notifier = container.read(authNotifierProvider.notifier);

      for (final command in commands) {
        switch (command) {
          case SignInCommand(:final providerId, :final outcome):
            await notifier.signIn(providerId);
            await pumpEventQueue();
            if (outcome == null) {
              fake.emit(AuthState.signedIn(userId: '$providerId-user'));
            } else {
              fake.emit(
                AuthState.authFailed(providerId: providerId, reason: outcome),
              );
            }
            await pumpEventQueue();
          case SignOutCommand():
            await notifier.signOut();
            await pumpEventQueue();
          case PassiveSessionLossCommand():
            fake.emit(const AuthState.signedOut());
            await pumpEventQueue();
        }

        final state = container.read(authNotifierProvider);

        // Reference-model invariant: AuthFailed is only ever reached
        // immediately after a SignInCommand with a non-null outcome.
        if (state is AuthFailedState) {
          expect(
            command,
            isA<SignInCommand>().having(
              (c) => c.outcome,
              'outcome',
              isNotNull,
            ),
            reason: 'AuthFailed must only follow a failed sign-in attempt, '
                'never a $command',
          );
        }

        // Reference-model invariant: SignOut and PassiveSessionLoss always
        // resolve to SignedOut (Rule 3 — never AuthFailed for a passive
        // loss, regardless of what preceded it).
        if (command is SignOutCommand || command is PassiveSessionLossCommand) {
          expect(state, isA<SignedOutState>());
        }
      }

      // Idempotence from SignedOut (Rule 8, via one more explicit signOut).
      await notifier.signOut();
      await pumpEventQueue();
      expect(container.read(authNotifierProvider), isA<SignedOutState>());
    },
  );
}
