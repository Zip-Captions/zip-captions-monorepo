# Code Generation Plan: Broadcaster Auth (Unit 2)

**Unit**: broadcaster-auth | **Branch**: `feature/broadcaster-auth` (off `develop`)
**Prior stages**: Functional Design + SR-01, NFR Requirements, NFR Design — all approved 2026-09-28.
**Workspace root**: `/Users/oblivious/Documents/zip-captions-monorepo` (brownfield — modify existing files in place, never create `*_new.dart`/`*_modified.dart`).

## Unit Context

- **Stories**: S-15 (Broadcaster Authentication), gated by SR-01 (approved).
- **Dependencies**: Proto-10 (approved, Unit 1). No spike dependency. This unit itself is a dependency for Unit 3 (S-11, authenticated identity for RLS).
- **Interfaces/contracts this unit defines** (fixed at Functional Design, restated at NFR Design): `AuthService`, `AuthState`, `AuthFailure`, `AuthProviderConfig`/`AuthProviderOption`, `AuthNotifier` — all in `zip_core`, consumed by `zip_broadcast` now and (unchanged, per FR-1.1) by Zip Captions in Phase 3.
- **No database entities** owned by this unit (Supabase Auth's own user table is GoTrue-managed, not a migration this unit writes).
- **Service boundary**: `zip_core` owns all auth logic and never references `zip_broadcast`; `zip_broadcast` owns only the static provider config and the sign-in view.

This plan executes the decisions already recorded in `aidlc-docs/construction/broadcaster-auth/{functional-design,nfr-requirements,nfr-design}/`. No new design decisions are made here — where a plan step needs a specific constant, exception type, or file path, it cites the artifact that already fixed it.

---

## Step 1: `zip_core` — Domain Models
**Files**: `packages/zip_core/lib/src/models/auth_state.dart` (new), `packages/zip_core/lib/src/models/auth_failure.dart` (new), `packages/zip_core/lib/src/models/auth_provider_option.dart` (new)
- [x] `AuthState` sealed class: `SignedOut`, `SigningIn(providerId)`, `SignedIn(userId)`, `AuthFailed(providerId, reason)` — shape per `domain-entities.md`. **Deviation**: implemented as a plain `sealed class` with `const` subclasses (matching the existing `RecordingState` convention — const canonicalization gives structural equality for free), not `freezed`, since this is a state machine like `RecordingState`, not a `freezed`-style value model.
- [x] `AuthFailure` enum: `cancelled, denied, network, providerError, sessionExpired` — per `sr-01-oauth-approach.md` §7.
- [x] `AuthProviderOption` (`id`, `displayLabel`, `provider: OAuthProvider`) and `AuthProviderConfig` (`providers: List<AuthProviderOption>`) — per `domain-entities.md`. Implemented with `freezed` (matches `AudioInputConfig`'s convention for simple value objects).
- Story: S-15. No dependency.

## Step 2: `zip_core` — Domain Model Unit Tests
**Files**: `packages/zip_core/test/models/auth_state_test.dart`, `auth_failure_test.dart`, `auth_provider_option_test.dart` (new)
- [x] Example-based: each `AuthState` variant constructs and equates correctly.
- [x] Invariant PBT (`testable-properties.md` row 4, applied at the model level): a generated non-empty `List<AuthProviderOption>` always produces an `AuthProviderConfig` whose `.providers` has the same length and elements — using the existing `test/helpers/pbt.dart` shim, not real `glados`.
- Story: S-15. Depends on: Step 1.

## Step 3: `zip_core` — `AuthService` Interface
**File**: `packages/zip_core/lib/src/services/auth/auth_service.dart` (new)
- [x] `abstract interface class AuthService` — `authStateChanges`, `currentUserId`, `signIn(providerId)`, `signOut()` — per `phase2-component-methods.md` §1 and `sr-01-oauth-approach.md`.
- No test (interface only). Story: S-15. Depends on: Step 1 (uses `AuthState`).

## Step 4: `zip_core` — `supabaseClientProvider`
**File**: `packages/zip_core/lib/src/providers/supabase_client_provider.dart` (new)
- [x] `@Riverpod(keepAlive: true)` provider throwing `UnimplementedError` unless overridden — mirror `audio_device_service_provider.dart` exactly (pattern fixed at Functional Design). Also added `authServiceProvider` (same pattern) as a small structural gap-fill not called out as its own step in this plan — `AuthNotifier` needs a Riverpod seam to obtain its `AuthService`, exactly like `supabaseClientProvider`.
- Story: S-15. No dependency (independent provider).

## Step 5: `zip_core` — `SecureDesktopLocalStorage`
**File**: `packages/zip_core/lib/src/services/auth/secure_desktop_local_storage.dart` (new)
- [x] `LocalStorage` (from `supabase_flutter`) implementation wrapping `flutter_secure_storage`'s `FlutterSecureStorage` — per `nfr-design-patterns.md`'s Storage Strategy pattern. Used only when `!kIsWeb`.
- Story: S-15 (NFR-3.8/SR-01 §4). Depends on: none (standalone).

## Step 6: `zip_core` — `SecureDesktopLocalStorage` Unit Tests
**File**: `packages/zip_core/test/services/auth/secure_desktop_local_storage_test.dart` (new)
- [x] Example-based: write/read/delete round trip against a fake/mocked `FlutterSecureStorage` backend (`mocktail`).
- [x] Confirms no plaintext fallback path exists (Rule 6).
- Depends on: Step 5.

## Step 7: `zip_core` — Fake `AuthService` Test Double
**File**: `packages/zip_core/test/helpers/fake_auth_service.dart` (new)
- [x] Stream-driven fake implementing `AuthService`: exposes a way to programmatically push `AuthState` values onto `authStateChanges` on command, for the stateful PBT (Step 11) and resilience tests (Step 10). Not a `mocktail` mock — must hold and emit state across a sequence (NFR-7.3, PBT-06).
- No test of its own (test infrastructure). Depends on: Step 3.

## Step 8: `zip_core` — `AuthCommand` PBT Generator
**File**: `packages/zip_core/test/helpers/generators.dart` (modified — add to existing file)
- [x] `AuthCommand` sealed type (`SignIn(outcome)`, `SignOut`, `PassiveSessionLoss`) and a `Generator<List<AuthCommand>>` weighted toward realistic sequences (sign-in-then-succeed, sign-in-then-retry, sign-in-then-sign-out) while still covering adversarial orderings (PBT-07, per `testable-properties.md`'s "Carried to Code Generation" note).
- Depends on: Step 1 (uses `AuthFailure`).

## Step 9: `zip_core` — `SupabaseAuthService` Implementation
**File**: `packages/zip_core/lib/src/services/auth/supabase_auth_service.dart` (new)
- [x] Implements `AuthService` against `supabaseClientProvider`'s `SupabaseClient`.
- [x] `signIn(providerId)`: resolves `providerId` against the injected `AuthProviderConfig` (Rule 5 — no `OAuthProvider` leaks past this class), calls `signInWithOAuth(provider, redirectTo: ..., authScreenLaunchMode: LaunchMode.externalApplication on desktop)` with the platform-appropriate `redirectTo` (desktop custom scheme vs. web default) per `sr-01-oauth-approach.md` §2–3.
- [x] **Revised 2026-09-28 (twice)**: `supabase_flutter` already subscribes to `app_links` internally for the *successful* path (`getSessionFromUrl`, `detectSessionInUri` default `true`) — but its internal failure handling is swallowed (non-public `notifyException`), so this class runs its **own** parallel `app_links` subscription, inspecting only the callback URI's `error` query parameter (never calling `getSessionFromUrl` itself, to avoid racing the SDK's one-shot PKCE code). See `sr-01-oauth-approach.md` §3, Corrections 1 and 2.
- [x] Resilience (NFR Design Q1): named constants for the 2-second foreground-resume grace window (via `AppLifecycleListener(onResume: ...)`, not a `WidgetsBindingObserver` mixin, since this is a plain Dart class) and the 3-minute hard timeout; both cancelled the instant the attempt resolves through any other path; either backstop resolves to `AuthFailed(providerId, cancelled)`.
- [x] Single exception→`AuthFailure` mapping chokepoint (the one `catch`, per `sr-01-oauth-approach.md` §7 table): logs the exception's **type and stack trace only** (never message) via the existing `logging` package's `Logger` before mapping.
- [x] `signOut()`: global-scope SDK sign-out, per §6.
- Story: S-15 (all ACs). Depends on: Steps 1, 3, 4, 5.

## Step 10: `zip_core` — `SupabaseAuthService` Unit Tests
**File**: `packages/zip_core/test/services/auth/supabase_auth_service_test.dart` (new)
- [x] Example-based, one per named `AuthFailure` scenario in S-15's acceptance criteria (`cancelled` via `access_denied`, `denied`, `network`, `providerError` catch-all incl. an unrecognized exception, `sessionExpired` on background refresh failure routing to `SignedOut` not `AuthFailed` — per Rule 3).
- [x] `mocktail`-mocked Supabase client/GoTrue calls for interaction assertions (`signIn` reaches the SDK with the resolved provider — via `getOAuthSignInUrl`, since `signInWithOAuth` is an unmockable extension method, discovered while writing this step; `signOut` called with global scope).
- [x] Resilience tests (NFR Design Q1) driven via `fake_async` (hard timeout) and `testWidgets` (resume grace, needs real lifecycle events) — no real `Timer`/`sleep`.
- [x] Verifies the logging chokepoint: an unmapped exception logs type+stack trace and never logs its message or any token-shaped string (Rule 4/9).
- **Bug found and fixed while writing this step**: `authStateChanges`'s original `async*` implementation had a subscribe race — a fresh listener's underlying subscription to the broadcast state stream attached one microtask late, so a state change immediately after subscribing (exactly what every test here does) could be silently missed. Fixed by switching to `Stream.multi`, which attaches synchronously on listen. Full `zip_core` test suite (361 tests) re-run clean after the fix.
- Depends on: Step 9.

## Step 11: `zip_core` — Stateful PBT for the Auth State Machine
**File**: `packages/zip_core/test/pbt/auth_state_machine_properties_test.dart` (new)
- [x] PBT-06 stateful test: runs generated `AuthCommand` sequences (Step 8) against a real `AuthNotifier` (Step 13) wired to the fake `AuthService` (Step 7), asserting against a simplified reference model — `AuthFailed` only follows a failed `SigningIn` for the same `providerId` (never a passive loss), `SignedOut` is always reachable and idempotence-safe from it (`testable-properties.md` row 3).
- Depends on: Steps 7, 8, 13.

## Step 12: `zip_core` — Failure-Mapping Invariant PBT
**File**: `packages/zip_core/test/pbt/auth_failure_mapping_properties_test.dart` (new)
- [x] PBT-03 invariant: for any generated exception type/shape the OAuth flow can plausibly raise, the mapping in Step 9 always yields exactly one `AuthFailure` — never an uncaught exception (`testable-properties.md` row 1).
- Depends on: Step 9.

## Step 13: `zip_core` — `AuthNotifier`
**File**: `packages/zip_core/lib/src/providers/auth_notifier.dart` (new)
- [x] `@Riverpod(keepAlive: true)` notifier per `phase2-component-methods.md` §1: `build()` reads `AuthService.currentUserId` synchronously for session restore (F-BA-2); `signIn(providerId)` sets `SigningIn(providerId)` synchronously before awaiting `AuthService.signIn` (NFR Design's performance pattern); `signOut()` (Rule 2, Rule 8 idempotence); Rule 1's single-in-flight guard.
- Story: S-15 (orchestration, F-BA-1 through F-BA-9). Depends on: Steps 1, 3.

## Step 14: `zip_core` — `AuthNotifier` Unit Tests
**File**: `packages/zip_core/test/providers/auth_notifier_test.dart` (new)
- [x] Example-based per F-BA-1 (sign-in success), F-BA-2 (restore, no network block), F-BA-3/Rule 8 (sign-out, idempotent), F-BA-6 (failure passthrough), F-BA-7 (passive loss → `SignedOut` not `AuthFailed`), Rule 1 (concurrent `signIn` no-op while `SigningIn`).
- [x] Uses the fake `AuthService` (Step 7) via direct injection, not the real `SupabaseAuthService`.
- Depends on: Steps 7, 13.

## Step 15: `zip_broadcast` — `AuthProviderConfig` Instance
**File**: `packages/zip_broadcast/lib/src/auth/auth_provider_config.dart` (new)
- [x] `zipBroadcastAuthProviderConfig` (single Google entry) — per `sr-01-oauth-approach.md` §8. Single static list, no branching logic. **Delegation note**: originally assigned to Qwen (`unit-plan-delegation.md`); two consecutive delegation attempts crashed with an identical internal backend error before producing any files (see `~/Documents/qwen-orchestrator/runs/zip-captions/broadcaster-auth/delegation-log.md`); Claude took Steps 15–17 over directly.
- Story: S-15 (FR-1.2, AC9). Depends on: Step 1.

## Step 16: `zip_broadcast` — Sign-In View (`AccountSection`)
**File**: `packages/zip_broadcast/lib/src/screens/account_section.dart` (new)
- [x] Renders `AuthState` per `frontend-components.md`'s state table, matching Proto-10 (`zip-broadcast-sign-in.html`) states/copy: signed-out (provider button list from `AuthProviderConfig`), signing-in (spinner on the tapped button, per Q1's provider-carrying state), signed-in (account row + sign-out button), auth-failure (generic alert + retry using `AuthFailed.providerId`). All copy localized via `app_en.arb`.
- [x] `data-testid`-equivalent stable widget keys for automation, following Proto-10's naming convention.
- [x] Does not call `AuthNotifier.signOut()` from anywhere except this widget in this unit — Unit 6's `ZbAppShell` guard (Rule 9) supersedes this call site later, not addressed here.
- Story: S-15 (AC1–AC6, AC9). Depends on: Steps 13, 15.

## Step 17: `zip_broadcast` — Sign-In View Widget Tests
**File**: `packages/zip_broadcast/test/widgets/account_section_test.dart` (new)
- [x] One widget test per `AuthState` variant renders the expected Proto-10-matching UI.
- [x] Tap wiring: provider button → `signIn(providerId)`, sign-out button → `signOut()`, retry button → `signIn(AuthFailed.providerId)` — verified via a hand-written fake `AuthNotifier` subclass + `ProviderScope` override (not `mocktail`, since `AuthNotifier` is a generated Riverpod class — extending it directly was simpler than mocking through the generated base).
- Depends on: Step 16.

## Step 18: `zip_broadcast` — `main.dart` Supabase Initialization
**File**: `packages/zip_broadcast/lib/main.dart` (modified)
- [x] `Supabase.initialize` with the desktop/web-conditional storage override (`SecureDesktopLocalStorage` on `!kIsWeb`, SDK default on web — SR-01 §4), following the existing `sharedPreferencesProvider.overrideWithValue` pattern already in this file for the new `supabaseClientProvider` override.
- Story: S-15. Depends on: Steps 4, 5.

## Step 19: `zip_captions` — `main.dart` Supabase Initialization
**File**: `packages/zip_captions/lib/main.dart` (modified)
- [x] Same `Supabase.initialize` + `supabaseClientProvider` override as Step 18 — no sign-in UI, no `AuthProviderConfig`/`AccountSection` (out of scope for Zip Captions in Phase 2, per S-15's "Out of scope (Phase 3): viewer sign-in UI"). This exists so `zip_core`'s auth components are wired identically in both apps, ready for Phase 3.
- Story: S-15 (FR-1.1's reuse intent, not a new AC). Depends on: Steps 4, 5.

## Step 20: Desktop Platform Redirect Registration
**Files**: `packages/zip_broadcast/macos/Runner/Info.plist` (modified), `packages/zip_broadcast/windows/runner/main.cpp` (modified), `packages/zip_broadcast/linux/` (not modified — see below)
- [x] **macOS**: `CFBundleURLTypes` added to `Info.plist` registering `io.zipcaptions.broadcast://`. Confirmed no `AppDelegate.swift` change is needed — that's only required for HTTPS universal links (`NSUserActivity`/associated domains), not custom URL schemes, which macOS delivers via Apple Events that `app_links`'s own plugin registration (already present, confirmed in `GeneratedPluginRegistrant.swift`) handles automatically once the scheme is declared.
- [x] **Windows**: `main.cpp` updated with the `app_links` plugin's documented integration point (`#include <app_links/app_links_plugin_c_api.h>` + `SendAppLinkToInstance()` at the top of `wWinMain`, forwarding a second-instance launch via the custom scheme to the already-running instance). **Not done**: the actual `io.zipcaptions.broadcast://` registry key registration itself — `app_links`'s own docs describe this as something the app registers at runtime via the `win32_registry` package (a new dependency, not yet added or approved) rather than something `flutter pub get`/the plugin does automatically. This is a real gap, not a false-confidence guess — flagged explicitly rather than silently attempted, since I have no Windows machine to build or verify against here.
- [ ] **Linux**: not attempted. `app_links`'s GTK runner integration (`linux/my_application.cc`) requires a specific patch (application-flag and command-line-handling changes) that the fetched documentation described narratively but did not show verbatim in full; guessing at hand-written GTK/C code I cannot compile or test here risks silently breaking the Linux build. Left untouched, flagged as a known gap.
- Story: S-15 (AC1, macOS and Windows launch path only — Linux OAuth sign-in is not yet functional). Depends on: none (platform config, parallel to Dart code).
- **Human follow-up needed**: complete and verify the Windows registry registration (decide on `win32_registry` as a new direct dependency, or an installer-time registration instead) and the Linux GTK runner patch, each on their own platform where a real build is possible. Both are flagged as an open item, not silently skipped.

## Step 21: Dependency Manifest Updates
**Files**: `packages/zip_core/pubspec.yaml`, `packages/zip_broadcast/pubspec.yaml`, `packages/zip_captions/pubspec.yaml` (modified)
- [x] `zip_core`: add `supabase_flutter: ^2.17.2` (approved), `flutter_secure_storage: ^9.2.2` (approved, matches the existing `zip_broadcast` pin), `app_links: ^7.0.0` (direct dependency, revised 2026-09-28 — see `sr-01-oauth-approach.md` §3/§9; already present transitively via `supabase_flutter`, declared directly because `SupabaseAuthService` uses its API itself).
- [x] `zip_broadcast`: add `supabase_flutter: ^2.17.2` (approved).
- [x] `zip_captions`: add `supabase_flutter: ^2.17.2` (approved).
- [x] Also added `packages/zip_core/lib/src/constants/supabase_config.dart` (`supabaseUrl`/`supabaseAnonKey`, `String.fromEnvironment`-overridable, defaulting to the local Supabase stack's values from `packages/zip_supabase/.env.example`) — a small structural gap-fill this plan didn't call out as its own step, needed so Steps 18/19's `Supabase.initialize` calls have something to pass. Used `publishableKey:` (not the deprecated `anonKey:`) per `supabase_flutter` 2.17.2's own deprecation notice, discovered while writing Step 18.
- Depends on: none (can run first, before Step 1, in practice — listed last only for narrative ordering).

## Step 22: Documentation
**File**: `aidlc-docs/construction/broadcaster-auth/code/unit2-summary.md` (new, markdown only, per Code Location Rules)
- [x] Summarize generated files (created vs. modified), test coverage achieved, and any deviations from the plan discovered during generation.
- Depends on: all prior steps.

---

## Story Traceability

| Story | Covered by |
|---|---|
| S-15 (all ACs) | Steps 1, 3, 4, 5, 9, 13, 15, 16, 18, 19, 20 |
| SR-01 (already approved, implemented here) | Steps 5, 9, 20, 21 |

No deployment artifacts beyond the pubspec/platform-manifest changes already covered in Steps 20–21 — this unit has no server-side or infrastructure component of its own.
