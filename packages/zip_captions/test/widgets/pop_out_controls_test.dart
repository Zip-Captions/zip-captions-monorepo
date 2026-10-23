import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/widgets/pop_out_controls.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

/// The copy every assertion reads, keyed so the sentinel is unambiguous.
const _strings = ZcStrings.fromMap({
  'popOutEnter': 'enter',
  'popOutExit': 'exit',
  'popOutHint': 'hint',
  'popOutReturn': 'return',
  'popOutUnavailableNoSession': 'no-session',
  'popOutUnavailableNoEngine': 'no-engine',
  'popOutOpenFailed': 'open-failed',
});

/// Pumps one control inside the scope that carries the copy, as the shell
/// does.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PopOutScope(
        enabled: false,
        onToggle: () {},
        available: true,
        strings: _strings,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  await tester.pump();
}

/// The chrome control's semantics hint, which carries its disabled reason.
///
/// The hint merges upwards from the button into the surrounding
/// `Semantics(container: …)`, so it is read from the card, not the button.
String? _hint(WidgetTester tester) =>
    tester.getSemantics(find.byType(PopOutChrome)).hint;

void main() {
  group('PopOutChrome (B31)', () {
    testWidgets('shows the enter label and fires the toggle when available', (
      tester,
    ) async {
      var toggled = 0;
      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          reason: popOutAvailability(
            status: const Off(),
            recording: const RecordingState.recording(sessionId: 's'),
            engineAvailable: true,
          ).reason,
          onToggle: () => toggled++,
        ),
      );

      expect(find.text('enter'), findsOneWidget);
      expect(find.text('exit'), findsNothing);

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
            reason: popOutAvailability(
              status: status,
              recording: const RecordingState.recording(sessionId: 's'),
              engineAvailable: true,
            ).reason,
            onToggle: () {},
          ),
        );
        expect(find.text('exit'), findsOneWidget);
        expect(find.text('enter'), findsNothing);
      }
    });

    testWidgets('renders nothing when the platform is unsupported', (
      tester,
    ) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Unsupported(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          reason: popOutAvailability(
            status: const Unsupported(),
            recording: const RecordingState.recording(sessionId: 's'),
            engineAvailable: true,
          ).reason,
          onToggle: () {},
        ),
      );

      expect(find.byKey(const Key('popOutToggle')), findsNothing);
      expect(find.byKey(const Key('popOutToggleReason')), findsNothing);
    });

    testWidgets('is disabled with a visible reason and no session', (
      tester,
    ) async {
      var toggled = 0;
      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.idle(),
          engineAvailable: true,
          isPoppedOut: false,
          reason: popOutAvailability(
            status: const Off(),
            recording: const RecordingState.idle(),
            engineAvailable: true,
          ).reason,
          onToggle: () => toggled++,
        ),
      );

      final button = tester.widget<TextButton>(
        find.byKey(const Key('popOutToggle')),
      );
      expect(button.onPressed, isNull);
      // FD frontend-components §3: the reason is visible text beneath the
      // control, under its own key, and in the semantics hint as well.
      expect(find.byKey(const Key('popOutToggleReason')), findsOneWidget);
      // The label stays: the feature must be discoverable while unavailable.
      expect(find.text('enter'), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutToggle')));
      expect(toggled, 0);
    });

    testWidgets('is disabled with a visible reason and no engine', (
      tester,
    ) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: false,
          isPoppedOut: false,
          reason: popOutAvailability(
            status: const Off(),
            recording: const RecordingState.recording(sessionId: 's'),
            engineAvailable: false,
          ).reason,
          onToggle: () {},
        ),
      );

      final button = tester.widget<TextButton>(
        find.byKey(const Key('popOutToggle')),
      );
      expect(button.onPressed, isNull);
      expect(find.byKey(const Key('popOutToggleReason')), findsOneWidget);
    });

    testWidgets('shows the open-failure line when the window service failed', (
      tester,
    ) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Failed(reason: 'create_failed'),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          reason: popOutAvailability(
            status: const Failed(reason: 'create_failed'),
            recording: const RecordingState.recording(sessionId: 's'),
            engineAvailable: true,
          ).reason,
          onToggle: () {},
        ),
      );

      expect(_hint(tester), isNotNull);
    });

    testWidgets('clears the failure line when the status leaves Failed', (
      tester,
    ) async {
      await _pump(
        tester,
        PopOutChrome(
          status: const Failed(reason: 'create_failed'),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          reason: popOutAvailability(
            status: const Failed(reason: 'create_failed'),
            recording: const RecordingState.recording(sessionId: 's'),
            engineAvailable: true,
          ).reason,
          onToggle: () {},
        ),
      );
      expect(_hint(tester), isNotNull);

      await _pump(
        tester,
        PopOutChrome(
          status: const Off(),
          recording: const RecordingState.recording(sessionId: 's'),
          engineAvailable: true,
          isPoppedOut: false,
          reason: popOutAvailability(
            status: const Off(),
            recording: const RecordingState.recording(sessionId: 's'),
            engineAvailable: true,
          ).reason,
          onToggle: () {},
        ),
      );
      expect(_hint(tester) ?? '', isEmpty);
      expect(find.byKey(const Key('popOutToggleReason')), findsNothing);
    });
  });

  group('PopOutInSurfaceToggle', () {
    testWidgets('uses the main-window key and fires the toggle', (
      tester,
    ) async {
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
      expect(
        find.byKey(const Key('popOutInSurfaceToggleWindow')),
        findsNothing,
      );
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

      expect(
        find.byKey(const Key('popOutInSurfaceToggleWindow')),
        findsOneWidget,
      );
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
