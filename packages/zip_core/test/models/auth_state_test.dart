import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/auth_failure.dart';
import 'package:zip_core/src/models/auth_state.dart';

void main() {
  group('AuthState', () {
    test('signedOut is a const singleton-equivalent value', () {
      const a = AuthState.signedOut();
      const b = AuthState.signedOut();
      expect(a, equals(b));
      expect(a, isA<SignedOutState>());
    });

    test('signingIn carries providerId', () {
      const state = AuthState.signingIn(providerId: 'google');
      expect(state, isA<SigningInState>());
      expect((state as SigningInState).providerId, 'google');
    });

    test('signingIn equality compares providerId', () {
      const a = AuthState.signingIn(providerId: 'google');
      const b = AuthState.signingIn(providerId: 'google');
      const c = AuthState.signingIn(providerId: 'github');
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('signedIn carries only userId', () {
      const state = AuthState.signedIn(userId: 'user-123');
      expect(state, isA<SignedInState>());
      expect((state as SignedInState).userId, 'user-123');
    });

    test('authFailed carries providerId and reason', () {
      const state = AuthState.authFailed(
        providerId: 'google',
        reason: AuthFailure.cancelled,
      );
      expect(state, isA<AuthFailedState>());
      const failed = state as AuthFailedState;
      expect(failed.providerId, 'google');
      expect(failed.reason, AuthFailure.cancelled);
    });

    test('authFailed equality compares providerId and reason', () {
      const a = AuthState.authFailed(
        providerId: 'google',
        reason: AuthFailure.network,
      );
      const b = AuthState.authFailed(
        providerId: 'google',
        reason: AuthFailure.network,
      );
      const c = AuthState.authFailed(
        providerId: 'google',
        reason: AuthFailure.denied,
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });

    test('distinct variants are never equal to each other', () {
      const signedOut = AuthState.signedOut();
      const signingIn = AuthState.signingIn(providerId: 'google');
      const signedIn = AuthState.signedIn(userId: 'user-1');
      const authFailed = AuthState.authFailed(
        providerId: 'google',
        reason: AuthFailure.providerError,
      );
      final variants = [signedOut, signingIn, signedIn, authFailed];
      for (final a in variants) {
        for (final b in variants) {
          if (identical(a, b)) continue;
          expect(a, isNot(equals(b)));
        }
      }
    });
  });
}
