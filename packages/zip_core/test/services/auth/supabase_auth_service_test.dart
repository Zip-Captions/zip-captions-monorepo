import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:zip_core/src/models/auth_failure.dart';
import 'package:zip_core/src/models/auth_provider_option.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/services/auth/supabase_auth_service.dart';

class _MockSupabaseClient extends Mock implements sb.SupabaseClient {}

class _MockGoTrueClient extends Mock implements sb.GoTrueClient {}

class _MockAppLinks extends Mock implements AppLinks {}

sb.User _testUser(String id) => sb.User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime(2026).toIso8601String(),
    );

sb.Session _testSession(String userId) => sb.Session(
      accessToken: 'test-access-token',
      tokenType: 'bearer',
      user: _testUser(userId),
    );

const _config = AuthProviderConfig(
  providers: [
    AuthProviderOption(
      id: 'google',
      displayLabel: 'Google',
      provider: sb.OAuthProvider.google,
    ),
  ],
);

void main() {
  late _MockSupabaseClient client;
  late _MockGoTrueClient gotrue;
  late _MockAppLinks appLinks;
  late StreamController<sb.AuthState> authChanges;
  late StreamController<Uri> incomingLinks;

  setUpAll(() {
    registerFallbackValue(sb.OAuthProvider.google);
    registerFallbackValue(sb.SignOutScope.global);
  });

  setUp(() {
    client = _MockSupabaseClient();
    gotrue = _MockGoTrueClient();
    appLinks = _MockAppLinks();
    authChanges = StreamController<sb.AuthState>.broadcast();
    incomingLinks = StreamController<Uri>.broadcast();
    when(() => client.auth).thenReturn(gotrue);
    when(() => gotrue.currentUser).thenReturn(null);
    when(() => gotrue.onAuthStateChange)
        .thenAnswer((_) => authChanges.stream);
    when(() => appLinks.uriLinkStream)
        .thenAnswer((_) => incomingLinks.stream);
  });

  tearDown(() async {
    await authChanges.close();
    await incomingLinks.close();
  });

  SupabaseAuthService buildService() => SupabaseAuthService(
        client: client,
        providerConfig: _config,
        appLinks: appLinks,
      );

  // `signInWithOAuth` is an extension method (GoTrueClientSignInProvider) —
  // it cannot be stubbed directly on a mock, since extension methods are
  // statically dispatched, not virtual. It delegates to the real instance
  // method `getOAuthSignInUrl` to obtain the URL, then launches it via
  // url_launcher (not mockable here at all). Our production code never
  // inspects `signInWithOAuth`'s own return value or awaits past the
  // point where the browser opens, so stubbing `getOAuthSignInUrl` to
  // never complete keeps every test below in the same "attempt is in
  // flight, browser never actually opens in this test" state real
  // abandonment/timeout scenarios are in anyway — without ever reaching
  // the unmockable url_launcher call.
  void stubOAuthUrlNeverCompletes() {
    when(
      () => gotrue.getOAuthSignInUrl(
        provider: any(named: 'provider'),
        redirectTo: any(named: 'redirectTo'),
      ),
    ).thenAnswer((_) => Completer<sb.OAuthResponse>().future);
  }

  void stubOAuthUrlThrows(Object error) {
    when(
      () => gotrue.getOAuthSignInUrl(
        provider: any(named: 'provider'),
        redirectTo: any(named: 'redirectTo'),
      ),
    ).thenThrow(error);
  }

  group('SupabaseAuthService — session restore (F-BA-2)', () {
    test('starts signedOut when no current session', () async {
      final service = buildService();
      expect(await service.authStateChanges.first, isA<SignedOutState>());
      service.dispose();
    });

    test('starts signedIn when a session is already present', () async {
      when(() => gotrue.currentUser).thenReturn(_testUser('user-1'));
      final service = buildService();
      final state = await service.authStateChanges.first;
      expect(state, isA<SignedInState>());
      expect((state as SignedInState).userId, 'user-1');
      service.dispose();
    });
  });

  group('SupabaseAuthService — signIn (F-BA-1)', () {
    test('reaches the SDK with the resolved provider', () async {
      stubOAuthUrlNeverCompletes();

      final service = buildService();
      unawaited(service.signIn('google'));
      await pumpEventQueue();

      verify(
        () => gotrue.getOAuthSignInUrl(
          provider: sb.OAuthProvider.google,
          redirectTo: any(named: 'redirectTo'),
        ),
      ).called(1);
      service.dispose();
    });

    test('unknown providerId throws ArgumentError, no SDK call', () async {
      final service = buildService();
      await expectLater(
        () => service.signIn('not-configured'),
        throwsArgumentError,
      );
      verifyNever(
        () => gotrue.getOAuthSignInUrl(
          provider: any(named: 'provider'),
          redirectTo: any(named: 'redirectTo'),
        ),
      );
      service.dispose();
    });

    test(
        'Rule 1: a second signIn while already signingIn is a no-op',
        () async {
      stubOAuthUrlNeverCompletes();

      final service = buildService();
      unawaited(service.signIn('google'));
      await service.signIn('google');

      verify(
        () => gotrue.getOAuthSignInUrl(
          provider: any(named: 'provider'),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).called(1);
      service.dispose();
    });
  });

  group('SupabaseAuthService — failure mapping (SR-01 §7, Rule 9)', () {
    test('AuthRetryableFetchException maps to network', () async {
      stubOAuthUrlThrows(sb.AuthRetryableFetchException(message: 'offline'));

      final service = buildService();
      final failedState = service.authStateChanges
          .firstWhere((s) => s is AuthFailedState);
      await service.signIn('google');
      final failed = await failedState as AuthFailedState;

      expect(failed.reason, AuthFailure.network);
      expect(failed.providerId, 'google');
      service.dispose();
    });

    test('AuthException maps to denied', () async {
      stubOAuthUrlThrows(const sb.AuthException('provider disabled'));

      final service = buildService();
      final failedState = service.authStateChanges
          .firstWhere((s) => s is AuthFailedState);
      await service.signIn('google');
      final failed = await failedState as AuthFailedState;

      expect(failed.reason, AuthFailure.denied);
      service.dispose();
    });

    test('any other exception maps to providerError', () async {
      stubOAuthUrlThrows(StateError('unexpected'));

      final service = buildService();
      final failedState = service.authStateChanges
          .firstWhere((s) => s is AuthFailedState);
      await service.signIn('google');
      final failed = await failedState as AuthFailedState;

      expect(failed.reason, AuthFailure.providerError);
      service.dispose();
    });

    test(
        'Rule 4/9: the exception message is never logged, only its type',
        () async {
      stubOAuthUrlThrows(StateError('secret-token-shaped-message'));

      final records = <LogRecord>[];
      final sub = Logger.root.onRecord.listen(records.add);
      final service = buildService();
      await service.signIn('google');
      await sub.cancel();

      for (final record in records) {
        expect(record.message, isNot(contains('secret-token-shaped-message')));
      }
      service.dispose();
    });
  });

  group('SupabaseAuthService — desktop callback URI (SR-01 §3, Rule 9)', () {
    test('error=access_denied on the callback URI maps to cancelled',
        () async {
      stubOAuthUrlNeverCompletes();
      final service = buildService();
      final failedState = service.authStateChanges
          .firstWhere((s) => s is AuthFailedState)
          .timeout(const Duration(seconds: 1));

      unawaited(service.signIn('google'));
      await pumpEventQueue();
      incomingLinks.add(
        Uri.parse('io.zipcaptions.broadcast://login-callback?error=access_denied'),
      );
      final failed = await failedState as AuthFailedState;

      expect(failed.reason, AuthFailure.cancelled);
      service.dispose();
    });

    test(
        'any other callback error (e.g. server_error) maps to '
        'providerError, never denied', () async {
      stubOAuthUrlNeverCompletes();
      final service = buildService();
      final failedState = service.authStateChanges
          .firstWhere((s) => s is AuthFailedState)
          .timeout(const Duration(seconds: 1));

      unawaited(service.signIn('google'));
      await pumpEventQueue();
      incomingLinks.add(
        Uri.parse('io.zipcaptions.broadcast://login-callback?error=server_error'),
      );
      final failed = await failedState as AuthFailedState;

      expect(failed.reason, AuthFailure.providerError);
      service.dispose();
    });

    test('a callback URI with no error param is ignored (success path left '
        'to the SDK)', () async {
      stubOAuthUrlNeverCompletes();
      final service = buildService();
      final states = <AuthState>[];
      service.authStateChanges.listen(states.add);

      unawaited(service.signIn('google'));
      await pumpEventQueue();
      incomingLinks.add(
        Uri.parse('io.zipcaptions.broadcast://login-callback?code=abc123'),
      );
      await pumpEventQueue();

      expect(states.whereType<AuthFailedState>(), isEmpty);
      service.dispose();
    });
  });

  group('SupabaseAuthService — passive session loss (Rule 3, F-BA-7)', () {
    test('a signedOut event with sessionExpired reason maps to signedOut, '
        'not authFailed', () async {
      final service = buildService();
      final states = service.authStateChanges.skip(1).take(1).toList();

      authChanges.add(
        const sb.AuthState(
          sb.AuthChangeEvent.signedOut,
          null,
          signOutReason: sb.SignOutReason.sessionExpired,
        ),
      );

      final result = await states;
      expect(result.single, isA<SignedOutState>());
      service.dispose();
    });

    test('a signedOut event with userInitiated reason also maps to '
        'signedOut (same handling regardless of reason)', () async {
      final service = buildService();
      final states = service.authStateChanges.skip(1).take(1).toList();

      authChanges.add(
        const sb.AuthState(
          sb.AuthChangeEvent.signedOut,
          null,
          signOutReason: sb.SignOutReason.userInitiated,
        ),
      );

      final result = await states;
      expect(result.single, isA<SignedOutState>());
      service.dispose();
    });
  });

  group('SupabaseAuthService — signedIn event (F-BA-1)', () {
    test('a signedIn event with a session publishes SignedInState', () async {
      final service = buildService();
      final states = service.authStateChanges.skip(1).take(1).toList();

      authChanges.add(
        sb.AuthState(sb.AuthChangeEvent.signedIn, _testSession('user-42')),
      );

      final result = await states;
      final signedIn = result.single as SignedInState;
      expect(signedIn.userId, 'user-42');
      service.dispose();
    });
  });

  group('SupabaseAuthService — signOut (Rule 2, Rule 8)', () {
    test('signs out locally first, then calls the SDK with global scope',
        () async {
      when(() => gotrue.signOut(scope: any(named: 'scope')))
          .thenAnswer((_) async {});

      final service = buildService();
      authChanges.add(
        sb.AuthState(sb.AuthChangeEvent.signedIn, _testSession('user-1')),
      );
      await pumpEventQueue();

      await service.signOut();

      verify(() => gotrue.signOut(scope: sb.SignOutScope.global)).called(1);
      service.dispose();
    });

    test('Rule 8: signOut while already signed out is a no-op', () async {
      final service = buildService();
      await service.signOut();

      verifyNever(() => gotrue.signOut(scope: any(named: 'scope')));
      service.dispose();
    });

    test('Rule 2: a failed server-side revoke does not revert local '
        'signedOut state', () async {
      when(() => gotrue.signOut(scope: any(named: 'scope')))
          .thenThrow(sb.AuthRetryableFetchException(message: 'down'));

      final service = buildService();
      authChanges.add(
        sb.AuthState(sb.AuthChangeEvent.signedIn, _testSession('user-1')),
      );
      await pumpEventQueue();

      await service.signOut();
      await pumpEventQueue();

      expect(await service.authStateChanges.first, isA<SignedOutState>());
      service.dispose();
    });
  });

  group('SupabaseAuthService — abandoned sign-in (NFR Design Q1)', () {
    test('hard timeout resolves an unanswered attempt to cancelled', () {
      fakeAsync((async) {
        stubOAuthUrlNeverCompletes();

        final service = buildService();
        AuthState? last;
        service.authStateChanges.listen((s) => last = s);

        unawaited(service.signIn('google'));
        async.elapse(SupabaseAuthService.hardTimeout);

        expect(last, isA<AuthFailedState>());
        expect((last! as AuthFailedState).reason, AuthFailure.cancelled);
        service.dispose();
      });
    });

    test('a real outcome cancels the pending hard timeout', () {
      fakeAsync((async) {
        stubOAuthUrlNeverCompletes();

        final service = buildService();
        final seen = <AuthState>[];
        service.authStateChanges.listen(seen.add);

        unawaited(service.signIn('google'));
        authChanges.add(
          sb.AuthState(sb.AuthChangeEvent.signedIn, _testSession('user-1')),
        );
        // Advance past the hard timeout — it must not fire a second,
        // stale authFailed after the attempt already resolved.
        async
          ..flushMicrotasks()
          ..elapse(SupabaseAuthService.hardTimeout);

        expect(seen.whereType<AuthFailedState>(), isEmpty);
        service.dispose();
      });
    });
  });

  testWidgets(
    'resume grace window resolves an unanswered attempt after resume '
    '(NFR Design Q1)',
    (tester) async {
      stubOAuthUrlNeverCompletes();

      final service = buildService();
      AuthState? last;
      service.authStateChanges.listen((s) => last = s);

      unawaited(service.signIn('google'));
      tester.binding
          .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(SupabaseAuthService.resumeGrace);
      await tester.pump();

      expect(last, isA<AuthFailedState>());
      expect((last! as AuthFailedState).reason, AuthFailure.cancelled);
      service.dispose();
    },
  );
}
