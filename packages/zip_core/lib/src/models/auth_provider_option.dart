import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

part 'auth_provider_option.freezed.dart';

/// A single enabled OAuth provider choice, configuration-driven (FR-1.2).
///
/// [id] is the stable identifier `AuthNotifier.signIn` is called with — the
/// sign-in view depends only on this, never on [provider] directly, which is
/// resolved to the SDK's [OAuthProvider] enum only inside
/// `SupabaseAuthService` (Rule 5 of `business-rules.md`).
@freezed
abstract class AuthProviderOption with _$AuthProviderOption {
  /// Creates an [AuthProviderOption].
  const factory AuthProviderOption({
    /// Stable identifier passed to `AuthNotifier.signIn`/`AuthService.signIn`.
    required String id,

    /// Label rendered on the provider's sign-in button (not localized in
    /// Phase 2 — provider brand names are shown as-is).
    required String displayLabel,

    /// The GoTrue provider this option resolves to.
    required OAuthProvider provider,
  }) = _AuthProviderOption;
}

/// The enabled OAuth providers for this app, configuration-driven (FR-1.2).
///
/// Never empty at runtime (`business-rules.md` Rule 7) — an empty list is a
/// configuration defect to catch before release, not a state the sign-in
/// view renders around.
@freezed
abstract class AuthProviderConfig with _$AuthProviderConfig {
  /// Creates an [AuthProviderConfig].
  const factory AuthProviderConfig({
    /// The enabled providers, in display order.
    required List<AuthProviderOption> providers,
  }) = _AuthProviderConfig;
}
