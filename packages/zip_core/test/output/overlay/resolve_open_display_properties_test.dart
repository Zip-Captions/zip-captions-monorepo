// Tests for Unit 8 (S-20): FP-4, open resolution over generated display lists
// (PBT-02/PBT-03).
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';
import 'package:zip_core/src/output/overlay/overlay_window_controller.dart';

import '../../helpers/overlay_generators.dart';
import '../../helpers/pbt.dart';

/// A display list paired with a persisted id drawn from it, from nowhere, or
/// absent entirely.
class _ResolutionCase {
  const _ResolutionCase(this.displays, this.persistedId);

  final List<DisplayInfo> displays;
  final String? persistedId;
}

_ResolutionCase _resolutionCase(Random random) {
  final displays = arbitraryDisplayList(random);
  final variant = random.nextInt(5);
  final String? persistedId;
  switch (variant) {
    case 0:
      // An id that is present in the list.
      persistedId = displays.isEmpty
          ? null
          : displays[random.nextInt(displays.length)].id;
    case 1:
      // An id that is not in the list.
      persistedId = 'absent-${random.nextInt(1000)}';
    case 2:
      persistedId = null;
    case 3:
      persistedId = '';
    default:
      // The empty display id, which some platforms report.
      persistedId = displays.isEmpty
          ? ''
          : displays[random.nextInt(displays.length)].id;
  }
  return _ResolutionCase(displays, persistedId);
}

bool _isPresent(List<DisplayInfo> displays, String? persistedId) =>
    persistedId != null &&
    persistedId.isNotEmpty &&
    displays.any((d) => d.id == persistedId);

DisplayInfo? _primary(List<DisplayInfo> displays) {
  for (final display in displays) {
    if (display.isPrimary) return display;
  }
  return null;
}

void main() {
  const Glados<_ResolutionCase>(_resolutionCase).test(
    'FP-4: the open target follows BR-U8-07 exactly',
    (testCase) {
      final displays = testCase.displays;
      final persistedId = testCase.persistedId;

      final resolution = resolveOpenDisplay(displays, persistedId);
      final present = _isPresent(displays, persistedId);
      final primary = _primary(displays);

      expect(resolution.persistedIdPresent, present);

      if (present) {
        final selected = displays.firstWhere(
          (display) => display.id == persistedId,
        );
        expect(resolution.target, selected);
      } else if (primary != null) {
        expect(resolution.target, primary);
      } else if (displays.isEmpty) {
        expect(resolution.target, isNull);
      } else {
        expect(resolution.target, displays.first);
      }
    },
  );

  const Glados<_ResolutionCase>(_resolutionCase).test(
    'FP-4: an absent id is kept, never cleared',
    (testCase) {
      // The function has no write path and takes the id by value: the caller's
      // copy is unchanged whether or not the id was found.
      final before = testCase.persistedId;
      final resolution = resolveOpenDisplay(testCase.displays, before);

      expect(testCase.persistedId, before);
      if (!resolution.persistedIdPresent &&
          before != null &&
          before.isNotEmpty) {
        // Nothing in the resolution replaces the id with another string.
        expect(resolution.target?.id, isNot(before));
      }
    },
  );
}
