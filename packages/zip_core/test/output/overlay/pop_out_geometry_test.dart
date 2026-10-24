// Tests for Unit 8.1 (S-21): pop-out geometry (FD §5 POP-4; NFR-D §2.3). N-07.
//
// The chrome allowance values are documented estimates until the Unit 9
// measurement; this test pins the selection and the semantics (content size,
// allowance added once), not the numbers' platform truth.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/display_settings.dart';
import 'package:zip_core/src/models/enums.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';
import 'package:zip_core/src/output/overlay/pop_out_geometry.dart';

DisplayInfo _display({
  String id = 'primary',
  Rect bounds = const Rect.fromLTWH(0, 0, 1920, 1080),
  bool isPrimary = true,
}) => DisplayInfo(
  id: id,
  label: id,
  bounds: bounds,
  scaleFactor: 1,
  isPrimary: isPrimary,
);

DisplaySettings _settings(CaptionTextSize size) => DisplaySettings(
  scrollDirection: ScrollDirection.bottomToTop,
  captionTextSize: size,
  captionFont: CaptionFont.atkinsonHyperlegible,
  themeModeSetting: ThemeModeSetting.system,
  maxVisibleLines: 0,
);

void main() {
  final textTheme = Typography.material2021().black;

  group('chromeAllowance', () {
    test('selects one documented estimate per desktop platform', () {
      expect(chromeAllowance(TargetPlatform.macOS).top, 28);
      expect(chromeAllowance(TargetPlatform.windows).top, 39);
      expect(chromeAllowance(TargetPlatform.linux).top, 38);
    });

    test('adds no side or bottom chrome on any platform', () {
      for (final platform in TargetPlatform.values) {
        final inset = chromeAllowance(platform);
        expect(inset.left, 0, reason: '$platform');
        expect(inset.right, 0, reason: '$platform');
        expect(inset.bottom, 0, reason: '$platform');
      }
    });

    test('falls back to zero for non-desktop platforms', () {
      expect(
        chromeAllowance(TargetPlatform.android),
        EdgeInsets.zero,
      );
      expect(chromeAllowance(TargetPlatform.iOS), EdgeInsets.zero);
      expect(chromeAllowance(TargetPlatform.fuchsia), EdgeInsets.zero);
    });
  });

  group('popOutSize', () {
    test('height is two lines plus the toggle row, padding and spacing', () {
      final style = CaptionTextSize.md.resolve(textTheme)!;
      final lineHeight = (style.fontSize ?? 16) * (style.height ?? 1.2);
      final size = popOutSize(_settings(CaptionTextSize.md), textTheme);

      expect(
        size.height,
        PopOutGeometry.toggleRowHeight +
            2 * lineHeight +
            PopOutGeometry.captionLineSpacing +
            2 * PopOutGeometry.captionVerticalPadding,
      );
    });

    test(
      'width is three quarters of the work area, never below the minimum',
      () {
        expect(
          popOutSize(
            _settings(CaptionTextSize.md),
            textTheme,
            workAreaWidth: 1920,
          ).width,
          1440,
        );
        expect(
          popOutSize(
            _settings(CaptionTextSize.md),
            textTheme,
            workAreaWidth: 200,
          ).width,
          PopOutGeometry.minWidth,
        );
      },
    );

    test('a work area narrower than the minimum clamps to the minimum', () {
      // The minimum is a content floor: a display too small for it is a Unit 9
      // placement concern, not a reason to render a one-character-wide surface.
      final width = popOutSize(
        _settings(CaptionTextSize.md),
        textTheme,
        workAreaWidth: 200,
      ).width;

      expect(width, PopOutGeometry.minWidth);
    });

    test('text scale grows the height, the width is unaffected', () {
      final base = popOutSize(_settings(CaptionTextSize.md), textTheme);
      final scaled = popOutSize(
        _settings(CaptionTextSize.md),
        textTheme,
        textScaler: 2,
      );

      expect(scaled.height, greaterThan(base.height));
      expect(scaled.width, base.width);
    });

    test('a small text tier never drops below the minimum height', () {
      final size = popOutSize(_settings(CaptionTextSize.xs), textTheme);

      expect(size.height, greaterThanOrEqualTo(PopOutGeometry.minHeight));
    });
  });

  group('computePopOutFrame', () {
    test('no display yields Rect.zero and a null id', () {
      final result = computePopOutFrame(
        displays: const <DisplayInfo>[],
        mainWindowCentre: null,
        settings: _settings(CaptionTextSize.md),
        textTheme: textTheme,
        textScaler: 1,
        platform: TargetPlatform.macOS,
      );

      expect(result.frame, Rect.zero);
      expect(result.displayId, isNull);
    });

    test('prefers the display under the main window centre', () {
      final result = computePopOutFrame(
        displays: [
          _display(),
          _display(
            id: 'right',
            bounds: const Rect.fromLTWH(1920, 0, 1920, 1080),
            isPrimary: false,
          ),
        ],
        mainWindowCentre: const Offset(2500, 500),
        settings: _settings(CaptionTextSize.md),
        textTheme: textTheme,
        textScaler: 1,
        platform: TargetPlatform.macOS,
      );

      expect(result.displayId, 'right');
    });

    test('falls back to the primary, then the first display', () {
      final primaryFallback = computePopOutFrame(
        displays: [
          _display(
            id: 'left',
            bounds: const Rect.fromLTWH(-1920, 0, 1920, 1080),
            isPrimary: false,
          ),
          _display(),
        ],
        mainWindowCentre: const Offset(5000, 5000),
        settings: _settings(CaptionTextSize.md),
        textTheme: textTheme,
        textScaler: 1,
        platform: TargetPlatform.macOS,
      );
      expect(primaryFallback.displayId, 'primary');

      final firstFallback = computePopOutFrame(
        displays: [
          _display(id: 'only', isPrimary: false),
        ],
        mainWindowCentre: null,
        settings: _settings(CaptionTextSize.md),
        textTheme: textTheme,
        textScaler: 1,
        platform: TargetPlatform.macOS,
      );
      expect(firstFallback.displayId, 'only');
    });

    test('is bottom-anchored, horizontally centred, and adds chrome once', () {
      final result = computePopOutFrame(
        displays: [_display()],
        mainWindowCentre: null,
        settings: _settings(CaptionTextSize.md),
        textTheme: textTheme,
        textScaler: 1,
        platform: TargetPlatform.windows,
      );
      final content = popOutSize(
        _settings(CaptionTextSize.md),
        textTheme,
        workAreaWidth: 1920,
      );
      final frame = result.frame;

      expect(frame.width, content.width);
      expect(frame.height, closeTo(content.height + 39, 0.001));
      expect(frame.left, (1920 - frame.width) / 2);
      expect(frame.bottom, 1080);
    });

    test('the allowance differs per platform but the width never does', () {
      double heightFor(TargetPlatform platform) => computePopOutFrame(
        displays: [_display()],
        mainWindowCentre: null,
        settings: _settings(CaptionTextSize.md),
        textTheme: textTheme,
        textScaler: 1,
        platform: platform,
      ).frame.height;

      final macos = heightFor(TargetPlatform.macOS);

      expect(heightFor(TargetPlatform.windows), isNot(macos));
      expect(heightFor(TargetPlatform.linux), isNot(macos));
      expect(
        heightFor(TargetPlatform.android),
        lessThan(heightFor(TargetPlatform.linux)),
      );
    });

    test('clamps a tiny work area so the window stays on screen', () {
      final result = computePopOutFrame(
        displays: [
          _display(bounds: const Rect.fromLTWH(0, 0, 340, 300)),
        ],
        mainWindowCentre: null,
        settings: _settings(CaptionTextSize.xxl),
        textTheme: textTheme,
        textScaler: 3,
        platform: TargetPlatform.windows,
      );
      const workArea = Rect.fromLTWH(0, 0, 340, 300);
      final frame = result.frame;

      expect(frame.width, lessThanOrEqualTo(workArea.width));
      expect(frame.height, lessThanOrEqualTo(workArea.height));
      expect(frame.left, greaterThanOrEqualTo(workArea.left));
      expect(frame.top, greaterThanOrEqualTo(workArea.top));
      expect(frame.right, lessThanOrEqualTo(workArea.right));
      expect(frame.bottom, lessThanOrEqualTo(workArea.bottom));
    });

    test('an offset display is framed relative to its own work area', () {
      const bounds = Rect.fromLTWH(-1920, -200, 1920, 1080);
      final result = computePopOutFrame(
        displays: [_display(bounds: bounds)],
        mainWindowCentre: null,
        settings: _settings(CaptionTextSize.md),
        textTheme: textTheme,
        textScaler: 1,
        platform: TargetPlatform.linux,
      );

      expect(result.frame.bottom, bounds.bottom);
      expect(result.frame.center.dx, bounds.center.dx);
    });
  });
}
