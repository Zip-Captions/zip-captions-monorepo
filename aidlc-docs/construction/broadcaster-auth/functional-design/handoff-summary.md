# Handoff: Functional Design -> NFR Requirements
**Unit**: broadcaster-auth
**Date**: 2026-09-28

## Decisions Made
- Phase 2 ships exactly one OAuth provider: Google.
- Desktop uses external-browser OAuth + custom URL scheme (`io.zipcaptions.broadcast://login-callback`); web uses the SDK's default full-page redirect. **Correction (2026-09-28, at Code Generation)**: `app_links` is not a new dependency — `supabase_flutter` already bundles and wires it internally on every non-web platform (confirmed from its source); this unit only needs the OS-level scheme registration, not an app-level listener.
- Token storage: custom `flutter_secure_storage`-backed `LocalStorage` on desktop (macOS/Windows/Linux); SDK default browser storage kept on web.
- Refresh is entirely SDK-managed (no custom scheduling); background refresh failure routes to `SignedOut`, never to `AuthFailed`.
- `AuthProviderConfig` is a static Dart list in a dedicated config file — no dynamic/remote config in Phase 2.
- Failure taxonomy stays at the existing 5 `AuthFailure` values; unmapped exceptions fold into `providerError` with type+stacktrace logged (never message) for triage.
- `AuthState` now carries `providerId` on both `SigningIn` and `AuthFailed`, ahead of Phase 3's multi-provider UI.
- Sign-out stays unconditional at the `AuthNotifier`/`zip_core` level (must stay reusable for Zip Captions, FR-1.1); blocking sign-out during an active broadcast is a **Unit 6** responsibility (`ZbAppShell` guard, sole call path to `signOut()`) — not implemented in this unit. Backlog entry added to `aidlc-state.md`.
- SR-01 approach document is drafted and awaiting explicit human approval (see Section 10 of `sr-01-oauth-approach.md`) — do not start Code Generation before that checkbox is signed off, per AGENTS.md.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `AuthService` / `SupabaseAuthService` | interface / impl | No tokens cross the interface; storage override is mandatory on desktop (Rule 6) |
| `AuthState` / `AuthFailure` | sealed model / enum | Fixed shapes in `domain-entities.md` — NFR Design should not add cases without revisiting SR-01 |
| `AuthProviderConfig` | static config | Never empty at runtime (Rule 7) |
~~`app_links` | new dependency~~ | **Corrected 2026-09-28**: already an internal `supabase_flutter` dependency, not a new one this unit adds. |

## Constraints
- No credential material (tokens, auth codes, full callback URLs, raw SDK exception messages) may appear in logs anywhere in this unit (Rule 4, NFR-3.8) — NFR Requirements should turn this into a concrete, testable logging constraint.
- `flutter_secure_storage` must actually be wired on desktop before this unit is considered done — plaintext fallback is a defect, not a degraded mode (Rule 6).
- Session restore at app start must not block on a network round trip (F-BA-2).

## Open Questions for Next Stage
- Should `AuthFailure` eventually carry the attempted `providerId`? Not needed for Phase 2's single-provider case, but worth deciding before Phase 3 (source: `frontend-components.md` Open Question).
- Whether an already-live broadcast is force-ended on sign-out is explicitly out of scope here and deferred to Unit 5 (source: F-BA-3).
- Exact `supabase_flutter` API surface for the `LocalStorage` override (parameter name/shape) is to be confirmed against the pinned package version, not assumed from SR-01's general description (source: SR-01 Section 4).
