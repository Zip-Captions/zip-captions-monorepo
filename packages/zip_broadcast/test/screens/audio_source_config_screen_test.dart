import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';

import '../helpers/fake_notifiers.dart';
import '../helpers/zb_test_harness.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AudioSourceConfigScreen', () {
    testWidgets('shows one card per AudioInputConfig', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/audio-inputs',
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeTwoInputAudioInputConfigNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Two cards + one Add button = 3 items; cards show 'Input 1', 'Input 2'.
      expect(find.text('Input 1'), findsOneWidget);
      expect(find.text('Input 2'), findsOneWidget);
    });

    testWidgets('shows empty state text when no inputs configured',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/audio-inputs',
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeEmptyAudioInputConfigNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No audio inputs configured.'), findsOneWidget);
    });

    testWidgets('Add Audio Input button visible when inputs present',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/audio-inputs',
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeOneInputAudioInputConfigNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Audio Input'), findsOneWidget);
    });

    testWidgets('each card has a Remove button', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/audio-inputs',
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeTwoInputAudioInputConfigNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Remove'), findsNWidgets(2));
    });

    testWidgets('each card shows Speaker label text field', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/audio-inputs',
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeOneInputAudioInputConfigNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Speaker label'), findsOneWidget);
    });

    testWidgets('colour swatches rendered per card', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        buildZbApp(
          prefs: prefs,
          initialLocation: '/audio-inputs',
          overrides: [
            audioInputConfigNotifierProvider
                .overrideWith(FakeOneInputAudioInputConfigNotifier.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // AudioInputVisualStyle.count == 4 swatches per card.
      expect(find.text('Colour'), findsOneWidget);
      // Each swatch is an InkWell with a Semantics button label.
      expect(
        find.bySemanticsLabel(RegExp(r'^Colour \d$')),
        findsNWidgets(4),
      );
    });
  });
}
