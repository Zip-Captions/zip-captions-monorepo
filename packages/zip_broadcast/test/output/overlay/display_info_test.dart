// Tests for Unit 8 (S-20): the DisplayInfo model.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/output/overlay/display_info.dart';

import '../../helpers/generators.dart';
import '../../helpers/pbt.dart';

void main() {
  const display = DisplayInfo(
    id: 'display-1',
    label: 'Projector',
    bounds: Rect.fromLTWH(0, 0, 1920, 1080),
    scaleFactor: 1,
    isPrimary: true,
  );

  test('equality holds over id, label, bounds, scaleFactor and isPrimary', () {
    const same = DisplayInfo(
      id: 'display-1',
      label: 'Projector',
      bounds: Rect.fromLTWH(0, 0, 1920, 1080),
      scaleFactor: 1,
      isPrimary: true,
    );

    expect(display, same);
    expect(display.hashCode, same.hashCode);
    expect(
      display.copyWith(bounds: const Rect.fromLTWH(0, 0, 1280, 720)),
      isNot(display),
    );
    expect(display.copyWith(scaleFactor: 1.5), isNot(display));
  });

  const Glados<List<DisplayInfo>>(arbitraryDisplayList).test(
    'generated display lists hold at most one primary display',
    (displays) {
      final primaries = displays.where((d) => d.isPrimary).length;
      expect(primaries, lessThanOrEqualTo(1));
    },
  );
}
