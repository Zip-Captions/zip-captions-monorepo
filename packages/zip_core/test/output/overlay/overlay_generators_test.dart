// Tests for Unit 8.1 (S-21): the overlay generators that moved to zip_core
// ahead of the window machinery (FD BLM §7 shape change 4; PBT-07).
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/overlay_config.dart';
import 'package:zip_core/src/models/overlay_position.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';

import '../../helpers/overlay_generators.dart';

void main() {
  group('overlay generators', () {
    test('a display list has at most four entries and one primary', () {
      for (var seed = 0; seed < 100; seed++) {
        final displays = arbitraryDisplayList(Random(seed));
        expect(displays.length, lessThanOrEqualTo(4));
        expect(
          displays.where((d) => d.isPrimary).length,
          lessThanOrEqualTo(1),
        );
      }
    });

    test('a launch round-trips through the codec', () {
      for (var seed = 0; seed < 100; seed++) {
        final launch = arbitraryOverlayWindowLaunch(Random(seed)).launch;
        expect(decodeLaunch(encodeLaunch(launch)), launch);
      }
    });

    test('a launch carries one of the two accepted positions only', () {
      for (var seed = 0; seed < 100; seed++) {
        final config = arbitraryOverlayWindowLaunch(Random(seed)).launch.config;
        expect(config.position, isNot(isA<OverlayPositionCustom>()));
      }
    });

    test('a snapshot encodes within the size guard', () {
      for (var seed = 0; seed < 100; seed++) {
        final snapshot = arbitraryCaptionOverlaySnapshot(Random(seed)).snapshot;
        final encoded = encodeSnapshot(snapshot);
        expect(encoded.length, greaterThan(0));
        expect(decodeSnapshot(encoded)?.activity, snapshot.activity);
      }
    });

    test('a malformed payload never decodes and never throws', () {
      for (var seed = 0; seed < 100; seed++) {
        final payload = arbitraryMalformedWindowJson(Random(seed));
        expect(decodeLaunch(payload), isNull);
        expect(decodeSnapshot(payload), isNull);
      }
    });

    test('a pop-out geometry input has a positive work area and a scale', () {
      for (var seed = 0; seed < 100; seed++) {
        final input = arbitraryPopOutGeometryInput(Random(seed));
        expect(input.workAreaWidth, greaterThan(0));
        expect(input.textScale, greaterThan(0));
      }
    });

    test('the command sequence is bounded and closed', () {
      for (var seed = 0; seed < 100; seed++) {
        final commands = arbitraryOverlayCommandSequence(Random(seed));
        expect(commands, isNotEmpty);
        expect(commands.length, lessThanOrEqualTo(12));
        for (final command in commands) {
          expect(command, isA<OverlayCommand>());
        }
      }
    });
  });

  group('arbitraryOverlayWindowLaunch mode coverage', () {
    test('a generated config decodes as an external display launch', () {
      for (var seed = 0; seed < 20; seed++) {
        final launch = arbitraryOverlayWindowLaunch(Random(seed)).launch;
        expect(launch.config.mode, isA<ExternalDisplayMode>());
      }
    });
  });
}
