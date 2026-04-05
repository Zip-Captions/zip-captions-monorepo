import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;

import '../helpers/generators.dart';

void main() {
  group('SttResult PBT properties', () {
    Glados(arbitrarySttResult).test(
      'confidence is in [0.0, 1.0]',
      (result) {
        expect(result.confidence, greaterThanOrEqualTo(0.0));
        expect(result.confidence, lessThanOrEqualTo(1.0));
      },
    );

    Glados(arbitrarySttResult).test(
      'sourceId is non-empty',
      (result) {
        expect(result.sourceId, isNotEmpty);
      },
    );

    Glados(arbitrarySttResult).test(
      'final results have non-empty text',
      (result) {
        if (result.isFinal) {
          expect(result.text, isNotEmpty);
        }
      },
    );

    Glados(arbitrarySttResult).test(
      'timestamp is set',
      (result) {
        expect(result.timestamp, isNotNull);
      },
    );
  });
}
