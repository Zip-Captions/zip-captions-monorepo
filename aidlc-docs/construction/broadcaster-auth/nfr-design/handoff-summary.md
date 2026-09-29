# Handoff: NFR Design -> Code Generation
**Unit**: broadcaster-auth
**Date**: 2026-09-28

## Decisions Made
- Abandoned sign-in resolves via two independent mechanisms: a 2-second grace window after an app-foreground-resume with no completed callback, and a 3-minute hard timeout backstop — both map to `AuthFailed(providerId, cancelled)`; whichever resolves the attempt first cancels the other (Rule 1's single-outcome guarantee).
- `SecureDesktopLocalStorage` lives in `zip_core` (not `zip_broadcast`), for Phase 3 Zip Captions reuse (FR-1.1).
- **Corrected 2026-09-28**: there is no `app_links` subscription for this unit to own at all — `supabase_flutter` already listens internally on every non-web platform and calls `getSessionFromUrl` itself. `SupabaseAuthService` only calls `signInWithOAuth` and observes `onAuthStateChange`; NFR Design's Q3 (redirect-listener placement) is moot.
- No-credentials-in-logs enforcement is a single chokepoint: the `catch` block in `SupabaseAuthService` that maps SDK exceptions to `AuthFailure`. Audit exactly this one location at Code Generation review, not scattered catch blocks.
- Resilience timers are tested via `fake_async` (already a `zip_core` dev dependency) — no real `Timer`/`sleep` in tests.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `SupabaseAuthService` | impl | Owns: GoTrue calls (incl. `signInWithOAuth`), resilience timers, the single logging chokepoint. No `app_links` code (corrected 2026-09-28 — that's internal to `supabase_flutter`). This is the one class with the most concentrated responsibility — review it most carefully. |
| `SecureDesktopLocalStorage` | `zip_core` impl | Selected at `Supabase.initialize` via `!kIsWeb`; must not be the default on desktop under any code path (Rule 6, restated). |
| Fake `AuthService` | test double | Must support injecting a full command sequence (sign-in outcomes, sign-out, passive loss) for PBT-06; built before the stateful PBT test, reused by the Q1 resilience tests too. |
| `AuthCommand` generator | test helper | Goes in `test/helpers/generators.dart`, weighted per PBT-07 — not uniform-random. |

## Constraints
- Dependency direction is one-way: `zip_broadcast` depends on `zip_core`'s auth components, never the reverse. No code in `zip_core`'s `AuthService`/`AuthNotifier`/`SupabaseAuthService` may reference anything `zip_broadcast`-specific (including `BroadcastSessionState`, per Rule 9 — that guard is Unit 6's, not this unit's).
- The resume-heuristic's 2-second grace window and the 3-minute hard timeout are both named constants (not magic numbers) — Code Generation should define them alongside `BroadcastLimits`-style project constants, per the "configuration over code" principle already established for `BroadcastLimits`/auth providers.
- ~~`app_links` version `^7.1.1`~~ — corrected 2026-09-28: not a direct dependency, ships inside `supabase_flutter`. `supabase_flutter` itself: pin `^2.17.2` (verified at Code Generation).

## Open Questions for Next Stage
- None new from NFR Design. Still open from earlier stages (not Code Generation's to resolve): the Unit 6 `ZbAppShell` sign-out guard implementation itself (Rule 9, Backlog); whether an already-live broadcast is force-ended on sign-out (Unit 5's call, F-BA-3); crash-reporting SDK adoption (project-wide Backlog item, not this unit's).
