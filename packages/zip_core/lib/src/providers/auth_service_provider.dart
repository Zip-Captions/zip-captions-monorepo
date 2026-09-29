import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/auth/auth_service.dart';

part 'auth_service_provider.g.dart';

/// Provides the app's [AuthService].
///
/// The concrete implementation (a `SupabaseAuthService` configured with the
/// app's own `AuthProviderConfig`) is registered at app startup via provider
/// overrides, matching `supabaseClientProvider`'s pattern. This provider
/// throws by default if no override is supplied.
@Riverpod(keepAlive: true)
AuthService authService(Ref ref) {
  throw UnimplementedError(
    'authServiceProvider must be overridden at app startup with a '
    'SupabaseAuthService configured for this app.',
  );
}
