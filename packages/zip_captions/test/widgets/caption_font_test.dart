import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zip_core/zip_core.dart';

CaptionDisplayEntry _entry(String text) => CaptionDisplayEntry(
      entryId: text,
      sessionId: 'session',
      text: text,
      isFinal: true,
      sourceId: 'default',
      timestamp: DateTime.utc(2024),
    );

DisplaySettings _settings(CaptionFont font) => DisplaySettings(
      scrollDirection: ScrollDirection.bottomToTop,
      captionTextSize: CaptionTextSize.md,
      captionFont: font,
      themeModeSetting: ThemeModeSetting.system,
      maxVisibleLines: 0,
    );

Widget _wrap(CaptionFont font) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptionDisplayWidget(
            entries: [_entry('Sample caption text')],
            settings: _settings(font),
          ),
        ),
      ),
    );

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('caption fonts — bundled assets load without error', () {
    for (final font in CaptionFont.values) {
      testWidgets(font.fontFamily, (tester) async {
        await tester.pumpWidget(_wrap(font));
        await tester.pumpAndSettle();
        expect(find.text('Sample caption text'), findsOneWidget);
        final text =
            tester.widget<Text>(find.text('Sample caption text'));
        expect(
          text.style?.fontFamily,
          GoogleFonts.getFont(font.fontFamily, fontWeight: FontWeight.w500)
              .fontFamily,
          reason: 'CaptionDisplayWidget must apply ${font.fontFamily}',
        );
      });
    }
  });

  group('caption font weight', () {
    testWidgets(
        'caption text renders at w500 (matches text theme)',
        (tester) async {
      await tester.pumpWidget(_wrap(CaptionFont.poppins));
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Sample caption text'));
      expect(text.style?.fontWeight, FontWeight.w500);
    });
  });
}
