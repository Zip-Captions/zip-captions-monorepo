# Logical Components — Broadcaster Auth (Unit 2)

| Component | Package | Kind | Responsibility |
|---|---|---|---|
| `AuthService` | `zip_core` | interface | Contract: `authStateChanges`, `currentUserId`, `signIn(providerId)`, `signOut()`. No tokens cross it. |
| `SupabaseAuthService` | `zip_core` | impl (Adapter) | GoTrue implementation. **Corrected 2026-09-28**: does *not* own an `app_links` subscription — `supabase_flutter` already listens for the OAuth callback internally on every non-web platform and calls `getSessionFromUrl` itself; this class only needs to call `signInWithOAuth` with the right `redirectTo` and observe `onAuthStateChange`. Q3's original question (where should the redirect-capture wiring live) is moot — there is no such wiring for this unit to place. Owns the resilience timers (Q1) and the single no-credentials-logging chokepoint (Rule 4/9). |
| `SecureDesktopLocalStorage` | `zip_core` | impl (Strategy) | `LocalStorage` wrapping `flutter_secure_storage`. **Q2: lives in `zip_core`**, selected at `Supabase.initialize` based on `!kIsWeb`, so Phase 3's Zip Captions auth reuses it without a new decision. |
| `AuthProviderConfig` / `AuthProviderOption` | `zip_broadcast` | static config | The enabled-provider list (SR-01 §8). App-specific because Phase 2 only wires sign-in into Zip Broadcast. |
| `AuthState` / `AuthFailure` | `zip_core` | sealed model / enum | State pattern — `AuthNotifier`'s entire external contract is this type. Shapes fixed at Functional Design (`domain-entities.md`). |
| `AuthNotifier` | `zip_core` | notifier (keepAlive, Observer) | Orchestrates `AuthService`, exposes `AuthState`, owns Rule 1's single-in-flight-attempt guard. |
| `supabaseClientProvider` | `zip_core` | provider (keepAlive) | Throws unless overridden — matches `audio_device_service_provider.dart`'s existing pattern exactly; overridden in each app's `main()` post-`Supabase.initialize`. |
| Sign-in view (`AccountSection`) | `zip_broadcast` | widget | Renders `AuthState` per `frontend-components.md`'s state table; the only place `AuthNotifier.signOut()` is called from *in this unit* (Unit 6's `ZbAppShell` guard, Rule 9, supersedes this once it exists). |
| Fake `AuthService` | `zip_core` (test) | test double | Driven, stream-based fake for the stateful PBT (PBT-06) and the Q1 resilience tests — a `mocktail` mock can't hold state across a command sequence. |
| `AuthCommand` generator | `zip_core` (test) | test helper | New addition to `test/helpers/generators.dart`; realistic-weighted sequences per PBT-07. |
| `fake_async` usage | `zip_core` (test) | test infra | Drives Q1's timers/lifecycle-resume heuristic deterministically — already a `zip_core` dev dependency, no new one needed. |

## Integration Points

- `SupabaseAuthService` → `supabaseClientProvider` (reads the injected `SupabaseClient`). No direct `app_links` dependency — that's internal to `supabase_flutter` (corrected 2026-09-28).
- `AuthNotifier` → `AuthService.authStateChanges` (subscribed once, kept alive) and → `AuthProviderConfig` (read-only, to know valid `providerId`s for Rule 5's lookup).
- Sign-in view → `AuthNotifier` (Riverpod `watch` for state, explicit `read().signIn/signOut` calls, per the project's Riverpod convention) and → `AuthProviderConfig` (to render the button list).
- **Not yet wired** (explicitly out of this unit): `ZbAppShell` ↔ `BroadcastSessionState` sign-out guard (Rule 9) — Unit 6.

## Dependency Direction

```
zip_broadcast (AccountSection, AuthProviderConfig)
        │  reads/calls
        ▼
zip_core (AuthNotifier ─▶ AuthService ─▶ SupabaseAuthService ─▶ SecureDesktopLocalStorage,
                                                              ─▶ supabaseClientProvider)
        (app_links is internal to supabase_flutter — no direct edge from this unit's code)
```

No arrow points from `zip_core` back into `zip_broadcast` — this is what keeps `AuthService`
reusable by Zip Captions in Phase 3 (FR-1.1) without any change to `zip_core`.
