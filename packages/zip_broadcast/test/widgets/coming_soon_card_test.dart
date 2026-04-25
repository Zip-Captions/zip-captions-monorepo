import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/widgets/coming_soon_card.dart';

Widget _wrap(Widget child) => MaterialApp(
      localizationsDelegates: const [
        ZipBroadcastLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: ZipBroadcastLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  group('ComingSoonCard', () {
    testWidgets('renders label and Coming soon badge', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ComingSoonCard(
            icon: Icons.people_outlined,
            label: 'Remote Viewers',
          ),
        ),
      );

      expect(find.text('Remote Viewers'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
    });

    testWidgets('semantic label contains label and Coming soon',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ComingSoonCard(
            icon: Icons.people_outlined,
            label: 'Remote Viewers',
          ),
        ),
      );

      final semantics = tester.getSemantics(find.byType(ComingSoonCard));
      expect(semantics.label, contains('Remote Viewers'));
      expect(semantics.label, contains('Coming soon'));
    });

    testWidgets('ComingSoonCard ListTile is disabled (not interactive)',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ComingSoonCard(
            icon: Icons.people_outlined,
            label: 'Remote Viewers',
          ),
        ),
      );

      // ListTile with enabled: false has no onTap handler.
      final tile = tester.widget<ListTile>(find.byType(ListTile));
      expect(tile.enabled, isFalse);
      expect(tile.onTap, isNull);
    });

    testWidgets('optional subtitle is shown when provided', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const ComingSoonCard(
            icon: Icons.people_outlined,
            label: 'Remote Viewers',
            subtitle: 'Phase 2',
          ),
        ),
      );

      expect(find.text('Phase 2'), findsOneWidget);
    });
  });
}
