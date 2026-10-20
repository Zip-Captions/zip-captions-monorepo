// Tests for Unit 8 (S-20): FP-1 codec round-trip and FP-2 codec
// total-on-error (PBT-02/PBT-03).
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_codec.dart';

import '../../helpers/generators.dart';
import '../../helpers/pbt.dart';

void main() {
  const Glados<CaptionOverlaySnapshotFixture>(arbitraryCaptionOverlaySnapshot)
      .test(
    'FP-1: decode(encode(snapshot)) == snapshot for every generated snapshot',
    (fixture) {
      final snapshot = fixture.snapshot;
      final encoded = encodeSnapshot(snapshot);
      expect(
        decodeSnapshot(encoded),
        snapshot,
        reason: 'encoded: ${encoded.length} bytes',
      );
    },
  );

  const Glados<OverlayWindowLaunchFixture>(arbitraryOverlayWindowLaunch).test(
    'FP-1: decode(encode(launch)) == launch for every generated launch',
    (fixture) {
      final launch = fixture.launch;
      expect(decodeLaunch(encodeLaunch(launch)), launch);
    },
  );

  const Glados<String>(arbitraryMalformedWindowJson).test(
    'FP-2: decodeSnapshot returns null and never throws on malformed input',
    (payload) {
      expect(decodeSnapshot(payload), isNull);
    },
  );

  const Glados<String>(arbitraryMalformedWindowJson).test(
    'FP-2: decodeLaunch returns null and never throws on malformed input',
    (payload) {
      expect(decodeLaunch(payload), isNull);
    },
  );
}
