// Tests for Unit 8.1 (S-21): the pop-out window body (FD frontend-components
// §7). N-12.
//
// The body is rendered inside a `MaterialApp` because it reads the theme; the
// AppTheme is the shipped one, so a theme swap is observable as a surface
// colour change rather than an assertion on an internal field.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/widgets/pop_out_window_body.dart';
import 'package:zip_core/zip_core.dart';

CaptionDisplayEntry _entry(String text) => CaptionDisplayEntry(
  entryId: text,
  sessionId: 's',
  text: text,
  isFinal: true,
  sourceId: 'default',
  timestamp: DateTime.utc(2026),
);

Widget _build(
  PopOutWindowBody body, {
  ThemeMode themeMode = ThemeMode.dark,
}) => ProviderScope(
  child: MaterialApp(
    themeMode: themeMode,
    theme: AppTheme.light(),
    darkTheme: AppTheme.dark(),
    home: body,
  ),
);

void main() {
  testWidgets('standby shows the surface and nothing else', (tester) async {
    await tester.pumpWidget(
      _build(
        PopOutWindowBody(
          activity: OverlayActivity.standby,
          entries: [for (var i = 0; i < 5; i++) _entry('line $i')],
          interim: null,
          settings: DisplaySettings.defaults(),
        ),
      ),
    );

    expect(find.byType(CaptionDisplayWidget), findsNothing);
    expect(find.text('line 0'), findsNothing);
  });

  testWidgets('live renders through the shared caption widget', (tester) async {
    await tester.pumpWidget(
      _build(
        PopOutWindowBody(
          activity: OverlayActivity.live,
          entries: [_entry('hello')],
          interim: null,
          settings: DisplaySettings.defaults(),
        ),
      ),
    );

    expect(find.byType(CaptionDisplayWidget), findsOneWidget);
    expect(find.text('hello'), findsOneWidget);
  });

  testWidgets('paused keeps the frozen buffer on screen', (tester) async {
    await tester.pumpWidget(
      _build(
        PopOutWindowBody(
          activity: OverlayActivity.paused,
          entries: [_entry('frozen')],
          interim: null,
          settings: DisplaySettings.defaults(),
        ),
      ),
    );

    expect(find.text('frozen'), findsOneWidget);
  });

  testWidgets('the interim caption renders alongside the finals', (
    tester,
  ) async {
    await tester.pumpWidget(
      _build(
        PopOutWindowBody(
          activity: OverlayActivity.live,
          entries: [_entry('final')],
          interim: CaptionDisplayEntry(
            entryId: 'i',
            sessionId: 's',
            text: 'partial',
            isFinal: false,
            sourceId: 'default',
            timestamp: DateTime.utc(2026),
          ),
          settings: DisplaySettings.defaults(),
        ),
      ),
    );

    expect(find.text('final'), findsOneWidget);
    expect(find.text('partial'), findsOneWidget);
  });

  testWidgets('the injected toggle is present and its callback fires', (
    tester,
  ) async {
    var toggles = 0;
    await tester.pumpWidget(
      _build(
        PopOutWindowBody(
          activity: OverlayActivity.live,
          entries: [_entry('hello')],
          interim: null,
          settings: DisplaySettings.defaults(),
          onTogglePopOut: () => toggles++,
        ),
      ),
    );

    // Finding 4: popped out, so the exit glyph and the exit label, not a
    // static "enter" icon with no label.
    final toggle = find.byKey(const Key('popOutInSurfaceToggleWindow'));
    expect(toggle, findsOneWidget);
    expect(
      find.descendant(
        of: toggle,
        matching: find.byIcon(Icons.picture_in_picture_alt),
      ),
      findsOneWidget,
    );
    expect(find.text(popOutWindowExitLabel), findsOneWidget);

    await tester.tap(toggle);
    await tester.pump();

    expect(toggles, 1);
  });

  testWidgets('no caption text leaks into a widget key', (tester) async {
    await tester.pumpWidget(
      _build(
        PopOutWindowBody(
          activity: OverlayActivity.live,
          entries: [_entry('secret caption text')],
          interim: null,
          settings: DisplaySettings.defaults(),
        ),
      ),
    );

    // The text itself is on screen by design; what must never carry it is an
    // identifier — a key, a route name or a `Semantics` identifier — because
    // those are the values that reach logs and platform integrations.
    for (final element in find.byType(Widget).evaluate()) {
      final key = element.widget.key;
      if (key is ValueKey<String>) {
        expect(key.value.contains('secret'), isFalse);
      }
    }

    // A `Semantics` identifier is the one semantic field that leaves the
    // process, so it must never hold caption text.
    final nodes = <SemanticsNode>[];
    void walk(SemanticsNode node) {
      nodes.add(node);
      node.visitChildren((child) {
        walk(child);
        return true;
      });
    }

    final renderView = tester.binding.renderViews.first;
    final root = renderView.owner!.semanticsOwner!.rootSemanticsNode!;
    walk(root);

    for (final node in nodes) {
      expect(node.identifier.contains('secret'), isFalse);
    }
  });

  testWidgets('a theme swap changes the surface colour', (tester) async {
    Widget build(ThemeMode mode) => _build(
      PopOutWindowBody(
        activity: OverlayActivity.live,
        entries: [_entry('hello')],
        interim: null,
        settings: DisplaySettings.defaults(),
      ),
      themeMode: mode,
    );

    Color surface(WidgetTester tester) {
      final context = tester.element(find.byType(PopOutWindowBody));
      return Theme.of(context).colorScheme.surface;
    }

    await tester.pumpWidget(build(ThemeMode.dark));
    final dark = surface(tester);

    await tester.pumpWidget(build(ThemeMode.light));
    await tester.pumpAndSettle();
    final light = surface(tester);

    expect(dark, isNot(light));
  });
}
