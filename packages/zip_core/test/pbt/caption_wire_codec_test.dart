// CaptionWireCodec PBT (S-14, S-16, S-18): encode/decode round-trip
// recovers every CaptionWireMessage variant, and decode never throws on
// arbitrary malformed input (business-rules.md Rule 7). Mirrors
// signaling_codec_test.dart — the only codec-test precedent in this
// codebase — adapted to the three-variant wire model.

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/caption_wire_codec.dart';

import '../helpers/generators.dart';
import '../helpers/pbt.dart';

void main() {
  group('CaptionWireCodec PBT', () {
    const Glados(arbitraryCaptionWireMessage).test(
      'encode then decode recovers the original message',
      (message) {
        final decoded = CaptionWireCodec.decode(
          CaptionWireCodec.encode(message),
        );
        expect(decoded, equals(message));
      },
    );

    const Glados(arbitraryMalformedCaptionWireJson).test(
      'decode never throws on arbitrary malformed input',
      (json) {
        expect(() => CaptionWireCodec.decode(json), returnsNormally);
      },
    );

    test(
      'decode rejects a payload oversized only in a nested field the '
      "variant doesn't read (mirrors SignalingCodec's own PR #24 fix)",
      () {
        // ended ignores every field but messageType/version — the
        // oversized-input check must still look at the full encoded
        // payload, not just the fields a given variant happens to read.
        final oversized = <String, Object?>{
          'messageType': 'ended',
          'version': 1,
          'extra': {'blob': 'x' * 20000},
        };

        expect(CaptionWireCodec.decode(oversized), isNull);
      },
    );
  });
}
