/// Widget tests verifying that RecordingScreen wires displaySettingsProvider
/// through to CaptionDisplayWidget.
///
/// Regression coverage for the R1 bug where font and scroll direction settings
/// had no effect on the caption display.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_captions/src/screens/recording_screen.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/fake_recording_state_notifier.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

GoRouter _router() => GoRouter(
      initialLocation: '/recording',
      routes: [
        GoRoute(path: '/', builder: (ctx, s) => const SizedBox()),
        GoRoute(
          path: '/recording',
          builder: (ctx, s) => const RecordingScreen(),
        ),
        GoRoute(path: '/history', builder: (ctx, s) => const SizedBox()),
      ],
    );

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Map<String, Object> prefsValues = const {},
}) async {
  GoogleFonts.config.allowRuntimeFetching = false;
  SharedPreferences.setMockInitialValues(prefsValues);
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        recordingStateNotifierProvider.overrideWith(
          () => FakeRecordingStateNotifier(
            const RecordingState.recording(sessionId: 'test'),
          ),
        ),
        onScreenCaptionTargetProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
      ],
      child: MaterialApp.router(routerConfig: _router()),
    ),
  );
  await tester.pumpAndSettle();

  return ProviderScope.containerOf(
    tester.element(find.byType(RecordingScreen)),
  );
}

CaptionDisplayWidget _captionWidget(WidgetTester tester) =>
    tester.widget<CaptionDisplayWidget>(find.byType(CaptionDisplayWidget));

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RecordingScreen — display settings provider chain', () {
    testWidgets(
        'non-default font stored in prefs is passed to CaptionDisplayWidget',
        (tester) async {
      await _pump(tester, prefsValues: {
        'zip_captions.display_settings.captionFont': 'poppins',
      });

      expect(
        _captionWidget(tester).settings.captionFont,
        equals(CaptionFont.poppins),
      );
    });

    testWidgets(
        'changing font via notifier rebuilds CaptionDisplayWidget '
        'with new font',
        (tester) async {
      final container = await _pump(tester);

      expect(
        _captionWidget(tester).settings.captionFont,
        equals(CaptionFont.atkinsonHyperlegible),
      );

      await container
          .read(displaySettingsProvider.notifier)
          .setCaptionFont(CaptionFont.poppins);
      await tester.pumpAndSettle();

      expect(
        _captionWidget(tester).settings.captionFont,
        equals(CaptionFont.poppins),
      );
    });

    testWidgets(
        'non-default scroll direction stored in prefs is passed '
        'to CaptionDisplayWidget',
        (tester) async {
      await _pump(tester, prefsValues: {
        'zip_captions.display_settings.scrollDirection': 'topToBottom',
      });

      expect(
        _captionWidget(tester).settings.scrollDirection,
        equals(ScrollDirection.topToBottom),
      );
    });

    testWidgets(
        'changing scroll direction via notifier rebuilds CaptionDisplayWidget',
        (tester) async {
      final container = await _pump(tester);

      expect(
        _captionWidget(tester).settings.scrollDirection,
        equals(ScrollDirection.bottomToTop),
      );

      await container
          .read(displaySettingsProvider.notifier)
          .setScrollDirection(ScrollDirection.topToBottom);
      await tester.pumpAndSettle();

      expect(
        _captionWidget(tester).settings.scrollDirection,
        equals(ScrollDirection.topToBottom),
      );
    });
  });
}
