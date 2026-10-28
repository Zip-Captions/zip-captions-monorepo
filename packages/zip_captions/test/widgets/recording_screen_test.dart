import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/language_pack_providers.dart';
import 'package:zip_captions/src/screens/recording_screen.dart';
import 'package:zip_captions/src/widgets/recording_controls_bar.dart';
import 'package:zip_captions/src/widgets/speech_explainer_gate.dart';
import 'package:zip_captions/src/widgets/start_failure_view.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_language_pack_service.dart';
import '../helpers/fake_recording_state_notifier.dart';
// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Minimal router with the routes that RecordingScreen can navigate to.
GoRouter _router({TargetPlatform platform = TargetPlatform.android}) =>
    GoRouter(
      initialLocation: '/recording',
      routes: [
        GoRoute(
          path: '/',
          builder: (ctx, s) => const SizedBox(key: Key('home-screen')),
        ),
        GoRoute(
          path: '/recording',
          builder: (ctx, s) => RecordingScreen(platform: platform),
        ),
        GoRoute(
          path: '/history',
          // A Scaffold (as HistoryScreen really has) so the ScaffoldMessenger
          // keeps a host for the queued SnackBar after navigation, and no
          // transition so the recording Scaffold is unmounted in one frame
          // (a mid-transition double-host would show every SnackBar twice).
          pageBuilder: (ctx, s) => const NoTransitionPage(
            child: Scaffold(
              body: SizedBox(key: Key('history-screen')),
            ),
          ),
        ),
        GoRoute(path: '/settings', builder: (ctx, s) => const SizedBox()),
      ],
    );

/// The strings the screen renders, substituted so a test can tell an ARB
/// value from an inline literal.
const _testStrings = ZcStrings.fromMap({
  'onDeviceUnavailableTitle': 'od-title',
  'onDeviceUnavailableBody': 'od-body',
  'failureMicDeniedTitle': 'md-title',
  'failureMicDeniedBody': 'md-body',
  'failureMicPermanentlyDeniedTitle': 'mpd-title',
  'failureMicPermanentlyDeniedBody': 'mpd-body',
  'failureEngineInitFailedTitle': 'eif-title',
  'failureEngineInitFailedBody': 'eif-body',
  'failureEngineStartFailedTitle': 'esf-title',
  'failureEngineStartFailedBody': 'esf-body',
  'failureOtherTitle': 'other-title',
  'failureOtherBody': 'other-body',
  'failureTryAgain': 'try-again-label',
  'failureOpenSettings': 'open-settings-label',
  'failureBack': 'back-label',
  'speechExplainerTitle': 'explainer-title',
  'speechExplainerBody': 'explainer-body',
  'speechExplainerContinue': 'explainer-continue',
  'speechExplainerNotNow': 'explainer-not-now',
  'noTranscriptSavedNotice': 'no-transcript',
  'inactivityStopNotice': 'inactive-stop {minutes} minutes',
  'languagePackDownload': 'dl-label {language}',
  'languagePackDownloadingPercent': 'dling-pct {language} {percent}',
  'languagePackDownloading': 'dling {language}',
  'languagePackScheduled': 'scheduled {language}',
  'languagePackReady': 'ready {language}',
  'languagePackFailed': 'failed {language}',
  'languagePackIosInstructions': 'ios-steps {language}',
});

/// A [TranscriptSaveOutcome] with a fixed value (Q-2).
class _FixedOutcome extends TranscriptSaveOutcome {
  _FixedOutcome({required bool? value}) : _value = value;

  final bool? _value;

  @override
  bool? build() => _value;
}

/// A [TranscriptSaveOutcome] a test can drive, logging every change.
class _WritableOutcome extends TranscriptSaveOutcome {
  /// The value the writer would write, or `null` for no outcome.
  bool? value;

  /// Every value the screen read, in order.
  final reads = <bool?>[];

  /// Every write or clear, in order.
  final mutations = <String>[];

  @override
  bool? build() => null;

  @override
  bool? get saved {
    reads.add(value);
    return value;
  }

  @override
  set saved(bool v) => record(v);

  @override
  void record(bool? v) {
    mutations.add('record=$v');
    value = v;
    state = v;
  }
}

/// A [TranscriptSettingsNotifier] pinned to one capture setting.
class _PinnedCaptureSettings extends TranscriptSettingsNotifier {
  _PinnedCaptureSettings({required bool enabled}) : _enabled = enabled;

  final bool _enabled;

