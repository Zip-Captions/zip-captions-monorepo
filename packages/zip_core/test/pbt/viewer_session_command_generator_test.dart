// Generators are code too: the weighted viewer-session command table must
// be able to produce every command variant, including the activity fallback
// that an off-by-one range once made unreachable.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import '../helpers/generators.dart';

void main() {
  test('every viewer-session command kind is reachable', () {
    final seen = <String>{};
    for (var seed = 0; seed < 200; seed++) {
      for (final command in arbitraryViewerSessionCommandSequence(
        Random(seed),
      )) {
        seen.add(command.runtimeType.toString());
      }
    }

    expect(
      seen,
      containsAll(<String>[
        'LeaveCommand',
        'JoinCommand',
        'TransportStatusCommand',
        'StatusChannelEventCommand',
        'WindowExpiryCommand',
        'EndedCommand',
        'ActivityCommand',
      ]),
    );
  });
}
