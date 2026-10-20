// Tests for Unit 8 (S-20): BR-U8-07 open-time display resolution.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/output/overlay/display_info.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_window_controller.dart';

DisplayInfo _display(String id, {bool isPrimary = false, double left = 0}) =>
    DisplayInfo(
      id: id,
      label: 'Display $id',
      bounds: Rect.fromLTWH(left, 0, 1920, 1080),
      scaleFactor: 1,
      isPrimary: isPrimary,
    );

void main() {
  group('resolveOpenDisplay', () {
    test('a present id resolves to itself', () {
      final primary = _display('primary', isPrimary: true);
      final secondary = _display('secondary', left: 1920);

      final resolution = resolveOpenDisplay(
        [primary, secondary],
        'secondary',
      );

      expect(resolution.target, secondary);
      expect(resolution.persistedIdPresent, isTrue);
    });

    test('an absent id falls back to the primary and is marked absent', () {
      final primary = _display('primary', isPrimary: true);
      final secondary = _display('secondary', left: 1920);

      final resolution = resolveOpenDisplay([secondary, primary], 'gone');

      expect(resolution.target, primary);
      expect(resolution.persistedIdPresent, isFalse);
    });

    test('an absent id with no primary falls back to the first display', () {
      final first = _display('first');
      final second = _display('second', left: 1920);

      final resolution = resolveOpenDisplay([first, second], 'gone');

      expect(resolution.target, first);
      expect(resolution.persistedIdPresent, isFalse);
    });

    test('an absent persisted id with no displays resolves to null', () {
      final resolution = resolveOpenDisplay([], 'gone');

      expect(resolution.target, isNull);
      expect(resolution.persistedIdPresent, isFalse);
    });

    test('a null persisted id is treated as absent', () {
      final primary = _display('primary', isPrimary: true);

      final resolution = resolveOpenDisplay([primary], null);

      expect(resolution.target, primary);
      expect(resolution.persistedIdPresent, isFalse);
    });

    test('an empty persisted id is treated as absent', () {
      final primary = _display('primary', isPrimary: true);

      final resolution = resolveOpenDisplay([primary], '');

      expect(resolution.target, primary);
      expect(resolution.persistedIdPresent, isFalse);
    });

    test('no displays and no persisted id resolves to null', () {
      expect(resolveOpenDisplay([], null).target, isNull);
      expect(resolveOpenDisplay([], '').target, isNull);
    });
  });
}
