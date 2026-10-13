# Business Rules — Zip Broadcast Broadcast UI (Unit 6)

**Rule 1 — Single in-flight `goLive()`; accepted only from session-empty states.**
`BroadcastSessionNotifier.goLive()` is a no-op unless the current state is
`OfflineState` or `BroadcastFailedState` (both have zero session resources — the latter
because Rule 2's unwind completed). On acceptance it sets `StartingState`
**synchronously, before the first await**, so the entire mid-`goLive()` window is
observable by the Rule 9 guard and by the UI. A concurrent or later `goLive()` during
`StartingState`/`LiveState`/`EndingState` is ignored (same pattern as Unit 2's Rule 1
for sign-in: the external flow cannot be meaningfully started twice concurrently).

**Rule 2 — `goLive()` failures unwind in reverse order and map to exactly one
`BroadcastFailure` variant each.**

| F2 step that fails | `BroadcastFailure` | Unwind (reverse order of completed steps) |
|---|---|---|
| 1 (sign-in check) | `signedOut` | — (no resources) |
| 2 (`getOrCreateMine`) | `identityUnavailable` | — |
| 3 (`iceServersFor`) | `relayUnavailable` | — (values only) |
| 5 (`transport.start`) | `unknown` | — (step 4 carries no action, see F-6.2) |
| 6 (target create/register/prime) | `unknown` | — (local operation; failure = programming error) |
| 7 (`publishLive`) | `signalingUnavailable` | stop transport |
| 8 (auto-start captioning) | *not a goLive failure* — see Rule 3 | — |

Unwind steps, newest first: close the `StatusChannel` (if opened) →
`registry.remove(target)` (disposes it) → `transport.stop()`. After any unwind, state
is `BroadcastFailedState(reason)` and **no session resource remains** (this is what
makes `BroadcastFailedState` a legal retry start point and a sign-allowed state under
Rule 9). Local captioning is unaffected on every failure path: nothing before step 8
touches captioning, and step 8 cannot fail the broadcast (Rule 3). The UI shows the
specific reason per variant and offers retry (S-17 AC11) — retry is simply a new
`goLive()` from `BroadcastFailedState` (Rule 1 permits it).

**Rule 3 — Auto-start captioning is best-effort and never fails `goLive()`.**
The coupled start (F2 step 8) runs only when `autoStartCaptioning` is on **and**
`captioningStarter.currentActivity == CaptionActivity.inactive` — an already-running
captioning session is never restarted or interrupted. `start()` failure modes (no
audio inputs configured; all engines fail) leave captioning idle with the
captions-inactive banner visible; the broadcast itself proceeds to `LiveState`. This
is FR-6.7's independent lifecycles made operational: the coupling is one-directional
(broadcast may start captioning; captioning can never start, stop, pause, or end the
broadcast).

**Rule 4 — Caption activity has exactly one source of truth while live, and the
`RemoteBroadcastTarget` is primed to match it at registration.**
`LiveBroadcast.captionActivity` is seeded from `captioningStarter.currentActivity` at
F2 step 6 (the app's *actual* captioning state — not the target's shipped `inactive`
default), and from then on is updated **only** by the notifier's owned
`activityChanges` subscription (F3 step 3 — "a stream subscription it owns, not a
provider watcher"). The target is primed with the same value immediately after
registration (Q4's additive `primeActivity`), so the dashboard banner
(F-6.4 matrix) and the target's join-snapshot behavior (Unit 5 Rule 8) can never
disagree about the current activity. The banner is visible ⟺ state is `LiveState` and
`captionActivity != CaptionActivity.active` (FR-6.7) — `paused` counts as not-active.

**Rule 5 — `endBroadcast()` is idempotent, only valid from `LiveState`, and every
terminal path disposes exactly once.**
`endBroadcast()` is a no-op from `EndingState` (idempotent repeat — PBT-04) and from
`OfflineState`/`StartingState`/`BroadcastFailedState` (no live session to end; the UI
offers no end affordance in those states, but a programmatic call must still be a
safe no-op, never a throw). From `LiveState` it runs F-6.6 exactly once:
`EndingState` → wire `Ended` (+ signaling `BroadcastEnded` per Q5) → `transport.stop()`
→ `registry.remove(target)` → `publishOffline` → channel close → subscriptions
cancelled → `OfflineState`. Each owned per-session resource (status channel, admission,
transport, target, the two subscriptions) is disposed exactly once across any
sequence of `goLive`/`endBroadcast` calls — this is what makes repeated
go-live/end cycles leak-free (NFR-1.4; S-17's "no growth from viewer churn" AC at the
notifier level; the transport-level half is Unit 5's).

**Rule 6 — The status channel is held open for the broadcast's whole lifetime;
presence expiry is the broadcaster-disappearance mechanism, not an app-level
heartbeat.**
The `StatusChannel` opened in F2 step 7 stays open (its Realtime subscription is the
broadcaster's presence) until `endBroadcast()`'s `publishOffline` + `close`, or a
`goLive()` failure's unwind closes it. No heartbeat timer is added — a crash or
network loss kills the subscription, and Realtime's platform presence expiry
(`defaultBroadcastLimits.presenceTimeout`, interim 60s — Unit 3 Rule 6) emits
`offline` to viewers, clearing the stale live status (FR-6.6, NFR-4.3). This unit's
obligation is the positive one (don't close it early); the failure path requires no
code (F-6.8).

**Rule 7 — Session names are validated in one place and enforced at the boundary.**
`BroadcastSettings.validateSessionName` (static, on the model) is the single
validator, with exactly three error categories and specific per-category messages:
**empty** (the trimmed name is empty), **too long** (exceeds the max length fixed at
Q7, recommended 100 code units), **control characters** (any of U+0000–U+001F or
U+007F anywhere in the name). It is called (a) live, on edit, by the setup screen's
inline validation, and (b) by `goLive()`'s pre-flight (Rule 1 step 0) — so an invalid
name can never reach the state machine or be published via `publishLive` through any
call path, satisfying S-17's "validation rejects it with a specific message" AC. The
validator returns an error *key*, not a message — UI strings stay in the ARB files
(English-only rule).

**Rule 8 — Caption attribution is deferred, explicitly, for Phase 2 (resolves the
2026-09-25 Proto-12-review Backlog item).**
The speaker label is **not** prepended as text to caption content in Phase 2, for the
broadcaster or for viewers: the wire format is version 1 (Unit 5, shipped — a
`Caption` message carries exactly the ADR-005 `SttResult` fields, an unchanged stable
contract), and the label is not an `SttResult` field. The alternatives are all worse
now: mutating `SttResult.text` before publishing would corrupt the local transcript
(the same bus event feeds `TranscriptWriterTarget`); adding a label field is a wire
version bump, which requires the viewer side (Unit 7) to ship the decode together —
a coordinated release this unit is not. What ships instead: the Phase 1 on-screen
attribution stands as designed (per-input `AudioInputConfig.label` + visual
style/color applied by the local renderer, S-06) — local viewers and the broadcaster's
own display keep their speaker distinction; remote viewers see unattributed text in
Phase 2. **Revisit in the unit that bumps `CaptionWireCodec`'s version** (together
with Unit 7's viewer rendering), where the wire field, its rendering, and any
broadcaster-settable label-vs-device-name distinction are decided as one piece.

**Rule 9 — Sign-out must be unreachable, not just discouraged, while the broadcast
session is non-idle (carried forward from Unit 2 Business Rule 9, 2026-09-28 —
mandatory, not optional).**
`AuthNotifier.signOut()` in `zip_core` stays unconditional by design (Unit 2 Rule 9's
reasoning: `zip_core` has no broadcast concept and must stay reusable by Zip
Captions, FR-1.1). The guarantee is enforced one layer up, in `zip_broadcast`:
`ZbAppShell` is the **sole** place in the package that calls
`authNotifierProvider.notifier.signOut()` — a package-wide, review-checkable
invariant — and it refuses the call outright (the call is not made, not merely the
button disabled) while the current `BroadcasterSessionState` is `StartingState`,
`LiveState`, or `EndingState`. The mid-`goLive()` (`StartingState`) inclusion is what
closes the race Unit 2 identified: sign-out landing between "identity/signaling
established" and "state formally live." `OfflineState` and `BroadcastFailedState`
permit sign-out — both provably hold no session resources (Rule 2's unwind
guarantee). The sign-out affordance (Unit 2's `AccountSection` button, currently a
direct unguarded call — this unit switches it to the shell's guarded method, F-6.9)
may additionally be dimmed while non-idle, but correctness never depends on that.
Scope is deliberately **not** widened to "any active captioning" (the 2026-09-28
narrowing): local captioning/transcripts/OBS/browser-source/external-display stay
decoupled from `AuthState` (FR-1.4, F-BA-5) — signing out mid-local-caption without a
broadcast is safe and must stay unaffected.

**Rule 10 — No caption content or tokens in logs, ever (SECURITY-03 / SECURITY-05,
carried forward, restated for this unit's surfaces).**
Nothing in this unit logs `SttResult`/`Caption` text (the dashboard's caption
preview is rendered, never logged), TURN credentials (Unit 4's boundary), or auth
tokens (Unit 2's boundary). `LiveBroadcast`'s non-content fields — `broadcastId`,
`sessionId`, `sessionName`, `peerId`s, `captionActivity`, counts — are log-safe:
they are not transcript content, and `peerId` is the ephemeral signaling-layer id
with no account identity (NFR-6.2). The Rule 9 guard's refusal feedback names no
state details beyond "live broadcast."

**Rule 11 — Dashboard viewer data is derived, never re-tracked; the UI renders only
what the transport reports.**
`LiveBroadcast.viewers` is an exact mirror of `BroadcastTransport.viewers`
(ack-confirmed viewers, Unit 5 Rule 1) — the notifier stores what the stream emits
and adds nothing (no pending/"connecting" entries, no retained/"disconnected"
entries; a leaving viewer disappears on `viewerLeft`). "Broadcast full" is derived
(`viewers.length == maxViewers`), never a stored flag. `connectionType` is rendered
as-is — under Unit 5's current simplification every badge reads P2P direct, and the
UI must not invent TURN/connecting/disconnected values the data doesn't carry
(Proto-12's "Connecting…" and "Disconnected" rows are therefore not rendered in this
unit). No viewer identity of any kind appears on the dashboard (NFR-6.2).
