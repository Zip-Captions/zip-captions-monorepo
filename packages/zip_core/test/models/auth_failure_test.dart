import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/auth_failure.dart';

void main() {
  group('AuthFailure', () {
    test('has exactly the five values fixed by SR-01 Section 7', () {
      expect(
        AuthFailure.values,
        containsAll(<AuthFailure>[
          AuthFailure.cancelled,
          AuthFailure.denied,
          AuthFailure.network,
          AuthFailure.providerError,
          AuthFailure.sessionExpired,
        ]),
      );
      expect(AuthFailure.values, hasLength(5));
    });
  });
}
