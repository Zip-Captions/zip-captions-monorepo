// Tests for Unit 8 (S-20): the io window adapter's pure frame conversion and
// its test seam. The platform-channel calls are never exercised: the plugin is
// not loaded in tests (SECURITY-10 section 5 item 3).
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_multi_window_service_io.dart';

import '../../helpers/fake_display_enumerator.dart';

void main() {
  group('toPlatformFrame is pure', () {
    test('the same inputs give the same output, with no I/O', () {
      const frame = Rect.fromLTWH(120, -40, 1600, 900);

      final first = toPlatformFrame(
        frame,
        TargetPlatform.macOS,
        primaryFullHeight: 1417,
      );
      final second = toPlatformFrame(
        frame,
        TargetPlatform.macOS,
        primaryFullHeight: 1417,
      );

      expect(first, second);
    });

    test('no enumerator is required to convert a frame', () {
      const frame = Rect.fromLTWH(1, 2, 3, 4);

      // A conversion with no adapter constructed at all.
      expect(
        toPlatformFrame(frame, TargetPlatform.linux),
        frame,
      );
    });
  });

  group('DesktopMultiWindowService', () {
    test('the test seam accepts a FakeDisplayEnumerator', () {
      final service = DesktopMultiWindowService.withEnumerator(
        FakeDisplayEnumerator(),
      );

      expect(service.enumerator, isA<FakeDisplayEnumerator>());
    });

    test('the test seam does not change isSupported', () {
      final withFake = DesktopMultiWindowService.withEnumerator(
        FakeDisplayEnumerator(),
      );
      final withoutFake = DesktopMultiWindowService();

      expect(withFake.isSupported, withoutFake.isSupported);
    });

    test('the default enumerator is the production adapter', () {
      final service = DesktopMultiWindowService();

      expect(service.enumerator, isNotNull);
      expect(service.enumerator, isNot(isA<FakeDisplayEnumerator>()));
    });
  });
}
