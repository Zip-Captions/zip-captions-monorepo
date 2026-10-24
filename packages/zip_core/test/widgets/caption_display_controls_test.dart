// Tests for Unit 8.1 (S-21): the `controls` slot on the shared caption widget
// (FD frontend-components §2; R-M4). N-13.
//
// The point of the slot is that the control row lives **outside** the
// scrolling list, so it stays visible however many captions arrive and in
// either scroll direction. These tests assert that structurally: the control
// is not a descendant of the `ListView`, and it is still found after the list
// scrolls and after ten entries.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/zip_core.dart';

CaptionDisplayEntry _entry(String id) => CaptionDisplayEntry(
  entryId: id,
  sessionId: 's',
  text: 'caption $id',
  isFinal: true,
  sourceId: 'default',
  timestamp: DateTime.utc(2026),
);

Widget _build({
  required List<CaptionDisplayEntry> entries,
  Widget? controls,
  ScrollDirection direction = ScrollDirection.bottomToTop,
}) => ProviderScope(
  child: MaterialApp(
    home: Scaffold(
      body: CaptionDisplayWidget(
        entries: entries,
        settings: DisplaySettings.defaults().copyWith(
          scrollDirection: direction,
        ),
        controls: controls,
      ),
    ),
  ),
);

const _controlKey = ValueKey<String>('controls');

void main() {
  testWidgets('controls: null renders the list and nothing else', (
    tester,
  ) async {
    await tester.pumpWidget(_build(entries: [_entry('a'), _entry('b')]));

    expect(find.byType(ListView), findsOneWidget);
    expect(find.byKey(_controlKey), findsNothing);
    expect(find.text('caption b'), findsOneWidget);
  });

  testWidgets('a control renders outside the ListView', (tester) async {
    await tester.pumpWidget(
      _build(
        entries: [_entry('a')],
        controls: const SizedBox(key: _controlKey, height: 44),
      ),
    );

    expect(find.byKey(_controlKey), findsOneWidget);

    // Structural, not visual: the control is not inside the scrollable, so
    // scrolling can never move it out of the viewport.
    expect(
      find.descendant(
        of: find.byType(ListView),
        matching: find.byKey(_controlKey),
      ),
      findsNothing,
    );
  });

  testWidgets('the control stays visible after ten entries and a scroll', (
    tester,
  ) async {
    await tester.pumpWidget(
      _build(
        entries: [for (var i = 0; i < 10; i++) _entry('$i')],
        controls: const SizedBox(key: _controlKey, height: 44),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_controlKey), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(find.byKey(_controlKey), findsOneWidget);
  });

  testWidgets('the same holds with reverse: false', (tester) async {
    await tester.pumpWidget(
      _build(
        entries: [for (var i = 0; i < 10; i++) _entry('$i')],
        controls: const SizedBox(key: _controlKey, height: 44),
        direction: ScrollDirection.topToBottom,
      ),
    );
    await tester.pumpAndSettle();

    final list = tester.widget<ListView>(find.byType(ListView));
    expect(list.reverse, isFalse);
    expect(find.byKey(_controlKey), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(find.byKey(_controlKey), findsOneWidget);
  });
}
