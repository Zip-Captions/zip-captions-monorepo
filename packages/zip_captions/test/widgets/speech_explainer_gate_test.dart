// Tests for Unit 10, P8 / TP-19 (BR-U10-33): the iOS speech explainer gate.
//
// The ordering guarantee is the point: on iOS, `start()` is unreachable until
// the explainer has been acknowledged. On Android there is no explainer at all.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/widgets/speech_explainer_gate.dart';
import 'package:zip_core/zip_core.dart';

const String _seenKey = SpeechExplainerGate.seenKey;

const _strings = ZcStrings.fromMap({
  'speechExplainerTitle': 'explainer-title',
  'speechExplainerBody': 'explainer-body',
  'speechExplainerContinue': 'explainer-continue',
  'speechExplainerNotNow': 'explainer-not-now',
});

/// Preferences whose `setBool` waits for [gate], so a test can hold the write
/// open. Every other member throws if called ([Fake]).
class _SlowPrefs extends Fake implements SharedPreferences {
  final gate = Completer<bool>();
  int writes = 0;

  @override
  bool? getBool(String key) => null;

  @override
  Future<bool> setBool(String key, bool value) {
    writes++;
    return gate.future;
  }
}

void main() {
  late SharedPreferences prefs;
  late int starts;
  late int backToHome;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
    starts = 0;
    backToHome = 0;
  });

  var visits = 0;

  Future<void> pumpGate(
    WidgetTester tester, {
    required TargetPlatform platform,
  }) async {
    visits++;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          zcStringsProvider.overrideWith((ref) async => _strings),
        ],
        child: MaterialApp(
          home: SpeechExplainerGate(
            key: ValueKey('gate-$visits'),
            platform: platform,
            strings: _strings,
            onStart: () async => starts++,
            onBackToHome: () => backToHome++,
            builder: (context) => const Scaffold(body: Text('captions')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('SpeechExplainerGate (TP-19)', () {
    testWidgets('on iOS start() is not called before the explainer is shown', (
      tester,
    ) async {
      await pumpGate(tester, platform: TargetPlatform.iOS);

      expect(starts, 0);
      expect(find.text('explainer-title'), findsOneWidget);
      expect(find.text('captions'), findsNothing);
    });

    testWidgets('Android never shows the explainer and starts at once', (
      tester,
    ) async {
      await pumpGate(tester, platform: TargetPlatform.android);

      expect(find.text('explainer-title'), findsNothing);
      expect(starts, 1);
      expect(find.text('captions'), findsOneWidget);
    });

    testWidgets('Continue sets the flag, starts, and is not shown again', (
      tester,
    ) async {
      await pumpGate(tester, platform: TargetPlatform.iOS);

      await tester.tap(find.text('explainer-continue'));
      await tester.pumpAndSettle();

      expect(starts, 1);
      expect(prefs.getBool(_seenKey), isTrue);

      // A second visit goes straight through.
      await pumpGate(tester, platform: TargetPlatform.iOS);
      expect(find.text('explainer-title'), findsNothing);
      expect(starts, 2);
    });

    testWidgets('a cleared flag shows the explainer again', (tester) async {
      await prefs.setBool(_seenKey, false);
      await pumpGate(tester, platform: TargetPlatform.iOS);

      expect(find.text('explainer-title'), findsOneWidget);
      expect(starts, 0);
    });

    testWidgets('"Not now" sets no flag, starts nothing and returns to Home', (
      tester,
    ) async {
      await pumpGate(tester, platform: TargetPlatform.iOS);

      await tester.tap(find.text('explainer-not-now'));
      await tester.pumpAndSettle();

      expect(starts, 0);
      expect(backToHome, 1);
      expect(prefs.getBool(_seenKey), isNull);
    });

    group('while Continue is writing the flag', () {
      Future<_SlowPrefs> pumpSlow(WidgetTester tester) async {
        final slow = _SlowPrefs();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [sharedPreferencesProvider.overrideWithValue(slow)],
            child: MaterialApp(
              home: SpeechExplainerGate(
                platform: TargetPlatform.iOS,
                strings: _strings,
                onStart: () async => starts++,
                onBackToHome: () => backToHome++,
                builder: (context) => const Scaffold(body: Text('captions')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return slow;
      }

      testWidgets('both buttons are disabled', (tester) async {
        final slow = await pumpSlow(tester);

        await tester.tap(find.text('explainer-continue'));
        await tester.pump();

        expect(slow.writes, 1);
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNull,
        );
        slow.gate.complete(true);
        await tester.pumpAndSettle();
      });

      testWidgets('a second Continue writes nothing more and "Not now" '
          'records and does nothing', (tester) async {
        final slow = await pumpSlow(tester);

        await tester.tap(find.text('explainer-continue'));
        await tester.pump();
        await tester.tap(find.text('explainer-continue'), warnIfMissed: false);
        await tester.tap(find.text('explainer-not-now'), warnIfMissed: false);
        await tester.pump();

        expect(slow.writes, 1, reason: 'one write only');
        expect(backToHome, 0, reason: 'Not now did nothing');
        expect(starts, 0, reason: 'nothing starts before the write lands');

        slow.gate.complete(true);
        await tester.pumpAndSettle();

        expect(starts, 1);
        expect(backToHome, 0);
        expect(find.text('captions'), findsOneWidget);
      });

      testWidgets('a failed write re-enables the buttons', (tester) async {
        final slow = await pumpSlow(tester);

        await tester.tap(find.text('explainer-continue'));
        await tester.pump();
        slow.gate.completeError(StateError('disk full'));
        await tester.pump();

        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(
          tester.widget<TextButton>(find.byType(TextButton)).onPressed,
          isNotNull,
        );
        expect(starts, 0);
      });
    });

    testWidgets('macOS and desktop never show it either', (tester) async {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      ]) {
        starts = 0;
        await pumpGate(tester, platform: platform);
        await tester.pumpAndSettle();
        expect(find.text('explainer-title'), findsNothing, reason: '$platform');
        expect(starts, 1, reason: '$platform');
      }
    });

    testWidgets('the body copy comes from the strings', (tester) async {
      await pumpGate(tester, platform: TargetPlatform.iOS);

      expect(find.text('explainer-body'), findsOneWidget);
    });
  });
}
