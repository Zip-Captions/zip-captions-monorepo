# Business Logic Model — Broadcaster Auth

Orchestration is `AuthNotifier` (UI-facing, keepAlive) calling `AuthService` (interface)
explicitly — no reactive watching of SDK streams from the UI layer, per the project's
Riverpod convention. `SupabaseAuthService` is the only component that talks to
`supabaseClientProvider`.

## F-BA-1: Sign-In (S-15 AC1)

1. UI calls `AuthNotifier.signIn(providerId)`.
2. `AuthNotifier` sets state to `SigningIn(providerId)`.
3. `AuthNotifier` calls `AuthService.signIn(providerId)`.
4. `SupabaseAuthService` resolves `providerId` against `AuthProviderConfig`, then calls
   the SDK's `signInWithOAuth` with the platform-appropriate `redirectTo` (see
   `sr-01-oauth-approach.md` Section 2–3).
5. The external browser flow completes (or fails) out-of-process; the SDK's
   `onAuthStateChange` stream — which `AuthService.authStateChanges` wraps — emits the
   outcome.
6. `AuthNotifier`, subscribed to `authStateChanges`, maps a successful sign-in to
   `SignedIn(userId)`; a failure maps through the `AuthFailure` table (Section 7 of
   the SR-01 doc) to `AuthFailed(providerId, reason)` — `AuthNotifier` retains the
   `providerId` it was already holding from `SigningIn`, so no separate bookkeeping is
   needed to attach it to the failure.
7. If sign-in was prompted by a go-live attempt (F-BA-4), the UI returns to broadcast
   setup with its configuration intact — `AuthNotifier` itself does not perform navigation;
   it only exposes the resulting `AuthState`, and the calling screen reacts to
   `SignedIn` to pop back.

## F-BA-2: Session Restore on App Start (S-15 AC2)

1. At `Supabase.initialize`, the SDK loads any persisted session from the platform's
   `LocalStorage` implementation (secure storage on desktop, SDK default on web — SR-01
   Section 4) and, if present and not expired, restores it without any network round trip
   blocking startup.
2. `AuthNotifier.build()` reads `AuthService.currentUserId` synchronously at construction:
   non-null resolves the initial state to `SignedIn(userId)` directly — there is no
   intermediate `SigningIn` state for a restored session, since no OAuth flow runs.
3. If the SDK's background refresh (Section 5 of SR-01) succeeds before expiry, the state
   remains `SignedIn` transparently — `AuthNotifier` does not need to react to a refresh
   distinctly from steady-state sign-in.

## F-BA-3: Sign-Out (S-15 AC3)

1. UI calls `AuthNotifier.signOut()`.
2. `AuthNotifier` calls `AuthService.signOut()`, then sets state to `SignedOut`
   immediately on local completion (SR-01 Section 6 — does not block on the server-side
   revoke round trip).
3. `AuthNotifier.signOut()` itself is unconditional and has no visibility into whether a
   broadcast is live — it cannot be otherwise, since `AuthService`/`AuthNotifier` live in
   `zip_core` and must stay reusable by Zip Captions (FR-1.1), which has no broadcasting
   concept at all. Local captioning, transcripts, and every Phase 1 output target stay
   unaffected by sign-out regardless (F-BA-5) — this guard is scoped to broadcasting only,
   not to captioning activity in general. **The decision to block sign-out while
   `BroadcastSessionState` is non-idle (live or mid-`goLive()` transition) is a Unit 6
   responsibility**, not this unit's: `ZbAppShell` (Unit 6, per `phase2-unit-of-work.md`)
   is where the sign-out affordance and `BroadcastSessionNotifier` are composed together,
   and it must be the *only* call path to `AuthNotifier.signOut()` exposed in Zip
   Broadcast — e.g. a `ZbAppShell`-level guard that refuses to invoke `signOut()` (not
   merely disables a button) while `BroadcastSessionState` is anything other than idle.
   This unit's contribution is limited to keeping `AuthNotifier.signOut()` itself simple
   and composable enough for that guard to wrap. See `business-rules.md` Rule 9 and the
   Backlog entry added to `aidlc-state.md` for Unit 6.

## F-BA-4: Prompted Sign-In from Go-Live (S-15 AC4)

1. A signed-out user starts a remote broadcast; `BroadcastSessionNotifier.goLive()`
   (Unit 5) detects `AuthState != SignedIn` and does not call into this unit further — it
   surfaces its own `failed(signedOut)` state, per `phase2-services.md` F2 step 1.
2. The UI (owned outside this unit) shows the sign-in prompt and, on completion, invokes
   F-BA-1 above. This unit's only contract with Unit 5 is `AuthState` itself; there is no
   direct call from `BroadcastSessionNotifier` into `AuthNotifier` beyond reading state.

## F-BA-5: Signed-Out Capability Preserved (S-15 AC5)

No flow in this unit touches local captioning, transcripts, OBS output, browser-source
output, or external-display output — none of those components read `AuthState` or depend
on `AuthService` in any way. This is verified by absence, not by a code path to design:
Functional Design confirms no dependency edge is introduced from Phase 1 output targets to
this unit's components.

## F-BA-6: OAuth Flow Cancelled, Denied, or Failed (S-15 AC6)

Covered by F-BA-1 step 6's failure mapping. The UI (per Proto-10, Q7 = carry through
as-is) shows one generic, non-technical failure message with a retry button regardless of
which `AuthFailure` value it is — retry re-invokes F-BA-1 from `SignedOut`.

## F-BA-7: Refresh Token Revoked or Expired (S-15 AC7)

Passive path — no user action initiates this. When the SDK's background refresh fails with
an invalid/expired refresh token, `AuthService.authStateChanges` emits a signed-out
transition; `AuthNotifier` maps this directly to `SignedOut` (not `AuthFailed`), matching
"signed out gracefully... prompted to sign in again only when needed" (SR-01 Section 7,
`sessionExpired` row).

## F-BA-8: No Credentials in Logs (S-15 AC8)

A cross-cutting constraint, not a flow: every log statement in `SupabaseAuthService` and
`AuthNotifier` is reviewed at Code Generation against the rule in `business-rules.md`
Rule 4 (exception type/stack trace only, never message or token material).

## F-BA-9: Config-Only Provider Addition (S-15 AC9)

Covered structurally, not as a runtime flow — see SR-01 Section 8 and `domain-entities.md`.
