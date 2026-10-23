import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/overlay_window_controller_provider.dart';
import 'package:zip_broadcast/src/widgets/external_display_controls.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart' hide Failed;

import '../helpers/fake_display_enumerator.dart';


/// A window service that never opens a real window.
class _StubWindow implements DesktopWindowService {
  @override
  bool get isSupported => true;
  @override
  Future<int> createWindow(String arguments) async => 1;
  @override
  Future<void> closeWindow(int windowId) async {}
  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async {}
  @override
  Future<void> setFrame(int windowId, Rect frame) async {}
  @override
  Future<void> show(int windowId) async {}
}

DisplayInfo _display(
  String id, {
  String label = '',
  bool isPrimary = false,
}) =>
    DisplayInfo(
      id: id,
      label: label,
      bounds: const Rect.fromLTWH(0, 0, 1920, 1080),
      scaleFactor: 1,
      isPrimary: isPrimary,
    );

void main() {
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pump(
    WidgetTester tester,
    ExternalDisplayStatus status, {
    List<DisplayInfo> displays = const [],
    OutputTargetSettings? settings,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        externalDisplayStatusProvider.overrideWith(
          (ref) => Stream.value(status),
        ),
        displayListProvider.overrideWith((ref) => Stream.value(displays)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            ZipBroadcastLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: ZipBroadcastLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(child: ExternalDisplayControls()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  OutputTargetSettings settings() =>
      container.read(outputTargetSettingsNotifierProvider);

  test('the real status provider replays the initial status', () async {
    final prefs = await SharedPreferences.getInstance();
    final window = _StubWindow();
    final enumerator = FakeDisplayEnumerator(
      initial: [_display('a', label: 'Projector', isPrimary: true)],
    );
    final controller = OverlayWindowController(
      windowService: window,
      enumerator: enumerator,
      handlerInstaller: (_) {},
      log: Logger('test.controls'),
    );
    addTearDown(controller.dispose);

    final real = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        overlayWindowControllerProvider.overrideWithValue(controller),
      ],
    );
    addTearDown(real.dispose);

    // The controller starts Off and emits nothing until a transition.
    expect(controller.status, isA<Off>());
    final first = await real.read(externalDisplayStatusProvider.future);
    expect(first, isA<Off>());
  });

  testWidgets('Unsupported renders nothing at all', (tester) async {
    await pump(tester, const Unsupported());

    expect(find.byType(ExternalDisplayControls), findsOneWidget);
    expect(find.text('External Display'), findsNothing);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('NoDisplays explains the situation without controls',
      (tester) async {
    await pump(tester, const NoDisplays());

    expect(find.text('External Display'), findsOneWidget);
    expect(find.text('No displays detected'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets('Off lists displays with a fallback name, meta and position '
      'selector', (tester) async {
    await pump(
      tester,
      const Off(),
      displays: [_display('a', label: 'Left', isPrimary: true), _display('b')],
    );

    expect(find.text('Available Displays'), findsOneWidget);
    expect(find.text('Left'), findsOneWidget);
    expect(find.text('Display 2'), findsOneWidget);
    expect(find.textContaining('1920'), findsWidgets);
    expect(find.text('Caption Position'), findsOneWidget);
    expect(find.text('Top'), findsOneWidget);
    expect(find.text('Bottom'), findsOneWidget);
  });

  testWidgets('Opening shows the selected row opening', (tester) async {
    await pump(
      tester,
      const Opening(),
      displays: [_display('a', label: 'Left', isPrimary: true)],
    );

    expect(find.text('opening'), findsOneWidget);
  });

  testWidgets('Open highlights the active display and keeps the selector live',
      (tester) async {
    await pump(
      tester,
      const Open(activity: OverlayActivity.live, displayId: 'a'),
      displays: [_display('a', label: 'Left', isPrimary: true)],
    );

    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Top'), findsOneWidget);
  });

  testWidgets('WaitingForDisplay banners, names the status and offers Cancel',
      (tester) async {
    await pump(
      tester,
      const WaitingForDisplay(displayId: 'a'),
      displays: [_display('a', label: 'Left')],
    );

    expect(find.textContaining('was disconnected'), findsOneWidget);
    expect(find.text('waiting for display'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Cancel switches the output off and keeps the chosen display',
      (tester) async {
    await pump(
      tester,
      const WaitingForDisplay(displayId: 'a'),
      displays: [_display('a', label: 'Left')],
    );
    await container
        .read(outputTargetSettingsNotifierProvider.notifier)
        .update(
          settings().copyWith(
            overlayEnabled: true,
            externalDisplayId: 'a',
          ),
        );

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(settings().overlayEnabled, isFalse);
    expect(settings().externalDisplayId, 'a');
  });

  testWidgets('Failed shows fixed copy and never the raw reason',
      (tester) async {
    await pump(tester, const Failed(reason: 'create_failed'));

    expect(find.textContaining('could not be opened'), findsOneWidget);
    expect(find.textContaining('create_failed'), findsNothing);
  });

  testWidgets('the caption position selector writes the setting',
      (tester) async {
    await pump(
      tester,
      const Off(),
      displays: [_display('a', label: 'Left', isPrimary: true)],
    );

    await tester.tap(find.text('Top'));
    await tester.pumpAndSettle();

    expect(settings().externalDisplayCaptionPosition, CaptionPosition.top);
  });

  testWidgets('toggling a row on writes the id and enables the output once',
      (tester) async {
    await pump(
      tester,
      const Off(),
      displays: [_display('a', label: 'Left', isPrimary: true)],
    );

    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(settings().externalDisplayId, 'a');
    expect(settings().overlayEnabled, isTrue);
  });
}
