import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/models/overlay_window_config.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/output/overlay/overlay_window_bridge.dart';
import 'package:zip_core/src/output/overlay/overlay_window_entry.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/output/overlay/window_configurator.dart';
import 'package:zip_core/zip_core.dart';

class _FakeBridge implements OverlayWindowBridge {
  void Function(String method, Object? arguments)? _onCall;
  final List<Object?> sent = <Object?>[];

  @override
  void listen(void Function(String method, Object? arguments) onCall) {
    _onCall = onCall;
  }

  @override
  void send(Object? arguments) => sent.add(arguments);

  final List<void> toggleRequests = <void>[];

  @override
  void sendPopOutToggle() => toggleRequests.add(null);

  bool get isListening => _onCall != null;

  void call(String method, Object? arguments) => _onCall!(method, arguments);
}

/// Records the `configure` call so a widget test never reaches a channel.
class _FakeConfigurator implements WindowConfigurator {
  final List<(int, OverlayWindowConfig)> calls =
      <(int, OverlayWindowConfig)>[];

  @override
  Future<void> configure(int windowId, OverlayWindowConfig config) async {
    calls.add((windowId, config));
  }
}

OverlayWindowLaunch _launch({List<CaptionDisplayEntry> entries = const []}) =>
    OverlayWindowLaunch(
      config: const OverlayConfig(),
      snapshot: CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: entries,
        settings: DisplaySettings.defaults(),
      ),
    );

void main() {
  group('isOverlayWindowLaunch', () {
    test('true for a multi_window launch with an encoded payload', () {
      expect(isOverlayWindowLaunch(['multi_window', '1', '{}']), isTrue);
    });

    test('false for no arguments', () {
      expect(isOverlayWindowLaunch(const []), isFalse);
    });

    test('false when the payload is missing', () {
      expect(isOverlayWindowLaunch(const ['multi_window', '1']), isFalse);
    });

    test('false for a different first argument', () {
      expect(
        isOverlayWindowLaunch(const ['something_else', '1', '{}']),
        isFalse,
      );
    });
  });

  group('overlayWindowMain', () {
    testWidgets('a bad payload builds the unavailable frame and never '
        'signals ready', (tester) async {
      final bridge = _FakeBridge();

      await overlayWindowMain(
        const ['multi_window', '1', 'not a payload'],
        bridge: bridge,
        windowConfigurator: _FakeConfigurator(),
        pump: (widget) => tester.pumpWidget(widget),
      );
      await tester.pump();

      expect(find.text('Window unavailable'), findsOneWidget);
      expect(bridge.isListening, isFalse);
      expect(bridge.sent, isEmpty);
    });

    testWidgets('a good payload installs the handler before signalling ready', (
      tester,
    ) async {
      final bridge = _FakeBridge();
      final encoded = encodeLaunch(_launch());

      final configurator = _FakeConfigurator();
      await overlayWindowMain(
        ['multi_window', '1', encoded],
        bridge: bridge,
        windowConfigurator: configurator,
        pump: (widget) => tester.pumpWidget(widget),
      );
      await tester.pump();

      expect(bridge.isListening, isTrue);
      expect(bridge.sent, hasLength(1));
      // Shape change 5: the window configures itself in its own engine first,
      // with the external display's borderless properties.
      expect(configurator.calls.single.$1, 1);
      expect(configurator.calls.single.$2, const OverlayWindowConfig());
    });

    testWidgets('the pop-out configures itself floating and decorated', (
      tester,
    ) async {
      final bridge = _FakeBridge();
      final configurator = _FakeConfigurator();
      final encoded = encodeLaunch(
        OverlayWindowLaunch(
          config: const OverlayConfig(mode: PopOutMode()),
          snapshot: _launch().snapshot,
        ),
      );

      await overlayWindowMain(
        ['multi_window', '2', encoded],
        bridge: bridge,
        windowConfigurator: configurator,
        pump: (widget) => tester.pumpWidget(widget),
      );
      await tester.pump();

      final (windowId, config) = configurator.calls.single;
      expect(windowId, 2);
      expect(config.floating, isTrue);
      expect(config.decorated, isTrue);
    });
  });

  group('OverlayWindowEntry', () {
    Widget build(_FakeBridge bridge) => ProviderScope(
      child: OverlayWindowEntry(launch: _launch(), bridge: bridge),
    );

    testWidgets('a bad captionUpdate is dropped without throwing', (
      tester,
    ) async {
      final bridge = _FakeBridge();
      await tester.pumpWidget(build(bridge));
      await tester.pump();

      bridge.call('captionUpdate', 'not a payload');
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(OverlayWindowEntry), findsOneWidget);
    });

    testWidgets('a good captionUpdate replaces the frame', (tester) async {
      final bridge = _FakeBridge();
      await tester.pumpWidget(build(bridge));
      await tester.pump();

      final next = CaptionOverlaySnapshot(
        activity: OverlayActivity.live,
        entries: [
          CaptionDisplayEntry(
            entryId: 'e1',
            sessionId: 's',
            text: 'hello',
            isFinal: true,
            sourceId: 'src',
            timestamp: DateTime.utc(2026),
          ),
        ],
        settings: DisplaySettings.defaults(),
      );
      bridge.call('captionUpdate', encodeSnapshot(next));
      await tester.pump();

      expect(find.text('hello'), findsOneWidget);
    });
  });
}
