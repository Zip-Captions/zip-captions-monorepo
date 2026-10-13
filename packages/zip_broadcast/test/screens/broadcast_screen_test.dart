// Widget tests for `BroadcastScreen` (Unit 6, S-17) — one widget test per
// approved Proto-11/Proto-12 state reachable via `ProviderScope` overrides
// (NFR Requirements Q2). No golden-image tests (this project has none
// today).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/screens/broadcast_screen.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_notifiers.dart';

class _FakeAuthNotifier extends AuthNotifier {
  _FakeAuthNotifier(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

class _FakeBroadcastSessionNotifier extends BroadcastSessionNotifier {
  _FakeBroadcastSessionNotifier(this._initial);
  final BroadcasterSessionState _initial;

  @override
  BroadcasterSessionState build() => _initial;

  @override
  Future<void> goLive() async {}

  @override
  Future<void> endBroadcast() async {}
}

class _FakeBroadcastSettingsNotifier extends BroadcastSettingsNotifier {
  _FakeBroadcastSettingsNotifier(this._initial);
  final BroadcastSettings _initial;

  @override
  BroadcastSettings build() => _initial;

  @override
  Future<void> updateSessionName(String sessionName) async {
    state = state.copyWith(sessionName: sessionName);
  }

  @override
  Future<void> setAutoStartCaptioning({
    required bool autoStartCaptioning,
  }) async {
    state = state.copyWith(autoStartCaptioning: autoStartCaptioning);
  }
}

class _FakeBroadcastIdentityRepository implements BroadcastIdentityRepository {
  @override
  Future<BroadcastId> getOrCreateMine() async => BroadcastId.parse('K7M9X2');
}

final _liveBroadcast = LiveBroadcast(
  broadcastId: BroadcastId.parse('K7M9X2'),
  url: BroadcastLink.toUrl(BroadcastId.parse('K7M9X2')),
  sessionId: 's1',
  sessionName: 'My Stream',
  captionActivity: CaptionActivity.active,
  viewers: const [],
  maxViewers: 50,
  startedAt: DateTime.utc(2026),
);

Future<void> _pump(
  WidgetTester tester, {
  required BroadcasterSessionState sessionState,
  AuthState authState = const AuthState.signedIn(userId: 'u1'),
  BroadcastSettings settings = const BroadcastSettings(
    sessionName: 'My Stream',
  ),
}) async {
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        authNotifierProvider.overrideWith(() => _FakeAuthNotifier(authState)),
        broadcastSessionNotifierProvider.overrideWith(
          () => _FakeBroadcastSessionNotifier(sessionState),
        ),
        broadcastSettingsNotifierProvider.overrideWith(
          () => _FakeBroadcastSettingsNotifier(settings),
        ),
        broadcastIdentityRepositoryProvider.overrideWithValue(
          _FakeBroadcastIdentityRepository(),
        ),
        audioInputConfigNotifierProvider.overrideWith(
          FakeEmptyAudioInputConfigNotifier.new,
        ),
        broadcastRecordingNotifierProvider.overrideWith(
          FakeIdleBroadcastRecordingNotifier.new,
        ),
      ],
      // `supportedLocales` is a non-const getter, so `MaterialApp` itself
      // can't be a const constructor call here.
      // ignore: prefer_const_constructors
      child: MaterialApp(
        localizationsDelegates: const [
          ZipBroadcastLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: ZipBroadcastLocalizations.supportedLocales,
        home: const BroadcastScreen(),
      ),
    ),
  );
  // Not `pumpAndSettle`: `StartingState`'s `CircularProgressIndicator`
  // animates indefinitely, so settling would never complete.
  await tester.pump();
  await tester.pump();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Setup view (F-6.1)', () {
    testWidgets('signed-out overlay covers the form', (tester) async {
      await _pump(
        tester,
        sessionState: const BroadcasterSessionState.offline(),
        authState: const AuthState.signedOut(),
      );

      expect(
        find.byKey(const Key('broadcast-signed-out-overlay')),
        findsOneWidget,
      );
      final goLiveButton = tester.widget<FilledButton>(
        find.byKey(const Key('broadcast-go-live-button')),
      );
      expect(goLiveButton.onPressed, isNull);
    });

    testWidgets('empty session name shows the empty error', (tester) async {
      await _pump(
        tester,
        sessionState: const BroadcasterSessionState.offline(),
        settings: const BroadcastSettings(),
      );

      expect(find.text('Session name is required'), findsOneWidget);
    });

    testWidgets('a too-long session name shows the tooLong error', (
      tester,
    ) async {
      await _pump(
        tester,
        sessionState: const BroadcasterSessionState.offline(),
        settings: BroadcastSettings(
          sessionName: 'a' * (broadcastSessionNameMaxLength + 1),
        ),
      );

      expect(find.text('Session name is too long'), findsOneWidget);
    });

