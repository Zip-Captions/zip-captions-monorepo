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
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_broadcast/src/output/overlay/caption_position.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';
import 'package:zip_broadcast/src/output/overlay/display_enumerator.dart';
import 'package:zip_broadcast/src/output/overlay/external_display_status.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_controller.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/overlay_window_controller_provider.dart';
import 'package:zip_broadcast/src/shell/zb_app_shell.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_display_enumerator.dart';

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

  group('external display wiring (F26)', () {
    late _ShellWorld world;

    setUp(() {
      world = _ShellWorld();
      SharedPreferences.setMockInitialValues({
        // BR-U8-21: it is never restored switched on.
        'output.overlayEnabled': false,
      });
    });

    tearDown(() async {
      await world.controller.dispose();
      world.container.dispose();
    });

    testWidgets('switching the output on registers the target and opens the '
        'window', (tester) async {
      await world.pump(tester);
      expect(world.controller.isWindowOpen, isFalse);

      await world.setOverlayEnabled(tester, enabled: true);

      expect(world.registry.activeTargets, hasLength(1));
      expect(world.window.calls, contains('createWindow'));
    });

    testWidgets('switching the output off removes the target and closes the '
        'window', (tester) async {
      await world.pump(tester);
      await world.setOverlayEnabled(tester, enabled: true);
      await world.ready(tester);

      await world.setOverlayEnabled(tester, enabled: false);

      expect(world.registry.activeTargets, isEmpty);
      expect(world.window.calls, contains('closeWindow'));
    });

    testWidgets('the launch carries the persisted position and display '
        'selection (BR-U8-07, BR-U8-26)', (tester) async {
      await world.pump(tester);
      await tester.runAsync(() async {
        final notifier =
            world.container.read(outputTargetSettingsNotifierProvider.notifier);
        await notifier.update(
          world.container
              .read(outputTargetSettingsNotifierProvider)
              .copyWith(
                externalDisplayId: 'primary',
                externalDisplayCaptionPosition: CaptionPosition.top,
              ),
        );
      });
      await tester.pumpAndSettle();

      await world.setOverlayEnabled(tester, enabled: true);

      final launch = decodeLaunch(world.window.launchArguments!);
      expect(launch, isNotNull);
      expect(launch!.config.position, isA<OverlayPositionTop>());
      // The display id is deliberately not on the wire (B-7); the selection
      // shows up as the controller opening on that display.
      expect(world.controller.status, isA<Opening>());
      expect(world.controller.selectDisplay, 'primary');
    });

    testWidgets('a recognition pause never closes the window (D-5)',
        (tester) async {
      await world.pump(tester);
      await world.setOverlayEnabled(tester, enabled: true);
      await world.ready(tester);
      world.window.calls.clear();

      await world.publish(
        tester,
        const SessionStateEvent(RecordingState.paused(sessionId: 's')),
      );

      expect(world.window.calls, isNot(contains('closeWindow')));
      expect(world.settings.overlayEnabled, isTrue);
    });
  });
}

/// The shell plus an overridden overlay graph.
class _ShellWorld {
  final _ShellWindow window = _ShellWindow();
  final FakeDisplayEnumerator enumerator = FakeDisplayEnumerator(
    initial: const [
      DisplayInfo(
        id: 'primary',
        label: 'Primary',
        bounds: Rect.fromLTWH(0, 0, 1920, 1080),
        scaleFactor: 1,
        isPrimary: true,
      ),
    ],
  );
  late final OverlayWindowController controller = OverlayWindowController(
    windowService: window,
    enumerator: enumerator,
    handlerInstaller: (next) => handler = next,
    log: Logger('test.shell'),
  );
  late final ProviderContainer container;
  OverlayMethodHandler? handler;

  CaptionOutputTargetRegistry get registry =>
      container.read(captionOutputTargetRegistryProvider);

  OutputTargetSettings get settings =>
      container.read(outputTargetSettingsNotifierProvider);

  Future<void> ready(WidgetTester tester) async {
    await tester.runAsync(() async => handler?.call('overlayReady', 1));
    await tester.pumpAndSettle();
  }

  Future<void> publish(WidgetTester tester, CaptionEvent event) async {
    await tester.runAsync(
      () async => container.read(captionBusProvider).publish(event),
    );
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pumpAndSettle();
  }

  Future<void> setOverlayEnabled(
    WidgetTester tester, {
    required bool enabled,
  }) async {
    await tester.runAsync(() async {
      final notifier =
          container.read(outputTargetSettingsNotifierProvider.notifier);
      await notifier.update(
        container
            .read(outputTargetSettingsNotifierProvider)
            .copyWith(overlayEnabled: enabled),
      );
    });
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester) async {
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        overlayWindowControllerProvider.overrideWithValue(controller),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          localizationsDelegates: const [
            ZipBroadcastLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: ZipBroadcastLocalizations.supportedLocales,
          routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              ShellRoute(
                builder: (context, state, child) => ZbAppShell(child: child),
                routes: [
                  GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }
}

/// Records window calls.
class _ShellWindow implements DesktopWindowService {
  final List<String> calls = <String>[];

  @override
  bool get isSupported => true;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    launchArguments = arguments;
    return 1;
  }

  String? launchArguments;

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async =>
      calls.add('invokeMethod:$method');

  @override
  Future<void> setFrame(int windowId, Rect frame) async =>
      calls.add('setFrame');

  @override
  Future<void> show(int windowId) async => calls.add('show');
}
