import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/widgets/pop_out_controls.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

/// Pumps one control inside the app's localizations, as the shell does.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        ZipBroadcastLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZipBroadcastLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

ZipBroadcastLocalizations _l10n(WidgetTester tester) =>
    ZipBroadcastLocalizations.of(tester.element(find.byType(Scaffold)))!;

void main() {
  group('PopOutChrome (B31)', () {
    testWidgets('shows the enter label and fires the toggle when available',
        (tester) async {
      var toggled = 0;
      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          onToggle: () => toggled++,
        ),
      );

      final l10n = _l10n(tester);
      expect(find.text(l10n.popOutEnter), findsOneWidget);
      expect(find.text(l10n.popOutExit), findsNothing);

      await tester.tap(find.byKey(const Key('popOutToggle')));
      expect(toggled, 1);
    });

    testWidgets('shows the exit label while popped out', (tester) async {
      final states = <ExternalDisplayStatus>[
        const Off(),
        const Opening(),
        const Open(activity: OverlayActivity.live, displayId: 'd1'),
      ];

      for (final status in states) {
        await _pump(
          tester,
          PopOutChrome(
            status: status,
            recording: const RecordingState.recording(sessionId: 's'),
            engineAvailable: true,
            isPoppedOut: true,
            onToggle: () {},
          ),
        );
        final l10n = _l10n(tester);
        expect(find.text(l10n.popOutExit), findsOneWidget);
        expect(find.text(l10n.popOutEnter), findsNothing);
      }
    });

    testWidgets('renders nothing when the platform is unsupported',
        (tester) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Unsupported(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          onToggle: () {},
        ),
      );

      expect(find.byKey(const Key('popOutToggle')), findsNothing);
      expect(find.byKey(const Key('popOutToggleReason')), findsNothing);
    });

    testWidgets('is disabled with a visible reason and no session',
        (tester) async {
      var toggled = 0;
      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.idle(),
          engineAvailable: true,
          isPoppedOut: false,
          onToggle: () => toggled++,
        ),
      );

      final l10n = _l10n(tester);
      final button = tester.widget<TextButton>(
        find.byKey(const Key('popOutToggle')),
      );
      expect(button.onPressed, isNull);
      expect(find.text(l10n.popOutUnavailableNoSession), findsOneWidget);
      // The label stays: the feature must be discoverable while unavailable.
      expect(find.text(l10n.popOutEnter), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutToggle')));
      expect(toggled, 0);
    });

    testWidgets('is disabled with a visible reason and no engine',
        (tester) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: false,
          isPoppedOut: false,
          onToggle: () {},
        ),
      );

      final l10n = _l10n(tester);
      final button = tester.widget<TextButton>(
        find.byKey(const Key('popOutToggle')),
      );
      expect(button.onPressed, isNull);
      expect(find.text(l10n.popOutUnavailableNoEngine), findsOneWidget);
      // No engine beats no session: both are false only in the engine case.
      expect(find.text(l10n.popOutUnavailableNoSession), findsNothing);
    });

    testWidgets('shows the open-failure line when the window service failed',
        (tester) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Failed(reason: 'create_failed'),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          onToggle: () {},
        ),
      );

      expect(
        find.text(_l10n(tester).popOutOpenFailed),
        findsOneWidget,
      );
    });

    testWidgets('clears the failure line when the status leaves Failed',
        (tester) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Failed(reason: 'create_failed'),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          onToggle: () {},
        ),
      );
      expect(find.byKey(const Key('popOutOpenFailed')), findsOneWidget);

      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          onToggle: () {},
        ),
      );
      expect(find.byKey(const Key('popOutOpenFailed')), findsNothing);
    });
  });

  group('PopOutInSurfaceToggle', () {
    testWidgets('uses the main-window key and fires the toggle',
        (tester) async {
      var toggled = 0;
      await _pump(
        tester,
        PopOutInSurfaceToggle(
          isPoppedOut: false,
          onToggle: () => toggled++,
        ),
      );

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      expect(toggled, 1);
      expect(find.byKey(const Key('popOutInSurfaceToggleWindow')), findsNothing);
    });

    testWidgets('uses the window key inside the pop-out', (tester) async {
      await _pump(
        tester,
        PopOutInSurfaceToggle(
          isPoppedOut: true,
          windowToggle: true,
          onToggle: () {},
        ),
      );

      expect(find.byKey(const Key('popOutInSurfaceToggleWindow')), findsOneWidget);
      expect(find.byKey(const Key('popOutInSurfaceToggle')), findsNothing);
    });

    testWidgets('ignores taps when disabled', (tester) async {
      var toggled = 0;
      await _pump(
        tester,
        PopOutInSurfaceToggle(
          isPoppedOut: false,
          enabled: false,
          onToggle: () => toggled++,
        ),
      );

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      expect(toggled, 0);
    });
  });
}
