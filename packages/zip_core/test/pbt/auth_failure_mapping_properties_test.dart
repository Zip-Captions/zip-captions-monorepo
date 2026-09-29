// PBT-03 invariant: for any exception the OAuth flow can plausibly raise,
// SupabaseAuthService's mapping always yields exactly one AuthFailure value
// — the attempt never gets stuck in SigningIn and no exception ever escapes
// uncaught (testable-properties.md row 1, business-rules.md Rule 9).

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:zip_core/src/models/auth_failure.dart';
import 'package:zip_core/src/models/auth_provider_option.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/services/auth/supabase_auth_service.dart';

import '../helpers/pbt.dart' as pbt;

class _MockSupabaseClient extends Mock implements sb.SupabaseClient {}

class _MockGoTrueClient extends Mock implements sb.GoTrueClient {}

const _config = AuthProviderConfig(
  providers: [
    AuthProviderOption(
      id: 'google',
      displayLabel: 'Google',
      provider: sb.OAuthProvider.google,
    ),
  ],
);

final pbt.Generator<Object> _arbitraryOAuthException = pbt.any.choose<Object>([
  sb.AuthRetryableFetchException(message: 'network down'),
  const sb.AuthException('provider disabled'),
  const sb.AuthException('provider disabled', statusCode: '400'),
  StateError('unexpected internal state'),
  ArgumentError('bad argument'),
  const FormatException('bad response body'),
  Exception('generic failure'),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(sb.OAuthProvider.google);
  });

  pbt.Glados(_arbitraryOAuthException).test(
    'every OAuth-flow exception maps to exactly one AuthFailure',
    (exception) async {
      final client = _MockSupabaseClient();
      final gotrue = _MockGoTrueClient();
      when(() => client.auth).thenReturn(gotrue);
      when(() => gotrue.currentUser).thenReturn(null);
      when(() => gotrue.onAuthStateChange)
          .thenAnswer((_) => const Stream.empty());
      when(
        () => gotrue.getOAuthSignInUrl(
          provider: any(named: 'provider'),
          redirectTo: any(named: 'redirectTo'),
        ),
      ).thenThrow(exception);

      final service = SupabaseAuthService(
        client: client,
        providerConfig: _config,
      );
      final failedState = service.authStateChanges
          .firstWhere((s) => s is AuthFailedState)
          .timeout(const Duration(seconds: 1));

      await service.signIn('google');
      final failed = await failedState as AuthFailedState;

      expect(AuthFailure.values, contains(failed.reason));
      expect(failed.providerId, 'google');
      service.dispose();
    },
  );
}
