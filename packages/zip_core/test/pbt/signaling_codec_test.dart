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
  });
}
