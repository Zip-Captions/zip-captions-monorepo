import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/auth_provider_option.dart';

import '../helpers/pbt.dart';

const _google = AuthProviderOption(
  id: 'google',
  displayLabel: 'Google',
  provider: OAuthProvider.google,
);
const _github = AuthProviderOption(
  id: 'github',
  displayLabel: 'GitHub',
  provider: OAuthProvider.github,
);

final Generator<AuthProviderOption> _arbitraryProviderOption =
    any.choose([_google, _github]);

void main() {
  group('AuthProviderOption', () {
    test('equality compares all fields', () {
      const a = AuthProviderOption(
        id: 'google',
        displayLabel: 'Google',
        provider: OAuthProvider.google,
      );
      const b = AuthProviderOption(
        id: 'google',
        displayLabel: 'Google',
        provider: OAuthProvider.google,
      );
      expect(a, equals(b));
    });
  });

  group('AuthProviderConfig', () {
    test('holds the given provider list', () {
      const config = AuthProviderConfig(providers: [_google]);
      expect(config.providers, [_google]);
    });

    // PBT-03 invariant (testable-properties.md row 4, Code Generation Step
    // 2): for any generated non-empty list of AuthProviderOption, the
    // resulting config's .providers has the same length and elements.
    Glados(any.listWithLengthInRange(1, 5, _arbitraryProviderOption)).test(
      'providers preserves length and elements for any non-empty list',
      (options) {
        final config = AuthProviderConfig(providers: options);
        expect(config.providers, hasLength(options.length));
        expect(config.providers, equals(options));
      },
    );
  });
}
