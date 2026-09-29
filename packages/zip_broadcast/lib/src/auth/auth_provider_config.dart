import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/zip_core.dart';

/// The enabled OAuth providers for Zip Broadcast in Phase 2 — Google only
/// (`sr-01-oauth-approach.md` Section 8). Adding a provider later is a new
/// entry here, never a code change to `AuthService`/`AuthNotifier`.
const zipBroadcastAuthProviderConfig = AuthProviderConfig(
  providers: [
    AuthProviderOption(
      id: 'google',
      displayLabel: 'Google',
      provider: OAuthProvider.google,
    ),
  ],
);
