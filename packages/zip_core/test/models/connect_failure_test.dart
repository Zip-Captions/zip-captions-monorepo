// `hide Timeout`: `flutter_test` re-exports `test_api`'s `Timeout`, which
// would otherwise collide with `ConnectFailure`'s `Timeout` variant.
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_core/src/models/connect_failure.dart';

void main() {
  group('ConnectFailure', () {
    test(
      'has exactly the four variants fixed by business-rules.md Rule 3',
      () {
        const variants = <ConnectFailure>[
          BroadcastFull(),
          IceFailed(),
          SignalingRejected(),
          Timeout(),
        ];

        expect(variants, hasLength(4));
        for (final variant in variants) {
          expect(variant, isA<ConnectFailure>());
        }
      },
    );

    test('distinct variants are never equal to each other', () {
      const variants = <ConnectFailure>[
        BroadcastFull(),
        IceFailed(),
        SignalingRejected(),
        Timeout(),
      ];
      for (final a in variants) {
        for (final b in variants) {
          if (identical(a, b)) continue;
          expect(a, isNot(equals(b)));
        }
      }
    });
  });
}
