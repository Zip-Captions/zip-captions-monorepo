/// Widget tests for CaptionDisplayWidget scroll direction rendering.
///
/// Regression coverage for the R1 bug where new-at-bottom did not pin to
/// bottom and new-at-top did not render in reverse-chronological order.
library;

import 'package:flutter/material.dart' hide ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:zip_core/src/models/caption_display_entry.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/theme/app_theme.dart';
import 'package:zip_core/src/widgets/caption_display_widget.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

CaptionDisplayEntry _entry(String text) => CaptionDisplayEntry(
      entryId: text,
      sessionId: 'session',
      text: text,
      isFinal: true,
      sourceId: 'default',
      timestamp: DateTime.utc(2024),
    );

Widget _wrap(ScrollDirection dir) => ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: CaptionDisplayWidget(
            entries: [_entry('first'), _entry('second')],
            settings: DisplaySettings(
              scrollDirection: dir,
              captionTextSize: CaptionTextSize.md,
              captionFont: CaptionFont.atkinsonHyperlegible,
              themeModeSetting: ThemeModeSetting.system,
              maxVisibleLines: 0,
            ),
          ),
        ),
      ),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('CaptionDisplayWidget — scroll direction', () {
    testWidgets(
        'bottomToTop: oldest entry renders above newest (new captions pin to bottom)',
        (tester) async {
      await tester.pumpWidget(_wrap(ScrollDirection.bottomToTop));
      await tester.pumpAndSettle();

      final firstDy = tester.getCenter(find.text('first')).dy;
      final secondDy = tester.getCenter(find.text('second')).dy;

      // "first" (oldest) must be higher on screen (lower dy) than
      // "second" (newest) which is pinned to the bottom.
      expect(
        firstDy,
        lessThan(secondDy),
        reason: '"first" (oldest) should appear above "second" (newest) '
            'in bottomToTop mode',
      );
    });

    testWidgets(
        'topToBottom: newest entry renders above oldest (new captions pin to top)',
        (tester) async {
      await tester.pumpWidget(_wrap(ScrollDirection.topToBottom));
      await tester.pumpAndSettle();

      final firstDy = tester.getCenter(find.text('first')).dy;
      final secondDy = tester.getCenter(find.text('second')).dy;

      // "second" (newest) must be higher on screen (lower dy) than
      // "first" (oldest) in reverse-chronological top-pinned mode.
      expect(
        secondDy,
        lessThan(firstDy),
        reason: '"second" (newest) should appear above "first" (oldest) '
            'in topToBottom mode',
      );
    });
  });
}
