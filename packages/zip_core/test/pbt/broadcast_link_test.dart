import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/constants/broadcast_link_config.dart';
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

    // PBT-02: the full `https://...` form built from any configured base
    // parses back to the same id — `parseInput` stays host-agnostic
    // (`business-rules.md` Rule 11).
    Glados(
      any.combine2(
        arbitraryConfiguredBase,
        arbitraryBroadcastId,
        (base, id) => (base, id),
      ),
    ).test(
      'parseInput recovers the id from any configured base form',
      (input) {
        final (base, id) = input;
        final url = '$base${id.value.toLowerCase()}';
        expect(BroadcastLink.parseInput(url), equals(id));
      },
    );

    // PBT-02: the bare-code form (and its lower-cased display form).
    Glados(arbitraryBroadcastId).test(
      'parseInput recovers the id from the bare and lower-cased forms',
      (id) {
        expect(BroadcastLink.parseInput(id.value), equals(id));
        expect(
          BroadcastLink.parseInput(id.value.toLowerCase()),
          equals(id),
        );
      },
    );

    // PBT-02: generated invalid strings are rejected with `null`.
    Glados(arbitraryInvalidLinkInput).test(
      'parseInput returns null for generated invalid input',
      (input) {
        expect(BroadcastLink.parseInput(input), isNull);
      },
    );

    test('toUrl interpolates broadcastBaseUrl (Rule 11)', () {
      final id = arbitraryBroadcastId(Random(0));
      expect(
        BroadcastLink.toUrl(id).toString(),
        equals('$broadcastBaseUrl${id.value.toLowerCase()}'),
      );
    });

    test('broadcastBaseUrl defaults to the v1 apex (Rule 11)', () {
      // The default is a deliberate, byte-identical carry-over of the
      // shipped `BroadcastLink.baseUrl`; a future environment change is an
      // explicit edit here, not an accidental one.
      expect(broadcastBaseUrl, equals('https://zipcaptions.app/b/'));
    });
  });
}