// Property tests for Unit 8.1 (S-21): POP-4, the pop-out size invariants
// (FD §5 POP-4; FD domain-entities §3.3). N-08.
//
// Pure function, so the properties hold over the whole input space the app can
// produce: any work-area width, any text scale, any caption size tier.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/output/overlay/display_info.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/output/overlay/pop_out_geometry.dart';

import '../../helpers/pbt.dart';

DisplaySettings _settingsFor(CaptionTextSize size) => DisplaySettings(
      scrollDirection: ScrollDirection.bottomToTop,
      captionTextSize: size,
      captionFont: CaptionFont.atkinsonHyperlegible,
      themeModeSetting: ThemeModeSetting.system,
      maxVisibleLines: 0,
    );

void main() {
  final textTheme = Typography.material2021().black;

  final inputs = any.combine3(
    any.choose(CaptionTextSize.values),
    any.doubleInRange(PopOutGeometry.minWidth, 5120),
    any.doubleInRange(0.75, 3),
    (size, workAreaWidth, textScaler) => (size, workAreaWidth, textScaler),
  );

  Glados(inputs).test('width stays within [minWidth, workArea.width]', (input) {
    final (size, workAreaWidth, textScaler) = input;
    final result = popOutSize(
      _settingsFor(size),
      textTheme,
      textScaler: textScaler,
      workAreaWidth: workAreaWidth,
    );

    expect(result.width, greaterThanOrEqualTo(PopOutGeometry.minWidth));
    expect(result.width, lessThanOrEqualTo(workAreaWidth));
  });

  Glados(inputs).test('height is never below the minimum', (input) {
    final (size, workAreaWidth, textScaler) = input;
    final result = popOutSize(
      _settingsFor(size),
      textTheme,
      textScaler: textScaler,
      workAreaWidth: workAreaWidth,
    );

    expect(result.height, greaterThanOrEqualTo(PopOutGeometry.minHeight));
  });

  Glados(inputs).test('width is monotone non-decreasing in work-area width',
      (input) {
    final (size, workAreaWidth, textScaler) = input;
    Size sizeFor(double width) => popOutSize(
          _settingsFor(size),
          textTheme,
          textScaler: textScaler,
          workAreaWidth: width,
        );

    final narrow = sizeFor(workAreaWidth);
    final wide = sizeFor(workAreaWidth + 100);

    expect(wide.width, greaterThanOrEqualTo(narrow.width));
    expect(wide.width, lessThanOrEqualTo(workAreaWidth + 100));
  });

  Glados(inputs).test('height is monotone non-decreasing in text scale',
      (input) {
    final (size, workAreaWidth, textScaler) = input;
    Size sizeFor(double scale) => popOutSize(
          _settingsFor(size),
          textTheme,
          textScaler: scale,
          workAreaWidth: workAreaWidth,
        );

    final small = sizeFor(textScaler);
    final large = sizeFor(textScaler + 0.5);

    expect(large.height, greaterThanOrEqualTo(small.height));
  });

  Glados(inputs).test('the frame always fits inside the work area', (input) {
    final (size, workAreaWidth, textScaler) = input;
    final workArea = Rect.fromLTWH(0, 0, workAreaWidth, 1080);

    final result = computePopOutFrame(
      displays: [
        DisplayInfo(
          id: 'primary',
          label: 'primary',
          bounds: workArea,
          scaleFactor: 1,
          isPrimary: true,
        ),
      ],
      mainWindowCentre: null,
      settings: _settingsFor(size),
      textTheme: textTheme,
      textScaler: textScaler,
      platform: TargetPlatform.windows,
    );

    expect(result.frame.left, greaterThanOrEqualTo(workArea.left));
    expect(result.frame.top, greaterThanOrEqualTo(workArea.top));
    expect(result.frame.right, lessThanOrEqualTo(workArea.right));
    expect(result.frame.bottom, lessThanOrEqualTo(workArea.bottom));
  });

  test('capture: a 1920-wide work area at two-times text scale', () {
    final result = popOutSize(
      _settingsFor(CaptionTextSize.md),
      textTheme,
      textScaler: 2,
      workAreaWidth: 1920,
    );

    expect(result.width, 1440);
    expect(result.height, greaterThan(PopOutGeometry.minHeight));
  });
}
