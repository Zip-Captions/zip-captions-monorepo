# NFR Design Patterns — Broadcaster Auth (Unit 2)

## Resilience Patterns

### Abandoned sign-in resolution (Q1: dual mechanism)

Two independent signals, either of which resolves a stuck `SigningIn(providerId)` to
`AuthFailed(providerId, cancelled)`:

1. **Foreground-resume heuristic**: `AuthNotifier` (or a small internal helper it owns)
   observes app lifecycle resume events (`WidgetsBindingObserver.didChangeAppLifecycleState`
   → `AppLifecycleState.resumed`, which Flutter reports consistently across desktop and web).
   On resume while still `SigningIn`, it does **not** fail immediately — it waits a short
   grace window (2 seconds) for a pending OAuth callback that may be arriving
   concurrently with the resume event (the OS can resume the window and deliver the deep
   link in either order), then fails only if still `SigningIn` after the grace window.
2. **Hard timeout backstop**: a 3-minute timer starts when `signIn(providerId)` is called.
   If the attempt is still unresolved when it fires, it fails unconditionally — this
   catches cases the resume heuristic can't (e.g. the OS never reports a resume event, or
   the user leaves the browser open indefinitely without returning to the app at all).

Both mechanisms are cancelled the instant the attempt resolves through any other path
(success, or an explicit `AuthFailure` from the SDK) — there is no race where a genuine
late-arriving success gets clobbered by a stale timeout, because whichever resolves first
cancels the other. This is the same reasoning as Rule 1 (single in-flight attempt): exactly
one outcome per `signIn()` call, from exactly one of three sources (SDK callback, resume
heuristic, hard timeout).

**Testability**: both mechanisms are driven by fake time (`package:fake_async`, already a
`zip_core` dev dependency) in tests — no real `Timer`/`sleep` in the test suite, and no
flakiness from real wall-clock timing.

## Scalability Patterns — N/A

Restated from NFR Requirements: single-user, single-device, one-in-flight-attempt client
flow (Rule 1). No scaling pattern applies; there is no request volume or fan-out this unit
owns.

## Performance Patterns

`AuthNotifier.signIn()` sets `SigningIn(providerId)` synchronously before awaiting the SDK
call, so the UI's busy treatment (Proto-10 addition) never waits on I/O to appear — the tap
response is bounded by the UI frame budget, not by network or browser-launch latency, which
is the only performance property this unit makes a claim about (NFR Requirements Q4).

## Security Patterns

### Storage Strategy pattern (Q2: lives in `zip_core`)

`LocalStorage` (from `supabase_flutter`) is the extension point; `SecureDesktopLocalStorage`
is a `zip_core`-owned implementation wrapping `flutter_secure_storage`, selected at
`Supabase.initialize` time based on platform (`!kIsWeb`). Placing it in `zip_core` alongside
`AuthService`/`SupabaseAuthService` means Phase 3's Zip Captions auth (FR-1.1's reuse
target) gets the same secure-storage behavior automatically, with no new decision required
when that unit is built — the Strategy is already there to select.

### No-credentials-in-logs enforcement point

Business Rule 4/9 (never log tokens, auth codes, callback URLs, or raw SDK exception
messages) is enforced at exactly one seam: the `catch` block inside `SupabaseAuthService`
where SDK exceptions are mapped to `AuthFailure` values (SR-01 §7). This is a single
chokepoint by design — every path from "the SDK threw something" to "the app has an
`AuthFailure`" passes through it, so there is one place to audit at Code Generation, not a
scattered set of catch blocks each needing separate review.

### Configuration-only provider addition (Strategy over a static list)

`AuthProviderConfig`'s static list (SR-01 §8) is itself a Strategy-selection mechanism:
`SupabaseAuthService.signIn(providerId)` behaves identically regardless of which entry is
selected, so "adding a provider" is adding a Strategy instance to the list, never a new code
path in the service.
