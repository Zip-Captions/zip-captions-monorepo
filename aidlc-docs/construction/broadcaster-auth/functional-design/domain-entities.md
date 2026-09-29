# Domain Entities — Broadcaster Auth

## AuthState (sealed)

```
AuthState = SignedOut
          | SigningIn(providerId: String)
          | SignedIn(userId: String)
          | AuthFailed(providerId: String, reason: AuthFailure)
```

- `SignedOut` is the initial state and the state after `signOut()` completes locally.
- `SigningIn(providerId)` exists only between `AuthNotifier.signIn(providerId)` being
  called and the flow resolving (success, cancellation, or error) — it is transient, never
  restored across app restarts (Session Restore always resolves directly to `SignedOut` or
  `SignedIn`). Carrying `providerId` here (not just on the failure case) keeps the shape
  consistent and lets the UI highlight the specific button mid-flow without separate widget
  state — Phase 2 only ever has one, but Phase 3's multi-provider UI needs this.
- `SignedIn(userId)` carries only the Supabase user id — no email, display name, avatar, or
  tokens. (Account display info for the sign-in view, if shown at all, is read separately
  from the SDK's current session object by the UI layer, not carried on `AuthState`.)
- `AuthFailed(providerId, reason)` is only ever entered as a direct result of a
  user-initiated `signIn(providerId)` call failing. A passive background failure (refresh
  failure) goes to `SignedOut` instead — see `business-rules.md` Rule 3. Carrying
  `providerId` means a retry affordance (or, in Phase 3, per-provider failure messaging)
  never has to be reconstructed from view-local memory — see `frontend-components.md`.

## AuthFailure (enum)

```
AuthFailure = cancelled | denied | network | providerError | sessionExpired
```

See `sr-01-oauth-approach.md` Section 7 for the full trigger-to-value mapping. Invariant:
exactly one value is chosen per failed attempt — these are not flags, and a failure is
never left unmapped (an unrecognized exception always resolves to `providerError`, never
propagates as an uncaught exception out of `AuthService`).

## AuthProviderOption / AuthProviderConfig

```
AuthProviderOption = { id: String, displayLabel: String, provider: OAuthProvider }
AuthProviderConfig = { providers: List<AuthProviderOption> }
```

- `id` is the stable identifier `AuthNotifier.signIn(providerId)` is called with — it is
  never the raw `OAuthProvider` enum value directly, so the sign-in view only ever depends
  on `AuthProviderConfig`, never on `package:supabase_flutter` types.
- Invariant: `providers` is never empty in a running app (Phase 2 ships with exactly one
  entry — Google). An empty list is a configuration error, not a runtime state to render
  around.
- `displayLabel` is what Proto-10's provider button renders; it is not localized in Phase 2
  (provider brand names are conventionally shown as-is, matching Proto-10's mockup copy).

## Relationships

- `AuthNotifier` exposes `AuthState` (from `AuthService.authStateChanges`) and reads
  `AuthProviderConfig` (static, injected) to know which provider buttons exist.
- `AuthService.signIn(providerId)` resolves `providerId` against `AuthProviderConfig`
  internally (via `SupabaseAuthService`) to get the `OAuthProvider` enum value GoTrue needs
  — this resolution is the one place provider identity crosses from config into SDK calls.
