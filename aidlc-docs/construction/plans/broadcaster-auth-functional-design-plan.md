# Functional Design Plan: Broadcaster Auth (Unit 2)

**Unit**: broadcaster-auth
**Stories**: S-15 (Broadcaster Authentication), gated by SR-01 (OAuth Flow Approach Review)
**Packages**: zip_core, zip_broadcast (plus `main.dart` Supabase init in both apps)
**Branch**: `feature/broadcaster-auth` (off `develop`)

This stage has two outputs: the standard Functional Design artifacts (business logic,
rules, domain entities), and the **SR-01 approach document** itself — this unit's
Functional Design *is* the security-critical approach review required by AGENTS.md
before any OAuth code is written. SR-01 requires explicit human approval separate from
(but presented alongside) the Functional Design approval.

## What's Already Decided (from phase2-application-design.md / phase2-component-methods.md)

Not open for reinterpretation here — Functional Design elaborates these, it doesn't
re-decide them:
- Interfaces: `AuthService` (`authStateChanges`, `currentUserId`, `signIn(providerId)`, `signOut()`), `SupabaseAuthService` (GoTrue impl), `AuthProviderConfig` (id + display label list), `AuthState` (`signedOut | signingIn | signedIn(userId) | failed(AuthFailure)`), `AuthNotifier` (keepAlive, exposes `AuthState`, calls `AuthService` explicitly).
- `AuthFailure` enum: `cancelled, denied, network, providerError, sessionExpired`.
- `supabaseClientProvider`: keepAlive, throws unless overridden — same pattern as `packages/zip_core/lib/src/providers/audio_device_service_provider.dart`, overridden in each app's `main()` after `Supabase.initialize` (see `packages/zip_broadcast/lib/main.dart`'s existing `sharedPreferencesProvider` override for the pattern to follow).
- Sign-in is required only for remote broadcasting; local captioning/transcripts/OBS/browser-source/external-display stay signed-out-capable (FR-1.4).
- Sign-in UI ships only in Zip Broadcast (Proto-10, already approved — `zip-broadcast-sign-in.html`).
- `supabase_flutter` and `flutter_secure_storage` are both pre-approved dependencies (`docs/04-technical-specification.md` Section 6) — no new-dependency approval needed for either.

## Planned Functional Design Artifacts

- [x] `aidlc-docs/construction/broadcaster-auth/functional-design/sr-01-oauth-approach.md` — the SR-01 approach document (providers, per-platform flow, redirect handling, token storage, refresh, sign-out, failure handling, config-only provider addition)
- [x] `aidlc-docs/construction/broadcaster-auth/functional-design/business-logic-model.md` — sign-in/sign-out/restore/prompted-sign-in orchestration (`AuthNotifier` ↔ `AuthService` ↔ `SupabaseAuthService`), mapped to S-15's acceptance criteria
- [x] `aidlc-docs/construction/broadcaster-auth/functional-design/business-rules.md` — failure-state mapping, retry rules, "never logged" enforcement points, config-only provider addition rule
- [x] `aidlc-docs/construction/broadcaster-auth/functional-design/domain-entities.md` — `AuthState`, `AuthFailure`, `AuthProviderConfig`/`AuthProviderOption` shapes and invariants
- [x] `aidlc-docs/construction/broadcaster-auth/functional-design/frontend-components.md` — sign-in view states against Proto-10 (signed-out / signing-in / signed-in / auth-failure), wired to `AuthNotifier`
- [x] `aidlc-docs/construction/broadcaster-auth/functional-design/handoff-summary.md`

## Open Questions

Researched supabase_flutter's actual OAuth API and storage behavior (WebSearch, since
supabase_flutter isn't in docs-mcp's index) before drafting the options below — these
aren't blind guesses, but SR-01 still requires your explicit sign-off since this is
security-critical per AGENTS.md. Answer each with a letter (or write in an alternative).

### Q1: Which OAuth provider(s) for Phase 2?
FR-1.2 allows one or two. `packages/zip_supabase/supabase/config.toml` already has
disabled stubs for `apple`, `azure`, `google`, `github` — none chosen yet.

