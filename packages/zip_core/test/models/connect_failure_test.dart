// `hide Timeout`: `flutter_test` re-exports `test_api`'s `Timeout`, which
// would otherwise collide with `ConnectFailure`'s `Timeout` variant.
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_core/src/models/connect_failure.dart';

void main() {
  group('ConnectFailure', () {
    test(
      'has exactly the four transport variants fixed by business-rules.md '
      'Rule 3, plus the three additive resolution-origin variants (Unit 7 '
      'Rule 5)',
      () {
        const variants = <ConnectFailure>[
          BroadcastFull(),
          IceFailed(),
          SignalingRejected(),
          Timeout(),
          RateLimited(),
          ResolutionFailed(),
          NotFound(),
        ];

        expect(variants, hasLength(7));
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
        RateLimited(),
        ResolutionFailed(),
        NotFound(),
      ];
      for (final a in variants) {
        for (final b in variants) {
          if (identical(a, b)) continue;
          expect(a, isNot(equals(b)));
        }
      }
    });

    test('value equality holds for each variant', () {
      const pairs = <(ConnectFailure, ConnectFailure)>[
        (BroadcastFull(), BroadcastFull()),
        (IceFailed(), IceFailed()),
        (SignalingRejected(), SignalingRejected()),
        (Timeout(), Timeout()),
        (RateLimited(), RateLimited()),
        (ResolutionFailed(), ResolutionFailed()),
        (NotFound(), NotFound()),
      ];
      for (final (a, b) in pairs) {
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      }
    });

    test('an exhaustive switch names every variant', () {
      // Compile-time pin: adding a variant without updating this switch
      // fails to compile, matching Rule 5's exhaustive mapping table.
      for (final failure in const <ConnectFailure>[
        BroadcastFull(),
        IceFailed(),
        SignalingRejected(),
        Timeout(),
        RateLimited(),
        ResolutionFailed(),
        NotFound(),
      ]) {
        final label = switch (failure) {
          BroadcastFull() => 'full',
          IceFailed() => 'ice',
          SignalingRejected() => 'rejected',
          Timeout() => 'timeout',
          RateLimited() => 'rateLimited',
          ResolutionFailed() => 'resolutionFailed',
          NotFound() => 'notFound',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}