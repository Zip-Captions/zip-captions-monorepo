import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/screens/account_section.dart';
import 'package:zip_core/zip_core.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initial);

  final AuthState _initial;
  final List<String> signInCalls = [];
  int signOutCalls = 0;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signIn(String providerId) async {
    signInCalls.add(providerId);
  }

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

Widget _wrap(Widget child, {required _FakeAuthNotifier notifier}) =>
    ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => notifier),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          ZipBroadcastLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: ZipBroadcastLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('AccountSection', () {
    testWidgets('SignedOutState renders the sign-in card', (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState.signedOut());
      await tester.pumpWidget(
        _wrap(const AccountSection(), notifier: notifier),
      );

      expect(find.byKey(const Key('sign-in-signed-out-card')), findsOneWidget);
      expect(
        find.byKey(const Key('sign-in-provider-google-button')),
        findsOneWidget,
      );
      expect(find.text('Sign in to broadcast'), findsOneWidget);
    });

    testWidgets('SigningInState shows a spinner on the active button',
        (tester) async {
      final notifier = _FakeAuthNotifier(
        const AuthState.signingIn(providerId: 'google'),
      );
      await tester.pumpWidget(
        _wrap(const AccountSection(), notifier: notifier),
      );

      final button = tester.widget<OutlinedButton>(
        find.byKey(const Key('sign-in-provider-google-button')),
      );
      expect(button.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('SignedInState renders the account card', (tester) async {
      final notifier = _FakeAuthNotifier(
        const AuthState.signedIn(userId: 'user-1'),
      );
      await tester.pumpWidget(
        _wrap(const AccountSection(), notifier: notifier),
      );

      expect(find.byKey(const Key('sign-in-signed-in-card')), findsOneWidget);
      expect(
        find.byKey(const Key('sign-in-signed-in-status')),
        findsOneWidget,
      );
      expect(find.text('user-1'), findsOneWidget);
    });

    testWidgets('AuthFailedState renders the failure alert', (tester) async {
      final notifier = _FakeAuthNotifier(
        const AuthState.authFailed(
          providerId: 'google',
          reason: AuthFailure.cancelled,
        ),
      );
      await tester.pumpWidget(
        _wrap(const AccountSection(), notifier: notifier),
      );

      expect(
        find.byKey(const Key('sign-in-auth-failure-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('sign-in-auth-failure-alert')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('sign-in-retry-button')), findsOneWidget);
    });

    testWidgets('tapping the Google button calls signIn(google)',
        (tester) async {
      final notifier = _FakeAuthNotifier(const AuthState.signedOut());
      await tester.pumpWidget(
        _wrap(const AccountSection(), notifier: notifier),
      );

      await tester.tap(find.byKey(const Key('sign-in-provider-google-button')));
      await tester.pump();

      expect(notifier.signInCalls, ['google']);
    });

    testWidgets('tapping sign-out calls signOut()', (tester) async {
      final notifier = _FakeAuthNotifier(
        const AuthState.signedIn(userId: 'user-1'),
      );
      await tester.pumpWidget(
        _wrap(const AccountSection(), notifier: notifier),
      );

      await tester.tap(find.byKey(const Key('sign-in-sign-out-button')));
      await tester.pump();

      expect(notifier.signOutCalls, 1);
    });

    testWidgets(
        "tapping retry calls signIn with the failed state's providerId",
        (tester) async {
      final notifier = _FakeAuthNotifier(
        const AuthState.authFailed(
          providerId: 'google',
          reason: AuthFailure.network,
        ),
      );
      await tester.pumpWidget(
        _wrap(const AccountSection(), notifier: notifier),
      );

      await tester.tap(find.byKey(const Key('sign-in-retry-button')));
      await tester.pump();

      expect(notifier.signInCalls, ['google']);
    });
  });
}
