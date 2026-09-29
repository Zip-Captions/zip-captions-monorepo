# Tech Stack Decisions — Broadcaster Auth (Unit 2)

## New Dependencies

### app_links (direct dependency, revised 2026-09-28)

`supabase_flutter` already depends on and internally subscribes to `app_links`'s
`uriLinkStream` on every non-web platform (confirmed from `supabase_auth.dart`'s
source), which is what completes a *successful* sign-in automatically. It does not,
however, surface *failures* — its internal handler swallows them (calls a non-public
`notifyException`). `SupabaseAuthService` therefore adds `app_links` as a **direct**
dependency (`^7.0.0`, already present transitively either way) and runs its own
parallel subscription, inspecting only the callback URI's `error` query parameter —
never calling `getSessionFromUrl` itself, so it never races the SDK's one-shot PKCE
code consumption. See `sr-01-oauth-approach.md` Section 3, Corrections 1 and 2.

The platform-level custom-URL-scheme *registration* (Info.plist, Windows/Linux) remains
required and unaffected — that's what gets the callback to the app process at all.

### flutter_secure_storage (already approved project-wide; newly used in the auth path)

| | |
|---|---|
| **Version** | `^9.2.2` — matches the existing pin already in `zip_broadcast`'s `pubspec.yaml` (used elsewhere in the app). No version drift introduced. |
| **Purpose here** | Backs a custom `LocalStorage` implementation for `supabase_flutter`'s session storage override on desktop (SR-01 §4), replacing the SDK's plaintext `shared_preferences` default. |
| **Approval status** | Already on the pre-approved dependency list (`docs/04-technical-specification.md` Section 6) — no new justification needed, only the specific usage (auth session storage) is new. |

## Testing Framework (PBT-09)

**Decision**: reuse `packages/zip_core/test/helpers/pbt.dart` — the project's existing
lightweight `Glados`-compatible shim — rather than adding the real `glados` pub.dev
package.

**Why**: `glados` is incompatible with Dart 3 (documented at the top of the existing
shim file, written when Phase 1's `core-abstractions` and `platform-stt-audio` units
adopted PBT). The shim already provides `Generator<T>`, the `any` namespace of
constrained-domain generators, and a `Glados(...).test(...)` runner that executes 100
seeded trials per property with reproducible `Random` instances (satisfies PBT-08's
shrinking/reproducibility requirement at the framework level — trials are seeded and
re-runnable, though the shim does not implement true shrinking to a minimal failing case;
this is an accepted limitation carried over from the Phase 1 units, not newly introduced
here).

This unit needs one addition to the shim's generator set: a generator for
`AuthNotifier` command sequences (the stateful property in `testable-properties.md`) —
i.e. a `Generator<List<AuthCommand>>` where `AuthCommand` is a small sealed type
(`SignIn(outcome)`, `SignOut`, `PassiveSessionLoss`) with a realistic outcome-weighting
(per PBT-07), not a uniform pick across all `AuthFailure` values. This generator is
written at Code Generation, in `test/helpers/generators.dart` alongside the project's
other domain generators (consistent with PBT-07's "centralized and reusable" requirement).

## Mocking Strategy (NFR-7.3, Q2)

- **`mocktail`** (already an approved dependency, used throughout the project) for
  interaction-style assertions on `AuthService` (e.g. verifying `signIn(providerId)` was
  called with the expected argument from `AuthNotifier`).
- **A hand-written fake `AuthService`** (not a `mocktail` mock) for the stateful PBT: it
  must hold internal state and emit a driven sequence of `authStateChanges` events over
  the course of a test, which a call-verification mock isn't built for. This fake lives
  in `zip_core`'s test helpers, scoped to this unit's tests.

## Error/Crash Reporting (Q3)

No new dependency. Continue using the existing `logging` package (`Logger`, configured in
`zip_broadcast/lib/main.dart`) for the `providerError` catch-all's type/stack-trace log
(Rule 9). A project-wide crash-reporting SDK is explicitly deferred — see the Backlog
entry in `aidlc-docs/aidlc-state.md`.
