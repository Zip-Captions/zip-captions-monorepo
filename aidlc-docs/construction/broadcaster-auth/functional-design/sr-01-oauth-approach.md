# SR-01: OAuth Flow Approach Review

**Story**: S-15 (Broadcaster Authentication) | **Blocks**: S-15 Code Generation
**Area**: Authentication (AGENTS.md: OAuth authentication flows — pre-approval required)
**FR**: FR-1.1–FR-1.7 | **NFR**: NFR-3.8

This document is the human-approval gate required by AGENTS.md before any OAuth code is
written. It records the approach decided in `broadcaster-auth-functional-design-plan.md`
(all questions answered, Q1–Q7).

## 1. Providers (Phase 2 scope)

Google only, via Supabase GoTrue (`OAuthProvider.google`). `packages/zip_supabase/supabase/config.toml`'s
`[auth.external.google]` stub is enabled with real credentials at Infrastructure/NFR Design
time; `apple`, `azure`, `github` stay disabled, deferred to Phase 3 (FR-1.6).

## 2. Flow Type Per Platform

| Platform | Flow |
|---|---|
| macOS, Windows, Linux (desktop) | External-browser OAuth: `signInWithOAuth(OAuthProvider.google, redirectTo: 'io.zipcaptions.broadcast://login-callback')`, launched in the system default browser (`LaunchMode.externalApplication`). No embedded webview (supabase_flutter v2 dropped the webview dependency by design). |
| Web | `signInWithOAuth(OAuthProvider.google)` with `redirectTo` unset — full-page navigation to Google and back to the app's own origin; the SDK's default `detectSessionInUri` behavior picks up the session from the URL on return. No new dependency. |

## 3. Redirect Handling

**Desktop**: a custom URL scheme, `io.zipcaptions.broadcast://login-callback`, is
registered per platform:
- macOS: `CFBundleURLTypes` in `Info.plist`
- Windows: a custom protocol registration in the Windows runner (registry entry created at install/first-run)
- Linux: `x-scheme-handler/io.zipcaptions.broadcast` MIME association in the app's `.desktop` file

**Correction 1 (found during Code Generation's API verification, 2026-09-28)**:
`supabase_flutter` already bundles `app_links` internally and subscribes to its
`uriLinkStream` whenever `!kIsWeb` (confirmed by reading `supabase_auth.dart`'s
source — this covers macOS/Windows/Linux, not only mobile as originally assumed here),
calling `getSessionFromUrl` on the received URI automatically. This is gated by
`FlutterAuthClientOptions.detectSessionInUri`, which defaults to `true` — kept at its
default. This internal path is what completes a *successful* sign-in.

**Correction 2 (found while implementing `SupabaseAuthService`, same day)**: that
internal path does not surface *failures* — its own catch block only calls an
undocumented, non-public `notifyException`, so a declined consent screen or a rejected
PKCE exchange would otherwise be silently swallowed, indistinguishable from the app
simply never receiving a callback. `SupabaseAuthService` therefore runs its **own**
`app_links` subscription in parallel (added as a direct dependency, not just a
transitive one), but only to inspect the callback URI's `error` query parameter — it
never calls `getSessionFromUrl` itself, so it never races the SDK's one-shot PKCE code
consumption. Google's provider-side redirect URI (configured in Google Cloud Console
and in Supabase's Auth settings) points at Supabase's own `/auth/v1/callback`, which
then redirects to the custom scheme with either the session or an `error` param in the
fragment/query — the app itself is never a redirect target Google needs to know about.

**Web**: the provider-side redirect points at Supabase's callback, which redirects back to
the app's own origin (registered in `additional_redirect_urls`, as already scaffolded for
`localhost:3000` in `config.toml` for local dev — production origins are added at
Infrastructure Design).

Why not a loopback HTTP server (the rejected desktop alternative): it requires binding a
local port during sign-in, which is both a worse user-facing failure mode (port-in-use) and
unnecessary given the custom-scheme approach is supabase_flutter's documented pattern for
non-web platforms.

## 4. Token Storage

- **Desktop** (macOS, Windows, Linux): a custom `LocalStorage` implementation backed by
  `flutter_secure_storage` (already an approved dependency, already used for the E2E
  encryption keys per ADR-006) replaces supabase_flutter's plaintext `shared_preferences`
  default. This is registered via supabase_flutter's storage-override hook at
  `Supabase.initialize` time; the exact parameter surface is confirmed against the pinned
  `supabase_flutter` version at NFR Design / Code Generation, not re-litigated here.
- **Web**: the SDK's default browser-storage mechanism is kept. This is the standard,
  expected mechanism for a GoTrue web client, and `flutter_secure_storage`'s web backing
  (Web Crypto API + IndexedDB) adds complexity without a clear security gain over the
  browser sandbox model web already relies on.

Rationale: FR-1.3 requires tokens be "stored per the SDK's secure-storage mechanism," read
as requiring secure storage rather than accepting the plaintext desktop default — a session
token is a bearer credential, not a UI preference, and unlike mobile, desktop `shared_preferences`
is an ordinary user-readable file with no OS sandboxing equivalent.

