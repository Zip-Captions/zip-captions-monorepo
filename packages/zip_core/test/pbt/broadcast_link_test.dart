import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/broadcast_link.dart';

import '../helpers/generators.dart';
import '../helpers/pbt.dart';

void main() {
  group('BroadcastLink PBT', () {
    const Glados(arbitraryBroadcastId).test(
      'toUrl then parseInput recovers the original id',
      (id) {
        final url = BroadcastLink.toUrl(id);
        expect(BroadcastLink.parseInput(url.toString()), equals(id));
      },
    );

    Glados(arbitraryLinkInput).test(
      'parseInput never throws on arbitrary input',
      (input) {
        expect(() => BroadcastLink.parseInput(input), returnsNormally);
      },
    );
  });
}
