import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_broadcast/src/providers/overlay_window_controller_provider.dart';
import 'package:zip_broadcast/src/widgets/pop_out_controls.dart';
import 'package:zip_broadcast/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';

import '../helpers/fake_display_enumerator.dart';
import '../helpers/fake_notifiers.dart';
import '../helpers/zb_test_harness.dart';

/// A window service that records instead of creating.
class _Window implements DesktopWindowService {
  final List<String> calls = <String>[];
  int _next = 41;

  @override
  bool get isSupported => true;

  /// Completes the ready handshake for the id about to be returned.
  void Function(int windowId)? onCreated;

  @override
  Future<int> createWindow(String arguments) async {
    calls.add('createWindow');
    final id = _next++;
    onCreated?.call(id);
    return id;
  }

  @override
  Future<void> closeWindow(int windowId) async => calls.add('closeWindow');

  @override
  Future<void> invokeMethod(
    int windowId,
    String method,
    dynamic arguments,
  ) async =>
      calls.add('invokeMethod:$method');

  @override
  Future<void> setFrame(int windowId, Rect frame) async =>
      calls.add('setFrame');

  @override
  Future<void> show(int windowId) async => calls.add('show');
}

class _Handler {
  OverlayMethodHandler? handler;

  // Named as a method, matching this project's `_FakeAuthNotifier.setState`
  // precedent, not a setter.
  // ignore: use_setters_to_change_properties
  void install(OverlayMethodHandler? next) => handler = next;
}

const _display = DisplayInfo(
  id: 'primary',
  label: 'Primary',
  bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: true,
);

/// Holds the controller so the test can close the window the way the
/// platform does — through the router's `windowClosed` handler.
class _Graph {
  _Graph({this.display = true})
      : window = _Window(),
        enumerator = FakeDisplayEnumerator(
          initial: display ? [_display] : const <DisplayInfo>[],
        ) {
    controller = OverlayWindowController(
      windowService: window,
      enumerator: enumerator,
      handlerInstaller: handler.install,
      log: Logger('test.popOutShell'),
      mode: const PopOutMode(),
    );
    // The open only leaves `Opening` when the window reports ready; the
    // service's creation hook stands in for the sub-window's entry point.
    // `overlayReady` is a post-frame message: the controller's bootstrap
    // records the window id when `createWindow`'s future completes, so the
    // stub defers one frame, as the real sub-engine does.
    window.onCreated = (id) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(handler.handler!('overlayReady', id)),
      );
      WidgetsBinding.instance.ensureVisualUpdate();
    };
  }

  final _Window window;
  final FakeDisplayEnumerator enumerator;

  /// The display list the shell's geometry reads, seeded from the same fake.
  List<DisplayInfo> get displayList =>
      display ? const [_display] : const <DisplayInfo>[];

  /// Whether the fake was seeded with a display.
  final bool display;
  final _Handler handler = _Handler();
  late final OverlayWindowController controller;

  /// The platform's own close notification, as the runner raises it: the
  /// main-engine close channel, delivered to the controller's native-close
  /// seam (`closeChannel`), not through the method router.
  void windowGone() => controller.onNativeWindowClosed(controller.windowId!);
}

Future<_Graph> _pumpRecording(
  WidgetTester tester, {
  bool display = true,
  bool engine = true,
}) async {
  final graph = _Graph(display: display);
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    buildZbApp(
      prefs: prefs,
      initialLocation: '/recording',
      popOutController: graph.controller,
      overrides: [
        externalDisplayStatusProvider.overrideWith(
          (ref) => Stream<ExternalDisplayStatus>.value(const Off()),
        ),
        displayListProvider.overrideWith(
          (ref) => Stream<List<DisplayInfo>>.value(graph.displayList),
        ),
        broadcastRecordingNotifierProvider.overrideWith(
          FakeActiveBroadcastRecordingNotifier.new,
        ),
        obsConnectionNotifierProvider
            .overrideWith(FakeDisconnectedObsConnectionNotifier.new),
        audioInputConfigNotifierProvider.overrideWith(
          engine
              ? FakeOneInputAudioInputConfigNotifier.new
              : FakeEmptyAudioInputConfigNotifier.new,
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  return graph;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('pop-out shell wiring (B30)', () {
    testWidgets('the chrome toggle opens one window and flips the label',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(graph.window.calls.where((c) => c == 'createWindow'), hasLength(1));
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);
    });

    testWidgets('a second toggle while opening creates no second window',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();

      expect(graph.window.calls.where((c) => c == 'createWindow'), hasLength(1));
    });

    testWidgets('the banner return closes the window and clears the banner',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      await tester.tap(find.byKey(const Key('popOutReturn')));
      await tester.pumpAndSettle();

      expect(graph.window.calls, contains('closeWindow'));
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    testWidgets('a window that goes away on its own clears the banner',
        (tester) async {
      final graph = await _pumpRecording(tester);

      await tester.tap(find.byKey(const Key('popOutInSurfaceToggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('popOutBanner')), findsOneWidget);

      graph.windowGone();
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });

    testWidgets('no engine disables the chrome toggle with its reason',
        (tester) async {
      await _pumpRecording(tester, engine: false);

      final toggle = tester.widget<TextButton>(
        find.byKey(const Key('popOutToggle')),
      );
      expect(toggle.onPressed, isNull);
      expect(find.byKey(const Key('popOutToggleReason')), findsOneWidget);
      // The in-surface toggle sits inside the caption surface and stays usable:
      // the window exists only because a session is running.
      final surface = tester.widget<PopOutInSurfaceToggle>(
        find.byType(PopOutInSurfaceToggle),
      );
      expect(surface.enabled, isTrue);
    });

    testWidgets('the scope carries the flag and the toggle to the screen',
        (tester) async {
      await _pumpRecording(tester);

      final scope = tester.widget<PopOutScope>(find.byType(PopOutScope));
      expect(scope.enabled, isFalse);
      expect(find.byKey(const Key('popOutBanner')), findsNothing);
    });
  });
}
