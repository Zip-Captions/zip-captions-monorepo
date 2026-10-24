// Tests for Unit 8 (S-20): B-1/B-2 platform frame conversion, named examples
// (FP-3, PBT-10).
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/output/overlay/desktop_multi_window_service_io.dart';

void main() {
  group('toPlatformFrame', () {
    test('Linux is the identity', () {
      const frame = Rect.fromLTWH(-1200, 40, 1920, 1080);

      expect(
        toPlatformFrame(frame, TargetPlatform.linux),
        frame,
      );
    });

    test('macOS primary at the origin', () {
      const frame = Rect.fromLTWH(0, 0, 1920, 1080);

      // 1080 - 0 - 1080 = 0: the primary's top edge is Cocoa y 1080 - 1080.
      expect(
        toPlatformFrame(frame, TargetPlatform.macOS, primaryFullHeight: 1080),
        const Rect.fromLTWH(0, 0, 1920, 1080),
      );
    });

    test('macOS secondary below the primary gets a negative Cocoa y', () {
      // The primary is 1080 tall (full height, menu bar included); the
      // secondary sits directly below it.
      const frame = Rect.fromLTWH(0, 1080, 1920, 1080);

      expect(
        toPlatformFrame(frame, TargetPlatform.macOS, primaryFullHeight: 1080),
        const Rect.fromLTWH(0, -1080, 1920, 1080),
      );
    });

    test('macOS secondary to the right keeps x and flips y', () {
      const frame = Rect.fromLTWH(1920, 25, 1280, 720);

      expect(
        toPlatformFrame(frame, TargetPlatform.macOS, primaryFullHeight: 1117),
        const Rect.fromLTWH(1920, 1117 - 25 - 720, 1280, 720),
      );
    });

    test('macOS uses the primary full height, not the visible height', () {
      // A primary with a 25px menu bar: 1117 full, 1092 visible. Using the
      // visible height would land the frame 25px off.
      const frame = Rect.fromLTWH(0, 0, 1920, 1092);

      expect(
        toPlatformFrame(frame, TargetPlatform.macOS, primaryFullHeight: 1117),
        const Rect.fromLTWH(0, 25, 1920, 1092),
      );
    });

    test('Windows at 1.5x scales every edge', () {
      const frame = Rect.fromLTWH(100, 50, 800, 600);

      expect(
        toPlatformFrame(
          frame,
          TargetPlatform.windows,
          displayScaleFactor: 1.5,
        ),
        const Rect.fromLTWH(150, 75, 1200, 900),
      );
    });

    test('Windows negative offsets scale too', () {
      const frame = Rect.fromLTWH(-1920, -100, 1920, 1080);

      expect(
        toPlatformFrame(
          frame,
          TargetPlatform.windows,
          displayScaleFactor: 2,
        ),
        const Rect.fromLTWH(-3840, -200, 3840, 2160),
      );
    });

    test('mixed DPI: each display converts with its own factor', () {
      const left = Rect.fromLTWH(0, 0, 1920, 1080);
      const right = Rect.fromLTWH(1920, -200, 2560, 1440);

      expect(
        toPlatformFrame(left, TargetPlatform.windows, displayScaleFactor: 1),
        left,
      );
      expect(
        toPlatformFrame(right, TargetPlatform.windows, displayScaleFactor: 1.5),
        const Rect.fromLTWH(2880, -300, 3840, 2160),
      );
    });

    test('Windows treats a scale factor of 0 as 1', () {
      const frame = Rect.fromLTWH(10, 20, 300, 400);

      expect(
        toPlatformFrame(frame, TargetPlatform.windows, displayScaleFactor: 0),
        frame,
      );
    });

    test('Windows treats a missing scale factor as 1', () {
      const frame = Rect.fromLTWH(10, 20, 300, 400);

      expect(toPlatformFrame(frame, TargetPlatform.windows), frame);
    });

    test('macOS treats a missing primary height as 0', () {
      const frame = Rect.fromLTWH(0, 100, 800, 600);

      expect(
        toPlatformFrame(frame, TargetPlatform.macOS),
        const Rect.fromLTWH(0, -700, 800, 600),
      );
    });
  });
}
