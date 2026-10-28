// Tests for Amendment 04 (BR-U10-46 to 48; TP-29): the language-pack section
// the on-device-unavailable panel embeds.
//
// Time is the widget tester's fake clock: `tester.pump(duration)` fires the
// 5 s re-check timer exactly as `fake_async` would.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/language_pack_providers.dart';
import 'package:zip_captions/src/widgets/language_pack_section.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_language_pack_service.dart';

const _strings = ZcStrings.fromMap({
  'languagePackDownload': 'dl-label {language}',
  'languagePackDownloadingPercent': 'dling-pct {language} {percent}',
  'languagePackDownloading': 'dling {language}',
  'languagePackScheduled': 'scheduled {language}',
  'languagePackReady': 'ready {language}',
  'languagePackFailed': 'failed {language}',
  'languagePackIosInstructions': 'ios-steps {language}',
});

const _locale = 'fr-CA';
const _name = 'French (Canada)';

Future<FakeLanguagePackService> _pump(
  WidgetTester tester, {
  TargetPlatform platform = TargetPlatform.android,
  int? osVersion = 34,
  LanguagePackStatus status = LanguagePackStatus.downloadable,
  FakeLanguagePackService? service,
}) async {
  final fake = (service ?? FakeLanguagePackService())
    ..setStatus(_locale, status, displayName: _name);
  addTearDown(fake.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        languagePackServiceProvider.overrideWithValue(fake),
        languagePackOsVersionProvider.overrideWithValue(osVersion),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: LanguagePackSection(
            localeId: _locale,
            strings: _strings,
            platform: platform,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return fake;
}

void main() {
  group('what each status shows (BR-U10-46)', () {
    testWidgets('downloadable: a Download button naming the language', (
      tester,
    ) async {
      final fake = await _pump(tester);

      expect(find.text('dl-label $_name'), findsOneWidget);
      expect(fake.statusCalls, [_locale]);
    });

    testWidgets('downloading at the first check: the scheduled state '
        '(BR-U10-47a)', (tester) async {
      final fake = await _pump(
        tester,
        status: LanguagePackStatus.downloading,
      );

      expect(find.text('scheduled $_name'), findsOneWidget);
      expect(find.text('dling $_name'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(fake.downloadCalls, isEmpty);
    });

    testWidgets('unsupported: nothing extra', (tester) async {
      await _pump(tester, status: LanguagePackStatus.unsupported);

      expect(find.byType(Text), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('installed at the first check: nothing extra', (tester) async {
      await _pump(tester, status: LanguagePackStatus.installed);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('Android unknown: nothing extra', (tester) async {
      await _pump(tester, status: LanguagePackStatus.unknown);

      expect(find.byType(Text), findsNothing);
    });

    testWidgets('iOS 26 unknown: the instructions', (tester) async {
      await _pump(
        tester,
        platform: TargetPlatform.iOS,
        osVersion: 26,
        status: LanguagePackStatus.unknown,
      );

      expect(find.text('ios-steps $_name'), findsOneWidget);
    });

    testWidgets('iOS 25: the instructions, whatever the status says', (
      tester,
    ) async {
      final fake = await _pump(
        tester,
        platform: TargetPlatform.iOS,
        osVersion: 25,
      );

      expect(find.text('ios-steps $_name'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
      expect(fake.downloadCalls, isEmpty);
    });

    testWidgets('iOS 26 downloadable: the Download button', (tester) async {
      await _pump(
        tester,
        platform: TargetPlatform.iOS,
        osVersion: 26,
      );

      expect(find.text('dl-label $_name'), findsOneWidget);
    });

    testWidgets('a status that throws is unknown, with the tag as name', (
      tester,
    ) async {
      final fake = FakeLanguagePackService()
        ..statusError = Exception('boom');
      addTearDown(fake.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languagePackServiceProvider.overrideWithValue(fake),
            languagePackOsVersionProvider.overrideWithValue(26),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LanguagePackSection(
                localeId: _locale,
                strings: _strings,
                platform: TargetPlatform.iOS,
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('ios-steps $_locale'), findsOneWidget);
    });
  });

  group('TP-29 user action only', () {
    testWidgets('no download call without a tap, even after time passes', (
      tester,
    ) async {
      final fake = await _pump(tester);

      await tester.pump(const Duration(minutes: 10));

      expect(fake.downloadCalls, isEmpty);
    });

    testWidgets('a tap starts one download for the locale', (tester) async {
      final fake = await _pump(tester);

      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      expect(fake.downloadCalls, [_locale]);
      expect(find.text('dling $_name'), findsOneWidget);
    });

    testWidgets('at most one download in flight: more taps do nothing', (
      tester,
    ) async {
      final gate = Completer<void>();
      final fake = FakeLanguagePackService()..downloadGate = gate.future;
      await _pump(tester, service: fake);

      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();
      // The button is gone while the download is in flight; a tap at its old
      // place hits nothing, and a second download is never requested.
      await tester.tap(find.byType(Scaffold), warnIfMissed: false);
      await tester.pump();

      expect(fake.downloadCalls, hasLength(1));
      gate.complete();
      await tester.pump();
      expect(fake.downloadCalls, hasLength(1));
    });

    testWidgets('a status of downloading never calls download', (
      tester,
    ) async {
      final fake = await _pump(
        tester,
        status: LanguagePackStatus.downloading,
      );
      fake.send(const LanguagePackProgress(_locale, percent: 10));
      await tester.pump();

      expect(fake.downloadCalls, isEmpty);
    });
  });

  group('the download states (BR-U10-47)', () {
    testWidgets('percent events drive the percent text and the bar', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackProgress(_locale, percent: 40));
      await tester.pump();

      expect(find.text('dling-pct $_name 40'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, closeTo(0.4, 1e-9));
    });

    testWidgets('a percent outside 0 to 100 is clamped', (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackProgress(_locale, percent: 140));
      await tester.pump();

      expect(find.text('dling-pct $_name 100'), findsOneWidget);
    });

    testWidgets('a progress event with no percent stays indeterminate', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackProgress(_locale));
      await tester.pump();

      expect(find.text('dling $_name'), findsOneWidget);
      final bar = tester.widget<LinearProgressIndicator>(
        find.byType(LinearProgressIndicator),
      );
      expect(bar.value, isNull);
    });

    testWidgets('events for another locale are ignored', (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake
        ..send(const LanguagePackDone('de-DE'))
        ..send(const LanguagePackFailed('de-DE', code: 3));
      await tester.pump();

      expect(find.text('dling $_name'), findsOneWidget);
    });

    testWidgets('a locale tag matches ignoring case and "_" versus "-"', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackDone('FR_ca'));
      await tester.pump();

      expect(find.text('ready $_name'), findsOneWidget);
    });

    testWidgets('done shows the ready state, with no Download button', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackDone(_locale));
      await tester.pump();

      expect(find.text('ready $_name'), findsOneWidget);
      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('failed shows the failure state', (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackFailed(_locale, code: 9));
      await tester.pump();

      expect(find.text('failed $_name'), findsOneWidget);
    });

    testWidgets('a download that throws shows the failure state', (
      tester,
    ) async {
      final fake = FakeLanguagePackService()
        ..downloadError = Exception('no network');
      await _pump(tester, service: fake);

      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      expect(find.text('failed $_name'), findsOneWidget);
    });
  });

  group('the re-check when no percent arrives (BR-U10-47)', () {
    testWidgets('re-checks the status every 5 seconds', (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();
      final before = fake.statusCalls.length;

      await tester.pump(const Duration(seconds: 4));
      expect(fake.statusCalls.length, before);

      await tester.pump(const Duration(seconds: 1));
      expect(fake.statusCalls.length, before + 1);

      await tester.pump(const Duration(seconds: 5));
      expect(fake.statusCalls.length, before + 2);
    });

    testWidgets('an installed re-check shows the ready state and stops', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.setStatus(_locale, LanguagePackStatus.installed, displayName: _name);
      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('ready $_name'), findsOneWidget);
      final calls = fake.statusCalls.length;
      await tester.pump(const Duration(seconds: 30));
      expect(fake.statusCalls.length, calls);
    });

    testWidgets('gives up after 5 minutes: the failure state', (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      await tester.pump(const Duration(minutes: 4, seconds: 55));
      expect(find.text('dling $_name'), findsOneWidget);

      await tester.pump(const Duration(seconds: 5));
      await tester.pump();

      expect(find.text('failed $_name'), findsOneWidget);
      final calls = fake.statusCalls.length;
      await tester.pump(const Duration(minutes: 1));
      expect(fake.statusCalls.length, calls);
    });

    testWidgets('a percent event ends the polling: the limit no longer applies',
        (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();
      fake.send(const LanguagePackProgress(_locale, percent: 5));
      await tester.pump();
      final calls = fake.statusCalls.length;

      await tester.pump(const Duration(minutes: 20));

      expect(fake.statusCalls.length, calls);
      expect(find.text('dling-pct $_name 5'), findsOneWidget);
    });

    testWidgets('a status of downloading at open does not poll (BR-U10-47a)', (
      tester,
    ) async {
      final fake = await _pump(
        tester,
        status: LanguagePackStatus.downloading,
      );
      final before = fake.statusCalls.length;

      await tester.pump(const Duration(minutes: 10));

      expect(fake.statusCalls.length, before);
      expect(find.text('scheduled $_name'), findsOneWidget);
      expect(find.text('failed $_name'), findsNothing);
    });

    testWidgets('a scheduled event: the scheduled text, never a failure', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackScheduled(_locale));
      await tester.pump();
      expect(find.text('scheduled $_name'), findsOneWidget);
      final calls = fake.statusCalls.length;

      await tester.pump(const Duration(minutes: 10));

      expect(find.text('scheduled $_name'), findsOneWidget);
      expect(find.text('failed $_name'), findsNothing);
      expect(fake.statusCalls.length, calls, reason: 'no re-check timer');
    });

    testWidgets('a scheduled event for another locale is ignored', (
      tester,
    ) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      fake.send(const LanguagePackScheduled('de-DE'));
      await tester.pump();

      expect(find.text('dling $_name'), findsOneWidget);
    });

    testWidgets('a download that sends no event at all fails after 5 minutes '
        '(Android 13)', (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      await tester.pump(const Duration(minutes: 5));
      await tester.pump();

      expect(find.text('failed $_name'), findsOneWidget);
      expect(fake.downloadCalls, [_locale]);
    });

    testWidgets('dispose cancels the timer', (tester) async {
      final fake = await _pump(tester);
      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      final calls = fake.statusCalls.length;
      await tester.pump(const Duration(minutes: 10));

      expect(fake.statusCalls.length, calls);
    });
  });

  group('log hygiene (TP-31, SECURITY-03)', () {
    testWidgets('the download flow logs no display name or locale text', (
      tester,
    ) async {
      final records = <LogRecord>[];
      Logger.root.level = Level.ALL;
      final sub = Logger.root.onRecord.listen(records.add);
      addTearDown(sub.cancel);
      final fake = FakeLanguagePackService()
        ..downloadError = Exception('secret words');
      await _pump(tester, service: fake);

      await tester.tap(find.text('dl-label $_name'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 5));

      expect(records, isNotEmpty, reason: 'a silent flow proves nothing');
      final text = records
          .map((r) => '${r.message} ${r.error} ${r.stackTrace}')
          .join('\n');
      expect(text, isNot(contains('French')));
      expect(text, isNot(contains('Canada')));
      expect(text, isNot(contains('secret words')));
      expect(text, isNot(contains(_locale)));
    });
  });
}