## 5. Refresh

Handled entirely by `supabase_flutter`'s GoTrue client — no custom polling or scheduling.
`SupabaseAuthService.authStateChanges` subscribes to the SDK's `onAuthStateChange` stream,
which emits `tokenRefreshed` events as the SDK refreshes proactively before expiry
(`jwt_expiry = 3600` in `config.toml`). `AuthNotifier` republishes these into `AuthState`
without needing to distinguish a refresh from an initial sign-in — both resolve to
`signedIn(userId)`.

## 6. Sign-Out

`SupabaseAuthService.signOut()` calls the SDK's `signOut()` with server-side (global) scope
by default — this both clears local storage (wherever the platform's `LocalStorage`
implementation put it) and revokes the refresh token on Supabase's side, so a stolen token
captured before sign-out cannot be used afterward. `AuthNotifier.signOut()` transitions to
`signedOut` immediately on the local clear, without waiting on the network round-trip to
complete, since local sign-out (and therefore loss of remote-broadcast capability) is what
the user is asking for.

**Sign-out is unconditional at the `AuthNotifier` level in this unit** — it has no
visibility into broadcast state, by design (`zip_core` stays reusable for Zip Captions,
FR-1.1), and local captioning stays fully decoupled from auth (F-BA-5, FR-1.4). Blocking
sign-out entirely while `BroadcastSessionState` is non-idle (live **or** mid-`goLive()`
transition) is a hard requirement, but it is enforced one layer up, in Zip Broadcast's
Unit 6 (`ZbAppShell`), which is the only place `AuthNotifier.signOut()` may be called from
within `zip_broadcast`. See `business-rules.md` Rule 9.

## 7. Failure Handling

| `AuthFailure` | Triggered by |
|---|---|
| `cancelled` | Google's OAuth callback carries `error=access_denied` — this is what Google sends when the *user* declines or backs out of the consent screen, not when Google itself refuses the app. |
| `denied` | GoTrue/Supabase rejects the flow at the provider-configuration level (e.g. provider disabled, domain not allowlisted) — distinct from the user declining. |
| `network` | Connectivity failures opening the browser, resolving Supabase's callback, or completing the token exchange (`SocketException`, timeout). |
| `providerError` | Any other OAuth-flow outcome, including unrecognized `error` query params and any unexpected exception. Per the plan's Q6: the underlying exception's **type and stack trace** (never its message) are logged at the point of folding into `providerError`, so a real bug isn't indistinguishable from a legitimate provider rejection during triage — without adding UI-facing granularity Proto-10 doesn't need. |
| `sessionExpired` | A background token refresh fails because GoTrue reports the refresh token itself is invalid/expired. Per S-15's acceptance criteria ("the user is signed out gracefully... prompted to sign in again only when needed"), this path transitions `AuthNotifier` directly to `signedOut`, **not** to `failed(sessionExpired)` — there is no active user action to report a failure against. `sessionExpired` as an `AuthFailure` value is reserved for the case where a user-initiated action (e.g. retrying sign-in) synchronously discovers the existing session is already gone. |

No token, authorization code, or credential is ever included in a log line for any of the
above (NFR-3.8) — only enum values, exception types, and stack traces.

## 8. Configuration-Only Provider Addition (FR-1.2)

`AuthProviderConfig` is populated from a single static Dart list in a dedicated config file
in `zip_broadcast` (not inlined into `AuthNotifier` or `AuthService` logic), e.g.:

```dart
const enabledAuthProviders = [
  AuthProviderOption(id: 'google', displayLabel: 'Google', provider: OAuthProvider.google),
];
```

`SupabaseAuthService.signIn(providerId)` looks up the matching `OAuthProvider` from this
list generically — there is no per-provider branch in service logic. Adding a provider in
Phase 3 means: one new list entry, enabling it in Supabase's auth config, and registering
any additional platform redirect scheme if needed — no change to `AuthService`,
`AuthNotifier`, or the sign-in view's logic. A real dynamic/remote-config source is out of
scope for Phase 2 (deferred to Phase 3, per the plan's Q5).

## 9. New Dependencies Introduced

| Package | Purpose | Approval status |
|---|---|---|
| `app_links` | Already present transitively via `supabase_flutter` (Correction 1, Section 3). Declared as a **direct** dependency because `SupabaseAuthService` runs its own subscription to observe OAuth failures the SDK's internal handler doesn't surface (Correction 2, Section 3) — inspecting the callback URI's `error` param only, never calling `getSessionFromUrl` itself. | Approved as part of this SR-01 sign-off (2026-09-28, revised same day). No separate justification beyond this document — it was already going to be present in the dependency tree either way. |

`supabase_flutter` and `flutter_secure_storage` are both already on the pre-approved
list and need no separate justification.

## 10. Approval

- [x] **Approved** — this approach may proceed to NFR Requirements and, eventually, Code Generation for S-15.

Approved by: James Petersen  Date: 2026-09-28