    testWidgets(
      'a session name with a control character shows the controlChar error',
      (tester) async {
        await _pump(
          tester,
          sessionState: const BroadcasterSessionState.offline(),
          settings: const BroadcastSettings(sessionName: 'hello\x00world'),
        );

        expect(
          find.text('Session name contains an invalid character'),
          findsOneWidget,
        );
      },
    );

    testWidgets('a valid session name shows no error and enables Go Live', (
      tester,
    ) async {
      await _pump(
        tester,
        sessionState: const BroadcasterSessionState.offline(),
      );

      final goLiveButton = tester.widget<FilledButton>(
        find.byKey(const Key('broadcast-go-live-button')),
      );
      expect(goLiveButton.onPressed, isNotNull);
    });

    testWidgets('StartingState renders the Go Live progress spinner', (
      tester,
    ) async {
      await _pump(
        tester,
        sessionState: const BroadcasterSessionState.starting(),
      );

      expect(find.text('Going live…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final goLiveButton = tester.widget<FilledButton>(
        find.byKey(const Key('broadcast-go-live-button')),
      );
      expect(goLiveButton.onPressed, isNull);
    });

    testWidgets(
      'BroadcastFailedState renders the failure card and allows retry',
      (tester) async {
        await _pump(
          tester,
          sessionState: const BroadcasterSessionState.failed(
            BroadcastFailure.signalingUnavailable,
          ),
        );

        expect(find.byKey(const Key('broadcast-failure-card')), findsOneWidget);
        expect(find.text("Couldn't go live"), findsOneWidget);
        final goLiveButton = tester.widget<FilledButton>(
          find.byKey(const Key('broadcast-go-live-button')),
        );
        expect(goLiveButton.onPressed, isNotNull);
      },
    );
  });

  group('Live dashboard (F-6.4, F-6.5)', () {
    testWidgets('active captioning hides the banner', (tester) async {
      await _pump(
        tester,
        sessionState: BroadcasterSessionState.live(_liveBroadcast),
      );

      expect(find.byKey(const Key('broadcast-captions-banner')), findsNothing);
    });

    testWidgets(
      'inactive, never started shows the never-started banner copy',
      (tester) async {
        await _pump(
          tester,
          sessionState: BroadcasterSessionState.live(
            _liveBroadcast.copyWith(captionActivity: CaptionActivity.inactive),
          ),
        );

        expect(
          find.byKey(const Key('broadcast-captions-banner')),
          findsOneWidget,
        );
        expect(
          find.textContaining("hasn't started yet"),
          findsOneWidget,
        );
      },
    );

    testWidgets('paused shows the not-running banner copy', (tester) async {
      await _pump(
        tester,
        sessionState: BroadcasterSessionState.live(
          _liveBroadcast.copyWith(captionActivity: CaptionActivity.paused),
        ),
      );

      expect(
        find.byKey(const Key('broadcast-captions-banner')),
        findsOneWidget,
      );
      expect(find.textContaining('are not running'), findsOneWidget);
    });

    testWidgets('a full broadcast shows the full banner', (tester) async {
      await _pump(
        tester,
        sessionState: BroadcasterSessionState.live(
          _liveBroadcast.copyWith(
            maxViewers: 1,
            viewers: [
              ViewerConnectionInfo(
                peerId: 'viewer-1',
                connectionType: ConnectionType.p2pDirect,
                connectedAt: DateTime.utc(2026),
              ),
            ],
          ),
        ),
      );

      expect(find.byKey(const Key('broadcast-full-banner')), findsOneWidget);
    });

    testWidgets('renders every connected viewer', (tester) async {
      await _pump(
        tester,
        sessionState: BroadcasterSessionState.live(
          _liveBroadcast.copyWith(
            viewers: [
              ViewerConnectionInfo(
                peerId: 'viewer-1',
                connectionType: ConnectionType.p2pDirect,
                connectedAt: DateTime.utc(2026),
              ),
              ViewerConnectionInfo(
                peerId: 'viewer-2',
                connectionType: ConnectionType.p2pDirect,
                connectedAt: DateTime.utc(2026),
              ),
            ],
          ),
        ),
      );

      expect(
        find.byKey(const Key('broadcast-viewer-viewer-1')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('broadcast-viewer-viewer-2')),
        findsOneWidget,
      );
    });

    testWidgets('End Broadcast button is present', (tester) async {
      await _pump(
        tester,
        sessionState: BroadcasterSessionState.live(_liveBroadcast),
      );

      expect(find.byKey(const Key('broadcast-end-button')), findsOneWidget);
    });
  });
}
