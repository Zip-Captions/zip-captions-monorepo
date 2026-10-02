import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/signaling_codec.dart';

import '../helpers/generators.dart';
import '../helpers/pbt.dart';

void main() {
  group('SignalingCodec PBT', () {
    const Glados(arbitrarySignalingMessage).test(
      'encode then decode recovers the original message',
      (message) {
        final decoded = SignalingCodec.decode(SignalingCodec.encode(message));
        expect(decoded, equals(message));
      },
    );

    const Glados(arbitraryMalformedSignalingJson).test(
      'decode never throws on arbitrary malformed input',
      (json) {
        expect(() => SignalingCodec.decode(json), returnsNormally);
      },
    );

    test(
      'decode rejects a payload oversized only in a nested field the '
      "variant doesn't read (PR #24 review, 2026-10-02)",
      () {
        // broadcastEnded ignores every field but type/version — the
        // oversized-input check must still look at the full encoded
        // payload, not just the fields a given variant happens to read.
        final oversized = <String, Object?>{
          'type': 'broadcastEnded',
          'version': 1,
          'extra': {'blob': 'x' * 20000},
        };

        expect(SignalingCodec.decode(oversized), isNull);
      },
    );
  });
}