  @override
  TranscriptSettings build() => TranscriptSettings(captureEnabled: _enabled);
}

Future<void> _pump(
  WidgetTester tester,
  FakeRecordingStateNotifier notifier, {
  TargetPlatform platform = TargetPlatform.android,
  Map<String, Object> prefsValues = const {},
  bool settle = true,
  List<Override> extraOverrides = const [],
  bool pumpOnly = false,
}) async {
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();

  if (pumpOnly) {
    // Re-pump the same tree so the container survives: `pumpWidget` with a
    // new `ProviderScope` would create a second container (and so a second
    // provider state), which is not what a second visit to the screen does.
    await tester.pump();
    return;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recordingStateNotifierProvider.overrideWith(() => notifier),
        onScreenCaptionTargetProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        zcStringsProvider.overrideWith((ref) async => _testStrings),
        ...extraOverrides,
      ],
      child: MaterialApp.router(
        routerConfig: _router(platform: platform),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // While `start()` is held the state is Idle, where the controls bar
    // animates forever, so `pumpAndSettle` would time out. Two pumps land
    // the first frame and its post-frame callbacks.
    await tester.pump();
    await tester.pump();
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RecordingScreen — entry behavior', () {
    testWidgets('calls start() when entered in idle state', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle());
      await _pump(tester, notifier);

      expect(notifier.calls, contains('start'));
      expect(notifier.calls, isNot(contains('clearSession')));
    });

    testWidgets(
      'calls clearSession() then start() when entered in stopped state',
      (tester) async {
        final notifier = FakeRecordingStateNotifier(
          const RecordingState.stopped(sessionId: 'prior-session'),
        );
        await _pump(tester, notifier);

        expect(notifier.calls, containsAllInOrder(['clearSession', 'start']));
      },
    );

    testWidgets('does not call start() or clearSession() when entered '
        'in recording state', (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      expect(notifier.calls, isNot(contains('start')));
      expect(notifier.calls, isNot(contains('clearSession')));
    });

    testWidgets(
      'does not call start() or clearSession() when entered in paused state',
      (tester) async {
        final notifier = FakeRecordingStateNotifier(
          const RecordingState.paused(sessionId: 'active'),
        );
        await _pump(tester, notifier);

        expect(notifier.calls, isNot(contains('start')));
        expect(notifier.calls, isNot(contains('clearSession')));
      },
    );
  });

  group('RecordingScreen — stop navigation', () {
    testWidgets('navigates to /history when state transitions to stopped', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      await notifier.stop();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('history-screen')), findsOneWidget);
    });
  });

  group('RecordingScreen — Unit 10 failure panel (BR-U10-10)', () {
    testWidgets('shows the panel when start() leaves IdleState with an error', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      await _pump(tester, notifier);

      expect(find.byType(StartFailurePanel), findsOneWidget);
      expect(find.text('od-title'), findsOneWidget);
    });

    testWidgets('hides RecordingControlsBar while the panel shows', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.engineStartFailed();
      await _pump(tester, notifier);

      expect(find.byType(StartFailurePanel), findsOneWidget);
      // The bar spins forever on IdleState, so it must be gone.
      expect(find.byType(RecordingControlsBar), findsNothing);
    });

    testWidgets('shows the panel only after start() has finished', (
      tester,
    ) async {
      final gate = Completer<void>();
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.engineStartFailed()
        ..startGate = gate.future;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(
              await SharedPreferences.getInstance(),
            ),
            recordingStateNotifierProvider.overrideWith(() => notifier),
            onScreenCaptionTargetProvider.overrideWith(
              (ref) => const Stream.empty(),
            ),
            zcStringsProvider.overrideWith((ref) async => _testStrings),
          ],
          child: MaterialApp.router(routerConfig: _router()),
        ),
      );
      await tester.pump();

      // While start() is in flight there is no failure to show.
      expect(find.byType(StartFailurePanel), findsNothing);

      gate.complete();
      await tester.pumpAndSettle();

      expect(find.byType(StartFailurePanel), findsOneWidget);
    });

    testWidgets('"Try again" clears the failure and re-runs start()', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.engineStartFailed();
      await _pump(tester, notifier);
      expect(find.byType(StartFailurePanel), findsOneWidget);
      final startsBefore = notifier.calls.where((c) => c == 'start').length;

      // The retry succeeds this time.
      notifier.startError = null;
      await tester.tap(find.text('try-again-label'));
      await tester.pumpAndSettle();

      expect(
        notifier.calls.where((c) => c == 'start').length,
        startsBefore + 1,
      );
      expect(find.byType(StartFailurePanel), findsNothing);
      expect(find.byType(RecordingControlsBar), findsOneWidget);
    });

    testWidgets('"Back" returns to Home', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.permissionDenied();
      await _pump(tester, notifier);

      await tester.tap(find.text('back-label'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('home-screen')), findsOneWidget);
    });

    testWidgets('"Open settings" appears only where the view allows it', (
      tester,
    ) async {
      final allowed = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.engineInitFailed();
      await _pump(tester, allowed);
      expect(find.text('open-settings-label'), findsOneWidget);
    });

    testWidgets('"Open settings" is absent for on-device unavailability', (
      tester,
    ) async {
      final denied = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      await _pump(tester, denied);

      expect(find.byType(StartFailurePanel), findsOneWidget);
      expect(find.text('open-settings-label'), findsNothing);
    });
  });

  group('RecordingScreen — language pack (Amendment 04, TP-29)', () {
    Future<FakeLanguagePackService> pumpRefusal(
      WidgetTester tester,
      FakeRecordingStateNotifier notifier, {
      TargetPlatform platform = TargetPlatform.android,
      LanguagePackStatus status = LanguagePackStatus.downloadable,
    }) async {
      final fake = FakeLanguagePackService()
        ..setStatus('fr-CA', status, displayName: 'French');
      addTearDown(fake.close);
      await _pump(
        tester,
        notifier,
        platform: platform,
        prefsValues: const {SpeechExplainerGate.seenKey: true},
        extraOverrides: [
          resolvedLocaleIdProvider.overrideWithValue('fr-CA'),
          languagePackServiceProvider.overrideWithValue(fake),
          languagePackOsVersionProvider.overrideWithValue(
            platform == TargetPlatform.iOS ? 26 : null,
          ),
        ],
      );
      return fake;
    }

    testWidgets('the refusal offers Download for the resolved locale, never '
        'Open settings', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      final fake = await pumpRefusal(tester, notifier);

      expect(find.text('od-title'), findsOneWidget);
      expect(find.text('dl-label French'), findsOneWidget);
      expect(find.text('open-settings-label'), findsNothing);
      expect(fake.statusCalls, ['fr-CA']);
      expect(fake.downloadCalls, isEmpty);
    });

    testWidgets('no download and no second start() without a tap', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      final fake = await pumpRefusal(tester, notifier);

      await tester.pump(const Duration(minutes: 10));

      expect(fake.downloadCalls, isEmpty);
      expect(notifier.startCalls, 1);
    });

    testWidgets('a finished download does not start captioning: Try again is '
        'the only way back to start()', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      final fake = await pumpRefusal(tester, notifier);

      await tester.tap(find.text('dl-label French'));
      await tester.pump();
      fake.send(const LanguagePackDone('fr-CA'));
      await tester.pump();
      await tester.pump(const Duration(minutes: 10));

      expect(find.text('ready French'), findsOneWidget);
      expect(notifier.startCalls, 1, reason: 'the app never starts itself');

      notifier.startError = null;
      await tester.tap(find.text('try-again-label'));
      await tester.pumpAndSettle();

      expect(notifier.startCalls, 2);
      expect(find.byType(StartFailurePanel), findsNothing);
    });

    testWidgets('the failure state keeps Try again and Back', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      final fake = await pumpRefusal(tester, notifier);

      await tester.tap(find.text('dl-label French'));
      await tester.pump();
      fake.send(const LanguagePackFailed('fr-CA', code: 1));
      await tester.pump();

      expect(find.text('failed French'), findsOneWidget);
      expect(find.text('try-again-label'), findsOneWidget);
      expect(find.text('back-label'), findsOneWidget);
      expect(notifier.startCalls, 1);
    });

    testWidgets('a pending download shows the scheduled text with Try again '
        'still available (BR-U10-47a)', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      final fake = await pumpRefusal(
        tester,
        notifier,
        status: LanguagePackStatus.downloading,
      );

      await tester.pump(const Duration(minutes: 10));

      expect(find.text('scheduled French'), findsOneWidget);
      expect(find.text('failed French'), findsNothing);
      expect(find.text('try-again-label'), findsOneWidget);
      expect(fake.downloadCalls, isEmpty);
      expect(notifier.startCalls, 1);
    });

    testWidgets('iOS below 26 shows the instructions on the refusal', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
        ..startError = RecordingErrorFactories.onDeviceRecognitionUnavailable();
      final fake = FakeLanguagePackService()
        ..setStatus('fr-CA', LanguagePackStatus.unknown, displayName: 'French');
      addTearDown(fake.close);
      await _pump(
        tester,
        notifier,
        platform: TargetPlatform.iOS,
        prefsValues: const {SpeechExplainerGate.seenKey: true},
        extraOverrides: [
          resolvedLocaleIdProvider.overrideWithValue('fr-CA'),
          languagePackServiceProvider.overrideWithValue(fake),
          languagePackOsVersionProvider.overrideWithValue(18),
        ],
      );

      expect(find.text('ios-steps French'), findsOneWidget);
      expect(find.text('dl-label French'), findsNothing);
    });

    for (final error in <String, RecordingError Function()>{
      'engineStartFailed': RecordingErrorFactories.engineStartFailed,
      'permissionDenied': RecordingErrorFactories.permissionDenied,
      'engineInitFailed': RecordingErrorFactories.engineInitFailed,
    }.entries) {
      testWidgets('${error.key} never asks for a language-pack status', (
        tester,
      ) async {
        final notifier = FakeRecordingStateNotifier(const RecordingState.idle())
          ..startError = error.value();
        final fake = await pumpRefusal(tester, notifier);

        expect(find.byType(StartFailurePanel), findsOneWidget);
        expect(fake.statusCalls, isEmpty);
        expect(find.text('dl-label French'), findsNothing);
      });
    }
  });

  group('RecordingScreen — mid-session notice (BR-U10-23)', () {
    testWidgets('shows a one-time notice when a session stops with an error', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      notifier.stopWithError(
        RecordingErrorFactories.onDeviceRecognitionUnavailable(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('od-title'), findsOneWidget);
      // The notice never offers "Open settings".
      expect(find.text('open-settings-label'), findsNothing);
    });

    testWidgets('shows no notice when a session stops without an error', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      await notifier.stop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('RecordingScreen — no-transcript notice (Q-2, Amendment 03 '
      'section 7)', () {
    testWidgets(
      'shows the notice once on a no-transcript stop with capture on',
      (tester) async {
        final notifier = FakeRecordingStateNotifier(
          const RecordingState.recording(sessionId: 'active'),
        );
        await _pump(
          tester,
          notifier,
          extraOverrides: [
            transcriptSaveOutcomeProvider.overrideWith(
              () => _FixedOutcome(value: false),
            ),
          ],
        );

        await notifier.stop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('no-transcript'), findsOneWidget);
        // Navigation to /history is unchanged by the notice.
        expect(find.byKey(const Key('history-screen')), findsOneWidget);
      },
    );

    testWidgets('shows nothing when the session saved a transcript', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(
        tester,
        notifier,
        extraOverrides: [
          transcriptSaveOutcomeProvider.overrideWith(
            () => _FixedOutcome(value: true),
          ),
        ],
      );

      await notifier.stop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('shows nothing when capture is off', (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(
        tester,
        notifier,
        extraOverrides: [
          transcriptSaveOutcomeProvider.overrideWith(
            () => _FixedOutcome(value: false),
          ),
          transcriptSettingsNotifierProvider.overrideWith(
            () => _PinnedCaptureSettings(enabled: false),
          ),
        ],
      );

      await notifier.stop();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets(
      'does not show a stale outcome: the writer forgetting the outcome on '
      'the next session start is what stops the notice repeating',
      (tester) async {
        // Step 29b follow-up: the outcome provider kept the previous
        // session's value, so a later stop read the old one and repeated the
        // notice. The writer target now records `null` when a new session
        // starts, which is the transition tested here: the screen only reads.
        // Session one stops after the writer recorded `false` (it ran and
        // saved nothing).
        final writer = _WritableOutcome();
        final first = FakeRecordingStateNotifier(
          const RecordingState.recording(sessionId: 'first'),
        )
          ..setSessionIdOnStop('first-stop')
          ..beforeStopGate = Completer<void>();
        await _pump(
          tester,
          first,
          extraOverrides: [
            transcriptSaveOutcomeProvider.overrideWith(() => writer),
          ],
        );
        // Recorded the way the stop callback does, once the screen (and so
        // the provider) exists, before the stop is published.
        ProviderScope.containerOf(
          tester.element(find.byType(RecordingScreen)),
          listen: false,
        ).read(transcriptSaveOutcomeProvider.notifier).record(false);
        final firstStop = first.stop();
        first.beforeStopGate!.complete();
        await firstStop;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('no-transcript'), findsOneWidget);
        expect(writer.mutations, ['record=false']);

        // Session two starts in the same screen and container: the writer
        // target forgetting the old outcome on the session-start event is
        // what keeps the notice from repeating. No second `pumpWidget`, so no
        // second provider container (which is not what a second visit does).
        await first.start();
        await tester.pump();
        writer.record(null);
        first
          ..setSessionIdOnStop('second-stop')
          ..beforeStopGate = Completer<void>();
        final secondStop = first.stop();
        first.beforeStopGate!.complete();
        await secondStop;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(
          writer.mutations,
          ['record=false', 'record=null'],
          reason: 'the screen read and changed nothing',
        );
        // The first session's notice is still on screen (its four-second
        // duration has not started under the fake clock), so the check is for
        // a second one, which only a stale read would add.
        final notices = tester
            .widgetList<SnackBar>(find.byType(SnackBar))
            .where((bar) => (bar.content as Text).data == 'no-transcript');
        expect(
          notices,
          hasLength(1),
          reason: "the writer forgot the previous session's outcome",
        );
      },
    );

    testWidgets('queues the notice after the error notice (BR-U10-23)', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(
        tester,
        notifier,
        extraOverrides: [
          transcriptSaveOutcomeProvider.overrideWith(
            () => _FixedOutcome(value: false),
          ),
        ],
      );

      notifier.stopWithError(
        RecordingErrorFactories.onDeviceRecognitionUnavailable(),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // The error notice shows first; the no-transcript notice waits in
      // the ScaffoldMessenger queue.
      expect(find.text('od-title'), findsOneWidget);
      expect(find.text('no-transcript'), findsNothing);

      // The duration timer arms only once the entrance animation completes,
      // so: land the entrance, run the 4 s duration, let the reverse
      // animation finish — then the queued notice shows.
      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('no-transcript'), findsOneWidget);
    });
  });

  group('RecordingScreen — inactivity stop notice (TP-33, BR-U10-53)', () {
    /// Records the stop reason the way the notifier does, just before the
    /// stopped state is published.
    void recordInactivity(WidgetTester tester) {
      ProviderScope.containerOf(
        tester.element(find.byType(RecordingScreen)),
        listen: false,
      ).read(sessionStopReasonProvider.notifier).record(
            SessionStopReason.inactivity,
          );
    }

    Future<void> pumpAfterStop(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows the notice once, with the minutes from the provider', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);
      recordInactivity(tester);

      await notifier.stop();
      await pumpAfterStop(tester);

      expect(find.text('inactive-stop 5 minutes'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.byKey(const Key('history-screen')), findsOneWidget);
    });

    testWidgets('uses the timeout in force and the singular for 1 minute', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(
        tester,
        notifier,
        extraOverrides: [
          speechInactivityTimeoutProvider
              .overrideWithValue(const Duration(minutes: 1)),
        ],
      );
      recordInactivity(tester);

      await notifier.stop();
      await pumpAfterStop(tester);

      expect(find.text('inactive-stop 1 minute'), findsOneWidget);
    });

    testWidgets('consumes the reason: read once, then reset', (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(RecordingScreen)),
        listen: false,
      );
      recordInactivity(tester);
      expect(
        container.read(sessionStopReasonProvider),
        SessionStopReason.inactivity,
      );

      await notifier.stop();
      await pumpAfterStop(tester);

      expect(find.text('inactive-stop 5 minutes'), findsOneWidget);
      expect(
        tester.widgetList<SnackBar>(find.byType(SnackBar)),
        hasLength(1),
      );
      expect(
        container.read(sessionStopReasonProvider),
        isNull,
        reason: 'read then reset',
      );
    });

    testWidgets('queues the no-transcript notice after it', (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(
        tester,
        notifier,
        extraOverrides: [
          transcriptSaveOutcomeProvider.overrideWith(
            () => _FixedOutcome(value: false),
          ),
        ],
      );
      recordInactivity(tester);

      await notifier.stop();
      await pumpAfterStop(tester);

      // The inactivity notice shows first; the other waits in the queue.
      expect(find.text('inactive-stop 5 minutes'), findsOneWidget);
      expect(find.text('no-transcript'), findsNothing);

      await tester.pump(const Duration(milliseconds: 250));
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('no-transcript'), findsOneWidget);
    });

    testWidgets('never shows for a user stop', (tester) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      await notifier.stop();
      await pumpAfterStop(tester);

      expect(find.textContaining('inactive-stop'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('never shows for an error stop or a refused resume', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(
        const RecordingState.recording(sessionId: 'active'),
      );
      await _pump(tester, notifier);

      notifier.stopWithError(
        RecordingErrorFactories.onDeviceRecognitionUnavailable(),
      );
      await pumpAfterStop(tester);

      expect(find.text('od-title'), findsOneWidget);
      expect(find.textContaining('inactive-stop'), findsNothing);
    });
  });

  group('Q-1 one start per entry', () {
    // Q-1: the screen and the gate both started the session, so a fresh
    // install ran start() twice in one frame. The gate is the only owner.
    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.macOS,
      TargetPlatform.iOS,
    ]) {
      testWidgets(
        'on $platform with the explainer already seen: exactly one start',
        (tester) async {
          // Q-1, tightened: `start()` is held open with the fake's startGate,
          // the way a real start sits at the permission dialog. Without the
          // hold the fake moved to Recording synchronously, so a second
          // post-frame `_startIfNeeded` saw RecordingActiveState and returned
          // — the case passed for the wrong reason.
          final entryGate = Completer<void>();
          final notifier = FakeRecordingStateNotifier(
            const RecordingState.idle(),
          )..startGate = entryGate.future;
          await _pump(
            tester,
            notifier,
            platform: platform,
            prefsValues: const {SpeechExplainerGate.seenKey: true},
            settle: false,
          );

          expect(
            notifier.startCalls,
            1,
            reason: 'exactly one start while start() is held at the dialog',
          );

          entryGate.complete();
          await tester.pumpAndSettle();
          expect(
            notifier.startCalls,
            1,
            reason: 'still exactly one start after the held start lands',
          );
        },
      );
    }

    testWidgets('on iOS not yet seen: no start until Continue, then one', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle());
      await _pump(tester, notifier, platform: TargetPlatform.iOS);

      expect(find.text('explainer-title'), findsOneWidget);
      expect(notifier.startCalls, 0);

      await tester.tap(find.text('explainer-continue'));
      await tester.pumpAndSettle();

      expect(notifier.startCalls, 1);
    });

    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      testWidgets(
        'on $platform a failure then Try again starts exactly twice',
        (tester) async {
          // Q-1, tightened: both starts are held open with startGate, so a
          // second start from the same tap (the old "Try again" mounted a
          // fresh gate whose initState started as well) is visible while the
          // first is still in flight.
          final entryGate = Completer<void>();
          final notifier =
              FakeRecordingStateNotifier(const RecordingState.idle())
                ..startError = RecordingErrorFactories.permissionDenied()
                ..startGate = entryGate.future;
          await _pump(
            tester,
            notifier,
            platform: platform,
            prefsValues: const {SpeechExplainerGate.seenKey: true},
            settle: false,
          );
          expect(
            notifier.startCalls,
            1,
            reason: 'one start while the entry start() is held',
          );

          entryGate.complete();
          await tester.pumpAndSettle();
          expect(
            notifier.startCalls,
            1,
            reason: 'still one start after the entry start lands',
          );
          expect(find.byType(StartFailurePanel), findsOneWidget);

          final retryGate = Completer<void>();
          notifier
            ..startGate = retryGate.future
            ..startError = null;
          await tester.tap(find.text('try-again-label'));
          await tester.pump();

          expect(
            notifier.startCalls,
            2,
            reason: 'exactly one retry start while start() is held',
          );

          retryGate.complete();
          await tester.pumpAndSettle();

          expect(
            notifier.startCalls,
            2,
            reason: 'still exactly two starts after the retry lands',
          );
          expect(find.byType(StartFailurePanel), findsNothing);
        },
      );
    }
  });

  group('RecordingScreen — iOS explainer gate (BR-U10-33)', () {
    testWidgets('on iOS start() is not called until the explainer continues', (
      tester,
    ) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle());
      await _pump(tester, notifier, platform: TargetPlatform.iOS);

      expect(find.text('explainer-title'), findsOneWidget);
      expect(notifier.calls, isNot(contains('start')));

      await tester.tap(find.text('explainer-continue'));
      await tester.pumpAndSettle();

      expect(notifier.calls, contains('start'));
    });

    testWidgets('on Android no explainer is shown', (tester) async {
      final notifier = FakeRecordingStateNotifier(const RecordingState.idle());
      await _pump(tester, notifier);

      expect(find.text('explainer-title'), findsNothing);
      expect(notifier.calls, contains('start'));
    });
  });
}
