import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/viewer_announcer_provider.dart';
import 'package:zip_captions/src/routing/zc_router.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/viewer_test_harness.dart';

/// Pumps the real [zcRouter] at [location] with the viewer's collaborators
/// faked, so shell chrome assertions describe the production route table.
Future<void> _pump(
  WidgetTester tester,
  String location, {
  Size physicalSize = const Size(375, 812),
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = physicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sentinelStringsOverride(),
        sharedPreferencesProvider.overrideWithValue(prefs),
        transcriptWriterTargetProvider.overrideWith((_) {}),
        broadcastResolverProvider.overrideWithValue(
          FakeViewerResolver([const BroadcastResolution.notFound()]),
        ),
        signalingServiceProvider.overrideWithValue(
          FakeViewerSignalingService(),
        ),
        iceServerProviderProvider.overrideWithValue(
          FakeViewerIceServerProvider(),
        ),
        viewerAnnouncerProvider.overrideWithValue((view, message) {}),
        ...overrides,
      ],
      child: MaterialApp.router(routerConfig: zcRouter),
    ),
  );
  zcRouter.go(location);
  await tester.pumpAndSettle();
}

void main() {
  group('zcRouter — viewer routes (harness-drift guard)', () {
    for (final size in const [Size(375, 812), Size(1200, 800)]) {
      testWidgets('/b/:id renders no shell chrome at $size', (tester) async {
        await _pump(tester, '/b/K7M9X2', physicalSize: size);

        expect(find.byType(Drawer), findsNothing);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byIcon(Icons.menu), findsNothing);
      });

      testWidgets('/join is in the shell at $size', (tester) async {
        await _pump(tester, '/join', physicalSize: size);

        final inShell =
            find.byType(NavigationRail).evaluate().isNotEmpty ||
            find.byIcon(Icons.menu).evaluate().isNotEmpty;
        expect(inShell, isTrue);
      });
    }

    testWidgets('/join shows the ARB Join title in the shell app bar', (
      tester,
    ) async {
      await _pump(
        tester,
        '/join',
        overrides: [
          zcStringsProvider.overrideWith(
            (ref) async => const ZcStrings.fromMap({
              'joinBroadcastSubmit': 'SENTINEL-SHELL-JOIN',
            }),
          ),
        ],
      );

      expect(
        find.widgetWithText(AppBar, 'SENTINEL-SHELL-JOIN'),
        findsOneWidget,
      );
    });
  });
}
