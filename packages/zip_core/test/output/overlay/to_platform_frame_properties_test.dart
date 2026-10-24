// Tests for Unit 8 (S-20): FP-3 frame conversion over generated logical frames
// (PBT-02/PBT-05).
import 'dart:math';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/output/overlay/desktop_multi_window_service_io.dart';

import '../../helpers/overlay_generators.dart';
import '../../helpers/pbt.dart';

/// A logical frame plus the two platform inputs the conversion may need.
class _FrameCase {
  const _FrameCase({
    required this.frame,
    required this.primaryFullHeight,
    required this.scaleFactor,
  });

  final Rect frame;
  final double primaryFullHeight;
  final double scaleFactor;
}

_FrameCase _frameCase(Random random) => _FrameCase(
  frame: arbitraryLogicalFrame(random),
  primaryFullHeight: arbitraryDisplayHeight(random),
  scaleFactor: arbitraryScaleFactor(random),
);

double _effectiveScale(double scaleFactor) =>
    scaleFactor == 0 ? 1 : scaleFactor;

void main() {
  const Glados<_FrameCase>(_frameCase).test(
    'FP-3: Linux is the identity for every frame',
    (testCase) {
      expect(
        toPlatformFrame(testCase.frame, TargetPlatform.linux),
        testCase.frame,
      );
    },
  );

  const Glados<_FrameCase>(_frameCase).test(
    'FP-3: Windows scales every edge by the display factor (0 -> 1)',
    (testCase) {
      final frame = testCase.frame;
      final scale = _effectiveScale(testCase.scaleFactor);

      final converted = toPlatformFrame(
        frame,
        TargetPlatform.windows,
        displayScaleFactor: testCase.scaleFactor,
      );

      expect(converted.left, closeTo(frame.left * scale, 1e-9));
      expect(converted.top, closeTo(frame.top * scale, 1e-9));
      expect(converted.width, closeTo(frame.width * scale, 1e-9));
      expect(converted.height, closeTo(frame.height * scale, 1e-9));
    },
  );

  const Glados<_FrameCase>(_frameCase).test(
    'FP-3: macOS flips y against the primary full height and keeps x',
    (testCase) {
      final frame = testCase.frame;

      final converted = toPlatformFrame(
        frame,
        TargetPlatform.macOS,
        primaryFullHeight: testCase.primaryFullHeight,
      );

      expect(converted.left, frame.left);
      expect(
        converted.top,
        closeTo(
          testCase.primaryFullHeight - frame.top - frame.height,
          1e-9,
        ),
      );
      expect(converted.width, closeTo(frame.width, 1e-9));
      expect(converted.height, closeTo(frame.height, 1e-9));
    },
  );

  const Glados<_FrameCase>(_frameCase).test(
    'FP-3: the conversion never changes the frame size on macOS or Linux',
    (testCase) {
      for (final target in [TargetPlatform.macOS, TargetPlatform.linux]) {
        final converted = toPlatformFrame(
          testCase.frame,
          target,
          primaryFullHeight: testCase.primaryFullHeight,
        );
        expect(converted.width, closeTo(testCase.frame.width, 1e-9));
        expect(converted.height, closeTo(testCase.frame.height, 1e-9));
      }
    },
  );
}
