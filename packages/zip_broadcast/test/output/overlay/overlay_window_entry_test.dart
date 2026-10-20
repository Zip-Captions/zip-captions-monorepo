import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_bridge.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_entry.dart';
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

  bool get isListening => _onCall != null;

  void call(String method, Object? arguments) => _onCall!(method, arguments);
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
        pump: (widget) => tester.pumpWidget(widget),
      );
      await tester.pump();

      expect(find.text('Window unavailable'), findsOneWidget);
      expect(bridge.isListening, isFalse);
      expect(bridge.sent, isEmpty);
    });

    testWidgets('a good payload installs the handler before signalling ready',
        (tester) async {
      final bridge = _FakeBridge();
      final encoded = encodeLaunch(_launch());

      await overlayWindowMain(
        ['multi_window', '1', encoded],
        bridge: bridge,
        pump: (widget) => tester.pumpWidget(widget),
      );
      await tester.pump();

      expect(bridge.isListening, isTrue);
      expect(bridge.sent, hasLength(1));
    });
  });

  group('OverlayWindowEntry', () {
    Widget build(_FakeBridge bridge) => ProviderScope(
          child: OverlayWindowEntry(launch: _launch(), bridge: bridge),
        );

    testWidgets('a bad captionUpdate is dropped without throwing',
        (tester) async {
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
