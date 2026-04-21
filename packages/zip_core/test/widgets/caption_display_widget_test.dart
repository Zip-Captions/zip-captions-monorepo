import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zip_core/src/models/caption_display_entry.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/widgets/caption_display_widget.dart';

CaptionDisplayEntry _entry(String text, {bool isFinal = true}) =>
    CaptionDisplayEntry(
      entryId: text,
      sessionId: 'session',
      text: text,
      isFinal: isFinal,
      sourceId: 'default',
      timestamp: DateTime.utc(2024),
    );

DisplaySettings _settings(ScrollDirection dir) => DisplaySettings(
      scrollDirection: dir,
      captionTextSize: CaptionTextSize.md,
      captionFont: CaptionFont.atkinsonHyperlegible,
      themeModeSetting: ThemeModeSetting.system,
      maxVisibleLines: 0,
    );

Widget _wrap(List<CaptionDisplayEntry> entries, DisplaySettings settings) =>
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: CaptionDisplayWidget(entries: entries, settings: settings),
        ),
      ),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CaptionDisplayWidget — scroll direction', () {
    group('bottomToTop (↑ New)', () {
      testWidgets('single interim entry renders at visual bottom',
          (tester) async {
        await tester.pumpWidget(
          _wrap(
            [_entry('Alpha', isFinal: false)],
            _settings(ScrollDirection.bottomToTop),
          ),
        );
        await tester.pump();
        final viewportHeight = tester.getSize(find.byType(Scaffold)).height;
        final itemCenter = tester.getCenter(find.text('Alpha')).dy;
        expect(itemCenter, greaterThan(viewportHeight / 2));
      });

      testWidgets('interim renders below its preceding final', (tester) async {
        await tester.pumpWidget(
          _wrap(
            [_entry('Final'), _entry('Interim', isFinal: false)],
            _settings(ScrollDirection.bottomToTop),
          ),
        );
        await tester.pump();
        final finalY = tester.getCenter(find.text('Final')).dy;
        final interimY = tester.getCenter(find.text('Interim')).dy;
        expect(interimY, greaterThan(finalY));
      });

      testWidgets(
          'finals ordered oldest-top to newest-bottom, interim at very bottom',
          (tester) async {
        await tester.pumpWidget(
          _wrap(
            [_entry('A'), _entry('B'), _entry('C', isFinal: false)],
            _settings(ScrollDirection.bottomToTop),
          ),
        );
        await tester.pump();
        final aY = tester.getCenter(find.text('A')).dy;
        final bY = tester.getCenter(find.text('B')).dy;
        final cY = tester.getCenter(find.text('C')).dy;
        expect(aY, lessThan(bY));
        expect(bY, lessThan(cY));
      });
    });

    group('topToBottom (↓ New)', () {
      testWidgets('single interim entry renders at visual top', (tester) async {
        await tester.pumpWidget(
          _wrap(
            [_entry('Alpha', isFinal: false)],
            _settings(ScrollDirection.topToBottom),
          ),
        );
        await tester.pump();
        final viewportHeight = tester.getSize(find.byType(Scaffold)).height;
        final itemCenter = tester.getCenter(find.text('Alpha')).dy;
        expect(itemCenter, lessThan(viewportHeight / 2));
      });

      testWidgets('interim renders above its preceding final', (tester) async {
        await tester.pumpWidget(
          _wrap(
            [_entry('Final'), _entry('Interim', isFinal: false)],
            _settings(ScrollDirection.topToBottom),
          ),
        );
        await tester.pump();
        final finalY = tester.getCenter(find.text('Final')).dy;
        final interimY = tester.getCenter(find.text('Interim')).dy;
        expect(interimY, lessThan(finalY));
      });

      testWidgets(
          'interim at very top, newest final below, oldest final at bottom',
          (tester) async {
        await tester.pumpWidget(
          _wrap(
            [_entry('A'), _entry('B'), _entry('C', isFinal: false)],
            _settings(ScrollDirection.topToBottom),
          ),
        );
        await tester.pump();
        final aY = tester.getCenter(find.text('A')).dy;
        final bY = tester.getCenter(find.text('B')).dy;
        final cY = tester.getCenter(find.text('C')).dy;
        expect(cY, lessThan(bY));
        expect(bY, lessThan(aY));
      });
    });
  });
}