- A. Google only **(recommended — broadest reach, simplest redirect config, defer the rest to Phase 3 per FR-1.6)**
- B. Google + GitHub
- C. Google + Apple
- D. Other (write in)

[Answer]: A

### Q2: Desktop redirect handling mechanism?
supabase_flutter v2 dropped the webview dependency — the documented desktop/mobile
pattern is an external-browser OAuth flow that redirects back via a custom URL scheme,
not a loopback HTTP server. This needs a deep-link-capture package; none is currently
in `zip_broadcast`'s dependencies (`desktop_multi_window` is unrelated).

- A. `app_links` package + custom URL scheme `io.zipcaptions.broadcast://login-callback`, registered per platform (Info.plist / platform manifest) **(recommended — `app_links` is actively maintained; `uni_links` is not)**
- B. Same custom-scheme approach but with `uni_links` instead
- C. Local loopback HTTP server (no new URL-scheme registration, but opens a local port during sign-in)
- D. Other (write in)

New dependency (A or B) needs your approval as part of SR-01 sign-off (Section 6
process — justification will be documented in the approach doc and the eventual PR).

[Answer]: A

### Q3: Web redirect handling?
- A. Standard `signInWithOAuth` with `redirectTo` unset (defaults to current origin); SDK detects the session from the URL fragment on return **(recommended — SDK's documented default, no new dependency)**
- B. Other (write in)

[Answer]: A

### Q4: Token storage — override the SDK default?
Default `supabase_flutter` storage is plaintext `shared_preferences`. FR-1.3 says
tokens are "stored per the SDK's secure-storage mechanism; never logged" — read as
requiring secure storage, not accepting the plaintext default.

- A. Custom `LocalStorage` backed by `flutter_secure_storage` (already approved) on macOS/Windows/Linux desktop; keep the SDK's default storage on web (browser-standard for GoTrue web clients) **(recommended)**
- B. `flutter_secure_storage` on desktop **and** web
- C. Keep the SDK default (plaintext `shared_preferences`) everywhere
- D. Other (write in)

[Answer]: A

### Q5: Provider-config source for "configuration only" (FR-1.2)?
- A. Static Dart list (`AuthProviderConfig` populated from a small config file, not inlined in `AuthNotifier`/`AuthService` logic) — sufficient to satisfy "no code changes to add a provider" for Phase 2; real dynamic/remote config deferred to Phase 3 **(recommended)**
- B. Dynamic/remote config (fetched from Supabase) already in Phase 2 scope
- C. Other (write in)

[Answer]: A

### Q6: Catch-all failure mapping?
Proto-10 (already approved) only has one generic failure card with a retry button, so
the UI-facing state doesn't need per-cause granularity. The real risk is losing
debugging insight if the underlying exception is discarded once folded into
`providerError` — a real bug (null redirect, JSON parse failure, deep-link scheme
mismatch) would then look identical to the provider legitimately rejecting sign-in.

- A. Any OAuth-flow exception that isn't clearly cancelled/denied/network/expired maps to `AuthFailure.providerError` for `AuthState`/UI purposes, **and** `AuthService`/`AuthNotifier` logs the underlying exception's type and stack trace (never its message, in case a provider error message ever embeds something sensitive) at the point it's folded in — simple two-state UI model, full triage visibility in logs/crash reporting, no new `AuthState` case **(recommended)**
- B. Add a distinct `AuthFailure.unknown` state instead of folding into `providerError`
- C. Other (write in)

[Answer]: A

### Q7: Anything from Jordan's persona or prior sign-in feedback I should weight?
Proto-10 (`zip-broadcast-sign-in.html`) is already approved and its states (signed-out,
signed-in, auth-failure) map directly onto `AuthState`.

- A. No — carry Proto-10's states and copy through as-is **(recommended — nothing on record suggests otherwise)**
- B. Yes — there's UX intent behind Proto-10 not fully captured in its states/copy (describe below)

[Answer]: A
