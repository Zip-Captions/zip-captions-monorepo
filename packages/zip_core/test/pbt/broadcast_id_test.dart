import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_id.dart';

import '../helpers/generators.dart';
import '../helpers/pbt.dart';

void main() {
  group('BroadcastId PBT', () {
    Glados(arbitraryValidBroadcastIdString).test(
      'parsing a valid code recovers the same value, normalized to uppercase',
      (s) {
        expect(BroadcastId.parse(s).value, equals(s.toUpperCase()));
        expect(BroadcastId.tryParse(s)!.value, equals(s.toUpperCase()));
      },
    );

  });
}
