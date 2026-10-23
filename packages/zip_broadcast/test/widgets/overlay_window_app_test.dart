import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

CaptionDisplayEntry _entry(String text, {bool isFinal = true}) =>
    CaptionDisplayEntry(
      entryId: text,
      sessionId: 's',
      text: text,
      isFinal: isFinal,
      sourceId: 'src',
      timestamp: DateTime.utc(2026),
    );

CaptionOverlaySnapshot _frame({
  OverlayActivity activity = OverlayActivity.live,
  List<CaptionDisplayEntry> entries = const [],
  CaptionDisplayEntry? interim,
  DisplaySettings? settings,
}) =>
    CaptionOverlaySnapshot(
      activity: activity,
      entries: entries,
      interim: interim,
      settings: settings ?? DisplaySettings.defaults(),
    );

Future<void> _pump(
  WidgetTester tester,
  CaptionOverlaySnapshot frame, {
  OverlayConfig config = const OverlayConfig(),
}) async {
  final notifier = ValueNotifier<CaptionOverlaySnapshot>(frame);
  addTearDown(notifier.dispose);
  await tester.pumpWidget(
    ProviderScope(
      child: OverlayWindowApp(
        launch: OverlayWindowLaunch(config: config, snapshot: frame),
        snapshot: notifier,
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('standby shows the surface and no caption text', (tester) async {
    await _pump(tester, _frame(activity: OverlayActivity.standby));

    expect(find.text('hello'), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('live renders the buffer through the shipped widget',
      (tester) async {
    await _pump(tester, _frame(entries: [_entry('hello')]));

    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('paused keeps the frozen buffer and the pause row',
      (tester) async {
    await _pump(
      tester,
      _frame(
        activity: OverlayActivity.paused,
        entries: [
          _entry('frozen'),
          CaptionDisplayEntry(
            entryId: 'pause',
            sessionId: 's',
            text: '',
            isFinal: true,
            sourceId: '__pause__',
            timestamp: DateTime.utc(2026),
          ),
        ],
      ),
    );

    expect(find.text('frozen'), findsOneWidget);
  });

  testWidgets('the unavailable frame names the problem', (tester) async {
    // Shape change 1: the copy is injected, because `zip_core` has no ARB.
    await tester.pumpWidget(
      const OverlayWindowUnavailableApp(message: 'Window unavailable'),
    );
    await tester.pump();

    expect(find.text('Window unavailable'), findsOneWidget);
  });

  testWidgets('the caption block follows the launch position', (tester) async {
    await _pump(
      tester,
      _frame(entries: [_entry('hello')]),
      config: const OverlayConfig(position: OverlayPositionTop()),
    );

    final align = tester.widget<Align>(
      find.ancestor(
        of: find.text('hello'),
        matching: find.byType(Align),
      ),
    );
    expect(align.alignment, Alignment.topCenter);
  });

  testWidgets('the surface colour follows the snapshot theme setting',
      (tester) async {
    Color surfaceFor(ThemeModeSetting setting) {
      final theme = switch (setting) {
        ThemeModeSetting.dark => AppTheme.dark(),
        ThemeModeSetting.light => AppTheme.light(),
        ThemeModeSetting.system => AppTheme.light(),
      };
      return theme.colorScheme.surface;
    }

    final notifier = ValueNotifier<CaptionOverlaySnapshot>(
      _frame(
        settings: DisplaySettings.defaults().copyWith(
          themeModeSetting: ThemeModeSetting.light,
        ),
      ),
    );
    addTearDown(notifier.dispose);
    await tester.pumpWidget(
      ProviderScope(
        child: OverlayWindowApp(
          launch: OverlayWindowLaunch(
            config: const OverlayConfig(),
            snapshot: notifier.value,
          ),
          snapshot: notifier,
        ),
      ),
    );
    await tester.pump();

    Color painted() => tester
        .widget<Scaffold>(find.byType(Scaffold))
        .backgroundColor!;

    expect(painted(), surfaceFor(ThemeModeSetting.light));

    notifier.value = _frame(
      settings: DisplaySettings.defaults().copyWith(
        themeModeSetting: ThemeModeSetting.dark,
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    expect(painted(), surfaceFor(ThemeModeSetting.dark));
  });

  testWidgets('the surface is opaque even when the config asks otherwise',
      (tester) async {
    await _pump(
      tester,
      _frame(entries: [_entry('hello')]),
      // A translucent request must still paint an opaque surface.
      config: const OverlayConfig(opacity: 0.5),
    );

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
    expect(scaffold.backgroundColor?.a, 1);
  });
}
