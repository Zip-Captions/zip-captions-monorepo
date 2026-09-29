# NFR Design Plan: Broadcaster Auth (Unit 2)

**Unit**: broadcaster-auth | **Prior stage**: NFR Requirements, approved 2026-09-28

## Planned Steps

- [x] Resilience Patterns — abandoned-flow handling (Q1)
- [x] Scalability Patterns — N/A, justified below
- [x] Performance Patterns — documented, no open question
- [x] Security Patterns — storage-implementation placement (Q2)
- [x] Logical Components — redirect-listener placement (Q3), full component list
- [x] Generate `aidlc-docs/construction/broadcaster-auth/nfr-design/nfr-design-patterns.md`
- [x] Generate `aidlc-docs/construction/broadcaster-auth/nfr-design/logical-components.md`
- [x] Generate `aidlc-docs/construction/broadcaster-auth/nfr-design/handoff-summary.md`

## Resilience Patterns

**Gap found while designing this**: SR-01's failure table covers explicit outcomes
(`access_denied`, network errors, provider errors) but not silent abandonment — the user
closes the external browser tab without Google ever sending back an `error` param at all.
Today's design would leave `AuthNotifier` in `SigningIn(providerId)` indefinitely.

### Q1: How should an abandoned (no-callback) sign-in attempt resolve?

- A. Both: treat an app-foreground-resume with no completed callback as likely abandonment (best-effort signal on desktop, where the OS notifies on window focus) **and** a hard 3-minute timeout as a backstop that always fires regardless of foreground signal reliability — either maps to `AuthFailed(providerId, cancelled)` **(recommended — foreground-resume alone is a weak/unreliable signal across three desktop OSes plus web, and a timeout alone is slow if the user visibly comes back to the app; together they cover both the fast common case and the guaranteed worst case)**
- B. Hard timeout only (no foreground-resume heuristic) — simpler, one mechanism
- C. Foreground-resume heuristic only — no timeout
- D. Other (write in)

[Answer]: A

## Scalability Patterns — N/A

This unit is a single-user, single-device, one-in-flight-attempt client flow (Rule 1). There is no request volume, no fan-out, and no shared server-side component this unit owns — GoTrue's own scaling is Supabase's concern. No scaling pattern applies.

## Performance Patterns

No numeric target exists (NFR Requirements Q4). The one performance-relevant pattern:
`AuthNotifier.signIn()` updates state to `SigningIn(providerId)` synchronously, before
awaiting the SDK call — so the UI's spinner treatment never waits on I/O to appear. This is
restated here as a design constraint, not re-decided.

## Security Patterns

### Q2: Where should the custom secure `LocalStorage` implementation live?

FR-1.1 requires `AuthService` itself to live in `zip_core` so Zip Captions can reuse it in
Phase 3 without changes. The desktop secure-storage override is arguably part of that same
reusable auth abstraction, not `zip_broadcast`-specific.

- A. `zip_core` (e.g. `zip_core/lib/src/services/auth/secure_desktop_local_storage.dart`), alongside `AuthService`/`SupabaseAuthService`, so Phase 3's Zip Captions auth gets secure storage for free **(recommended — consistent with FR-1.1's reuse intent; the storage mechanism has nothing broadcast-specific about it)**
- B. `zip_broadcast`, since it's the only app using auth in Phase 2 — move it to `zip_core` only when Phase 3 actually needs it (YAGNI)
- C. Other (write in)

[Answer]: A

## Logical Components

### Q3: Where should the `app_links` redirect-capture wiring live?

- A. Inside `SupabaseAuthService` itself, platform-gated (`!kIsWeb`) — the deep-link subscription is an implementation detail of *how* this one service completes the OAuth flow on desktop, not a separate concern **(recommended — `AuthService`'s public interface stays platform-agnostic either way; a separate component would only be justified if something else in the app also needed deep links, and nothing does)**
- B. A separate `OAuthRedirectListener` interface + platform implementation, injected into `SupabaseAuthService` — more isolated for testing, but adds a layer for a mechanism used exactly once
- C. Other (write in)

[Answer]: A

### Component List (for the artifact, not a question)

- `AuthService` (interface, `zip_core`), `SupabaseAuthService` (impl, `zip_core`) — GoTrue adapter, owns the `app_links` subscription per Q3.
- `SecureDesktopLocalStorage` (Q2's placement) — `LocalStorage` implementation wrapping `flutter_secure_storage`, used only on macOS/Windows/Linux.
- `AuthProviderConfig` / `AuthProviderOption` — static configuration component (`zip_broadcast`, per SR-01 §8).
- `AuthNotifier` (`zip_core`, keepAlive Riverpod notifier) — orchestration/state component (State pattern via the sealed `AuthState`).
- `supabaseClientProvider` (`zip_core`) — throws-unless-overridden provider, matching `audio_device_service_provider.dart`'s existing pattern.
- Fake `AuthService` + `AuthCommand` generator (test-only, `zip_core/test/helpers/`) — supports the stateful PBT (PBT-06) and the abandonment-timeout resilience test (Q1).
