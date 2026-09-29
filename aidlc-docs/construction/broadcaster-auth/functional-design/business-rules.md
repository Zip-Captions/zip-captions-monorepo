# Business Rules — Broadcaster Auth

**Rule 1 — Single in-flight sign-in.**
`AuthNotifier.signIn(providerId)` is a no-op (or ignored/debounced at the UI layer) if the
current state is already `SigningIn`. The external-browser flow cannot be meaningfully
started twice concurrently, and Proto-10 has no UI affordance for it either.

**Rule 2 — Sign-out is unconditional and local-first.**
`AuthNotifier.signOut()` always transitions to `SignedOut` once the local session clear
succeeds, regardless of whether the server-side revoke call succeeds, times out, or the
device is offline. A user asking to sign out must not be left in a signed-in-looking state
by a network failure.

**Rule 3 — Passive session loss never produces `AuthFailed`.**
Any transition to signed-out that was not the direct result of a call to
`AuthNotifier.signOut()` or a failed `AuthNotifier.signIn()` (i.e., a background refresh
failure) resolves to `SignedOut`, not `AuthFailed(sessionExpired)`. `AuthFailed` is
reserved for outcomes of an active, user-initiated `signIn()` call. See F-BA-7.

**Rule 4 — No credential material in logs, ever.**
No log statement, in any state, may include: an access token, a refresh token, an
authorization code, a full OAuth callback URL (which carries tokens in its fragment on
desktop), or a raw exception message from the auth SDK (which could echo back query
parameters). Only allowed: `AuthFailure` enum values, exception **type** names, stack
traces, and non-identifying metadata (e.g. which platform, whether desktop or web flow).
This is enforced at Code Generation review, not just documented here (NFR-3.8).

**Rule 5 — Provider identity never leaks past the service boundary.**
`AuthNotifier` and any UI component holds only `providerId: String` values sourced from
`AuthProviderConfig`. Nothing above `SupabaseAuthService` references
`package:supabase_flutter`'s `OAuthProvider` enum directly — this is what makes "add a
provider = config change" true in practice, not just in intent (FR-1.2, S-15 AC9).

**Rule 6 — Token storage is never the default on desktop.**
`SupabaseAuthService` must not be constructed without an explicit secure `LocalStorage`
override on macOS, Windows, or Linux builds. Falling through to the SDK's plaintext
default on desktop is treated as a defect, not a degraded-but-acceptable fallback (SR-01
Section 4).

**Rule 7 — `AuthProviderConfig.providers` is never empty at runtime.**
An empty provider list is a build/configuration defect to catch before release, not a
state the sign-in view needs to render gracefully (e.g. no "no providers available"
empty state is in scope for Phase 2).

**Rule 8 — Idempotent sign-out.**
Calling `signOut()` while already `SignedOut` is a safe no-op — it must not throw or
attempt a redundant server call that could surface a spurious network failure to the UI.

**Rule 9 — Sign-out must be unreachable, not just discouraged, while the broadcast session is non-idle.**
`AuthNotifier.signOut()` in `zip_core` stays unconditional by design (Rule 3's reasoning:
`zip_core` has no broadcast concept, and must not gain one just to serve this rule — FR-1.1
reuse for Zip Captions). Local captioning, transcripts, OBS output, browser-source output,
and external-display output are deliberately decoupled from `AuthState` (F-BA-5, FR-1.4)
and are explicitly **not** in scope for this guard — signing out mid-local-caption is safe
and must stay unaffected.

The "no way to sign out while broadcasting" guarantee applies specifically to
`BroadcastSessionState` being anything other than idle — this includes the mid-`goLive()`
transition window (`phase2-services.md` F2's 9-step sequence), not only the terminal
`live` state, to close the race where sign-out lands between "broadcast identity/signaling
established" and "state formally becomes live." It is enforced one layer up, in Zip
Broadcast: the sign-out affordance must be composed behind a guard that checks
`BroadcastSessionState` (Unit 6) and refuses to call `AuthNotifier.signOut()` at all while
non-idle — not merely disabling the button, since a disabled-button-only guard can be
bypassed by any other call path. `ZbAppShell` (Unit 6) must be the sole place in
`zip_broadcast` that calls `AuthNotifier.signOut()`, so this guard has exactly one gate to
sit behind. This unit does not implement the guard (it doesn't have `BroadcastSessionState`
to check against); it is recorded as a mandatory carry-forward requirement for Unit 6
Functional Design — see the Backlog entry in `aidlc-docs/aidlc-state.md`.
