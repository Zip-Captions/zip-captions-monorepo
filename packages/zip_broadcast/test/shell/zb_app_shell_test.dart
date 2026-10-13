// Tests for `ZbAppShell`'s Rule 9 sign-out guard (Functional Design Q6,
// `business-rules.md` Rule 9): `ZbSignOutScope.of(context)` refuses
// outright — never calls `authNotifierProvider.notifier.signOut()` — while
// `BroadcasterSessionState` is non-idle, and the state read/act happen in
// the same synchronous span (NFR Design Q2).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/shell/zb_app_shell.dart';
import 'package:zip_core/zip_core.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initial);
  final AuthState _initial;
  int signOutCalls = 0;

  @override
  AuthState build() => _initial;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

class _FakeBroadcastSessionNotifier extends BroadcastSessionNotifier {
  _FakeBroadcastSessionNotifier(this._initial);
  final BroadcasterSessionState _initial;

  @override
  BroadcasterSessionState build() => _initial;

  // Named as a method, matching this project's established
  // `_FakeAuthNotifier.setState` precedent, not a setter.
  // ignore: use_setters_to_change_properties
  void setState(BroadcasterSessionState next) => state = next;
}

class _SignOutTrigger extends StatelessWidget {
  const _SignOutTrigger();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ElevatedButton(
          key: const Key('test-sign-out-trigger'),
          onPressed: () => unawaited(ZbSignOutScope.of(context)),
          child: const Text('Sign out'),
        ),
      ),
    );
  }
}

Future<void> _pumpHarness(
  WidgetTester tester, {
  required _FakeAuthNotifier authNotifier,
  required _FakeBroadcastSessionNotifier sessionNotifier,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => ZbAppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const _SignOutTrigger()),
        ],
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith(() => authNotifier),
        broadcastSessionNotifierProvider.overrideWith(
          () => sessionNotifier,
        ),
      ],
      child: MaterialApp.router(
        theme: ThemeData(splashFactory: InkRipple.splashFactory),
        localizationsDelegates: const [
          ZipBroadcastLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: ZipBroadcastLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ZbSignOutScope.of (Rule 9)', () {
    testWidgets('calls signOut() from OfflineState', (tester) async {
      final authNotifier = _FakeAuthNotifier(
        const AuthState.signedIn(userId: 'u1'),
      );
      final sessionNotifier = _FakeBroadcastSessionNotifier(
        const BroadcasterSessionState.offline(),
      );
      await _pumpHarness(
        tester,
        authNotifier: authNotifier,
        sessionNotifier: sessionNotifier,
      );

      await tester.tap(find.byKey(const Key('test-sign-out-trigger')));
      await tester.pumpAndSettle();

      expect(authNotifier.signOutCalls, 1);
    });

    testWidgets('calls signOut() from BroadcastFailedState', (tester) async {
      final authNotifier = _FakeAuthNotifier(
        const AuthState.signedIn(userId: 'u1'),
      );
      final sessionNotifier = _FakeBroadcastSessionNotifier(
        const BroadcasterSessionState.failed(BroadcastFailure.signedOut),
      );
      await _pumpHarness(
        tester,
        authNotifier: authNotifier,
        sessionNotifier: sessionNotifier,
      );

      await tester.tap(find.byKey(const Key('test-sign-out-trigger')));
      await tester.pumpAndSettle();

      expect(authNotifier.signOutCalls, 1);
    });

    for (final blockingState in [
      const BroadcasterSessionState.starting(),
      const BroadcasterSessionState.ending(),
    ]) {
      testWidgets(
        'refuses and shows feedback from $blockingState',
        (tester) async {
          final authNotifier = _FakeAuthNotifier(
            const AuthState.signedIn(userId: 'u1'),
          );
          final sessionNotifier = _FakeBroadcastSessionNotifier(
            blockingState,
          );
          await _pumpHarness(
            tester,
            authNotifier: authNotifier,
            sessionNotifier: sessionNotifier,
          );

          await tester.tap(find.byKey(const Key('test-sign-out-trigger')));
          await tester.pumpAndSettle();

          expect(authNotifier.signOutCalls, 0);
          expect(
            find.text('End the live broadcast before signing out'),
            findsOneWidget,
          );
        },
      );
    }

    testWidgets('refuses while LiveState', (tester) async {
      final authNotifier = _FakeAuthNotifier(
        const AuthState.signedIn(userId: 'u1'),
      );
      final sessionNotifier = _FakeBroadcastSessionNotifier(
        BroadcasterSessionState.live(
          LiveBroadcast(
            broadcastId: BroadcastId.parse('K7M9X2'),
            url: BroadcastLink.toUrl(BroadcastId.parse('K7M9X2')),
            sessionId: 's1',
            sessionName: 'My Stream',
            captionActivity: CaptionActivity.active,
            viewers: const [],
            maxViewers: 50,
            startedAt: DateTime.utc(2026),
          ),
        ),
      );
      await _pumpHarness(
        tester,
        authNotifier: authNotifier,
        sessionNotifier: sessionNotifier,
      );

      await tester.tap(find.byKey(const Key('test-sign-out-trigger')));
      await tester.pumpAndSettle();

      expect(authNotifier.signOutCalls, 0);
      expect(
        find.text('End the live broadcast before signing out'),
        findsOneWidget,
      );
    });
  });
}
