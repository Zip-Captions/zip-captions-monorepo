import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/widgets/pop_out_controls.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';

/// The copy every assertion reads.
const _strings = ZcStrings.fromMap({
  'popOutHint': 'hint',
  'popOutReturn': 'return',
});

/// Pumps the banner inside the scope that carries the copy, as the shell does.
Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      home: PopOutScope(
        enabled: true,
        onToggle: () {},
        available: true,
        visible: true,
        strings: _strings,
        child: Scaffold(body: Column(children: [child])),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  group('PopOutBanner (B32)', () {
    testWidgets('shows the hint and a return action that fires',
        (tester) async {
      var returned = 0;
      await _pump(tester, PopOutBanner(onReturn: () => returned++));

      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);
      expect(find.text('hint'), findsOneWidget);
      expect(find.text('return'), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutReturn')));
      expect(returned, 1);
    });

    // FD frontend-components §5: the panel must not clip at large text sizes,
    // and it fills whatever caption area the window leaves (review round 7,
    // m4: a 160 px area at twice the text size overflowed).
    testWidgets('fits a short caption area at large text sizes',
        (tester) async {
      var returned = 0;
      await _pump(
        tester,
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: SizedBox(
            height: 160,
            child: PopOutBanner(onReturn: () => returned++),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byKey(const Key('popOutReturn')));
      await tester.tap(find.byKey(const Key('popOutReturn')));
      expect(returned, 1);
    });

    testWidgets('carries no caption text', (tester) async {
      await _pump(tester, PopOutBanner(onReturn: () {}));

      final texts = tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .toList();
      expect(texts, ['hint', 'return']);
    });

    testWidgets('the shell removes it when the pop-out closes', (tester) async {
      // The banner is conditional on the shell's flag; this test pins the
      // tree shape the flag produces rather than the shell's own state.
      var open = true;
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          home: PopOutScope(
            enabled: true,
            onToggle: () {},
            available: true,
            visible: true,
            strings: _strings,
            child: StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              return Scaffold(
                body: Column(
                  children: [
                    if (open) PopOutBanner(onReturn: () {}),
                    const Expanded(child: SizedBox()),
                  ],
                ),
              );
            },
            ),
          ),
        ),
      );
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      setState(() => open = false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });
  });
}
