// Tests for Unit 8.1 (S-21), fix round 6 finding R6-1: the macOS sub-engine
// must run before its window is shown.
//
// The macOS embedder launches a `FlutterViewController`'s engine only from
// `viewWillAppear` (`FlutterViewController.mm`), and `desktop_multi_window`
// keeps a new window hidden until `show`. The controller shows the window only
// after the sub-engine's `overlayReady`, so a sub-engine that waits for the
// window to appear never sends it and every open ends in `ready_timeout`. The
// runner therefore starts the engine itself, last in the window-created
// callback, once the `configure` channel and the close hook exist.
//
// Neither app has a Swift test target, so this is a static check of the
// runner source, in the same style as `refactor_fence_test.dart`.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The callback body in [source]: from the registration to the end of
/// `awakeFromNib`.
String _callbackBody(String source) {
  final start = source.indexOf('setOnWindowCreatedCallback');
  final end = source.indexOf('super.awakeFromNib()', start);
  expect(start, isNonNegative, reason: 'no window-created callback');
  expect(end, greaterThan(start), reason: 'callback not inside awakeFromNib');
  return source.substring(start, end);
}

void main() {
  for (final app in const ['zip_captions', 'zip_broadcast']) {
    test('$app starts the sub-engine after installing its channels', () {
      final source =
          File('../$app/macos/Runner/MainFlutterWindow.swift').readAsStringSync();
      final body = _callbackBody(source);

      final configure =
          body.indexOf('installConfigureChannel(for: controller)');
      final closeHook = body.indexOf('installCloseHook(for: controller)');
      final run = body.indexOf('controller.engine.run(withEntrypoint: nil)');

      expect(configure, isNonNegative);
      expect(closeHook, isNonNegative);
      expect(run, isNonNegative, reason: 'the sub-engine is never started');
      expect(run, greaterThan(configure));
      expect(run, greaterThan(closeHook));
    });
  }
}
