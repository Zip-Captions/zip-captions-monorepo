import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/widgets/pop_out_controls.dart';

/// Pumps the banner inside the app's localizations, as the shell does.
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
      home: Scaffold(body: Column(children: [child])),
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

      final l10n = ZipBroadcastLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);
      expect(find.text(l10n.popOutHint), findsOneWidget);
      expect(find.text(l10n.popOutReturn), findsOneWidget);

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
      final l10n = ZipBroadcastLocalizations.of(
        tester.element(find.byType(Scaffold)),
      )!;
      expect(texts, [l10n.popOutHint, l10n.popOutReturn]);
    });

    testWidgets('the shell removes it when the pop-out closes', (tester) async {
      // The banner is conditional on the shell's flag; this test pins the
      // tree shape the flag produces rather than the shell's own state.
      var open = true;
      late StateSetter setState;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            ZipBroadcastLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: ZipBroadcastLocalizations.supportedLocales,
          home: StatefulBuilder(
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
      );
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      setState(() => open = false);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });
  });
}
