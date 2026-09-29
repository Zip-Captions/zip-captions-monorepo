import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/auth_failure.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/providers/auth_notifier.dart';
import 'package:zip_core/src/providers/auth_service_provider.dart';

import '../helpers/fake_auth_service.dart';

void main() {
  group('AuthNotifier', () {
    test('F-BA-2: build reads currentUserId synchronously — signedOut',
        () {
      final fake = FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);

      expect(
        container.read(authNotifierProvider),
        isA<SignedOutState>(),
      );
    });

    test('F-BA-2: build reads currentUserId synchronously — signedIn', () {
      final fake = FakeAuthService(
        initialState: const AuthState.signedIn(userId: 'user-1'),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);

      final state = container.read(authNotifierProvider);
      expect(state, isA<SignedInState>());
      expect((state as SignedInState).userId, 'user-1');
    });

    test('F-BA-1: signIn delegates to AuthService with the given providerId',
        () async {
      final fake = FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);
      container.read(authNotifierProvider); // build the notifier

      await container.read(authNotifierProvider.notifier).signIn('google');

      expect(fake.signInCalls, ['google']);
    });

    test(
        'republishes AuthService.authStateChanges into AuthNotifier state',
        () async {
      final fake = FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);
      container.read(authNotifierProvider); // build the notifier

      fake.emit(const AuthState.signingIn(providerId: 'google'));
      await pumpEventQueue();
      expect(
        container.read(authNotifierProvider),
        isA<SigningInState>(),
      );

      fake.emit(const AuthState.signedIn(userId: 'user-1'));
      await pumpEventQueue();
      final state = container.read(authNotifierProvider);
      expect(state, isA<SignedInState>());
      expect((state as SignedInState).userId, 'user-1');
    });

    test(
        'F-BA-6: a failure from AuthService republishes as AuthFailedState',
        () async {
      final fake = FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);
      container.read(authNotifierProvider);

      fake.emit(
        const AuthState.authFailed(
          providerId: 'google',
          reason: AuthFailure.cancelled,
        ),
      );
      await pumpEventQueue();

      final state = container.read(authNotifierProvider);
      expect(state, isA<AuthFailedState>());
      expect((state as AuthFailedState).reason, AuthFailure.cancelled);
    });

    test(
        'F-BA-7 / Rule 3: a passive signedOut event republishes as '
        'SignedOutState, not AuthFailedState', () async {
      final fake = FakeAuthService(
        initialState: const AuthState.signedIn(userId: 'user-1'),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);
      container.read(authNotifierProvider);

      fake.emit(const AuthState.signedOut());
      await pumpEventQueue();

      expect(container.read(authNotifierProvider), isA<SignedOutState>());
    });

    test('Rule 1: signIn is a no-op while already signingIn', () async {
      // SigningIn is never a restored/initial state (F-BA-2) — it must be
      // reached via a real transition first, the same way production code
      // would arrive at it.
      final fake = FakeAuthService();
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);
      container.read(authNotifierProvider);

      fake.emit(const AuthState.signingIn(providerId: 'google'));
      await pumpEventQueue();
      expect(container.read(authNotifierProvider), isA<SigningInState>());

      await container.read(authNotifierProvider.notifier).signIn('google');

      expect(fake.signInCalls, isEmpty);
    });

    test('Rule 8 (via AuthService): signOut delegates through', () async {
      final fake = FakeAuthService(
        initialState: const AuthState.signedIn(userId: 'user-1'),
      );
      final container = ProviderContainer(
        overrides: [authServiceProvider.overrideWithValue(fake)],
      );
      addTearDown(container.dispose);
      addTearDown(fake.dispose);
      container.read(authNotifierProvider);

      await container.read(authNotifierProvider.notifier).signOut();

      expect(fake.signOutCallCount, 1);
    });
  });
}
