# Business Logic Model — Zip Broadcast Broadcast UI (Unit 6)

Orchestration is `BroadcastSessionNotifier` (zip_core, keepAlive) making **explicit
calls** into the existing services — the project Riverpod convention; no reactive
watchers trigger side effects. The two screens are pure readers of notifier state plus
the existing Phase 1 providers. `ZbAppShell` gains exactly one new responsibility:
the Rule 9 sign-out guard (F-6.9). Reconnection handling is **not** this unit's
concern — `ConnectionStatus`/`restart()`/`ReconnectPolicy` belong to Unit 5 (transport)
and Unit 7 (viewer orchestration); this unit only consumes what the transport reports.

## F-6.1: Broadcast Setup Screen (S-17 AC1, AC10)

1. The screen reads, per build: `broadcastSettingsNotifierProvider` (session name,
   auto-start toggle), `outputTargetSettingsNotifierProvider` (+
   `obsConnectionNotifierProvider` for the OBS row — the existing Phase 1 pattern in
   `HomeScreen`), and `authNotifierProvider`.
2. **Output targets**: the selection grid is the existing Phase 1 `OutputTargetsPanel`
   (On-Screen / OBS WebSocket / Browser Source / Caption Overlay / Transcripts);
   toggles persist through the existing `OutputTargetSettingsNotifier.update`.
   **No relay option exists anywhere in the form** (FR-6.1) — there is no toggle, row,
   or menu entry for a relay in Phase 2.
3. **Session name**: two-way bound to `BroadcastSettings.sessionName`, persisted on
   change (Phase 1 settings pattern). Live inline validation on edit via
   `BroadcastSettings.validateSessionName` (Rule 7) — the specific message per error
   category (empty / too long / control characters), rendered as in Proto-11's
   "Session name is required" pattern.
4. **Signed-out state** (`AuthState` not `SignedIn`): the Proto-11 overlay
   ("Sign in to broadcast … or go back to use local output targets only") covers the
   form; the Go Live button is unreachable under the overlay. The URL row is hidden
   (no ID is fetched while signed out — Q8).
5. **Signed-in state**: on screen load (once per mount), the screen calls
   `broadcastIdentityRepositoryProvider.getOrCreateMine()` to display the stable URL
   `BroadcastLink.toUrl(id)` in the URL row with the copy-to-clipboard action
   (Proto-11; Q8 recommends this timing). The ID is the broadcaster's permanent one —
   the same row content the dashboard will show once live.
6. **Go Live tap** → `broadcastSessionNotifierProvider.notifier.goLive()`. If the state
   resolves to `BroadcastFailedState(signedOut)` (only reachable if the session was
   passively lost between render and tap), the screen shows the sign-in prompt
   (F1/F-BA-4: on sign-in success the prompt dismisses, the form is intact, the user
   taps Go Live again — **no automatic goLive retry**).
7. **Starting state** (`StartingState`): the Go Live button renders a progress state
   (disabled spinner, per Proto-11's button); the form is inert. All other
   `BroadcasterSessionState` values route the screen to the dashboard (Q8: one route,
   content switches on state).

## F-6.2: goLive() (S-17 AC2, AC8, AC11)

Follows `phase2-services.md` F2's 9-step sequence exactly. Note on step 4: F2's text
predates Unit 3.1 — there is no broadcaster-side session channel to open (Unit 3.1
removed the shared `signaling:{session_id}` channel; the broadcaster learns of joins
via `signalingService.joinRequests(broadcastId)` and opens per-viewer channels
itself). Unit 5's own Functional Design revision (2026-10-07) already applies this
reading: the join-request stream is subscribed **inside** `transport.start()` (F2 step
5's context), so F2 step 4 has no independent action left and no independent failure
mode of its own (its failure surfaces through step 5).

0. **Pre-flight (no state change yet):** accepted only from `OfflineState` or
   `BroadcastFailedState` (Rule 1 — any other state: no-op). Session name validated
   via `BroadcastSettings.validateSessionName` (Rule 7) — invalid: return with no
   state change (the UI's inline error is the user-facing message; a programmatic
   call with an invalid name can never start a session).
1. **State → `StartingState`** (synchronously, before the first await — this is what
   makes the mid-`goLive()` window visible to the Rule 9 guard).
2. **F2-1 — sign-in check:** `authNotifierProvider` state not `SignedIn` →
   `failed(signedOut)`. No resources exist; nothing to unwind.
3. **F2-2 — identity:** `broadcastIdentityRepositoryProvider.getOrCreateMine()` →
   `BroadcastId`.
4. **F2-3 — session + ICE:** generate `sessionId` (UUID v4);
   `iceServerProviderProvider.iceServersFor(sessionId)` (TURN credentials fetched
   inside, Unit 4).
5. **F2-4 — (superseded in place by Unit 3.1/Unit 5, see above):** no action.
6. **F2-5 — transport:** `TransportSelector.broadcastTransport().start(BroadcastTransportContext(
   sessionId, broadcastId, signalingService, iceServers, ViewerAdmission(defaultBroadcastLimits)))`.
   The `ViewerAdmission` instance is created here, per session, and owned by the
   notifier for teardown.
7. **F2-6 — target:** create `RemoteBroadcastTarget(transport)`, register it on the
   app `CaptionOutputTargetRegistry`, then **prime its initial activity** from
   `captioningStarter.currentActivity` (Rule 4 / Q4 — this is what makes F2 step 6's
   "created with its initial activity from the current recording state" true for the
   already-recording case).
8. **F2-7 — publish live:** open `signalingService.statusChannel(broadcastId)` (held
   open for the broadcast's lifetime — Rule 6) and `publishLive(sessionId,
   sessionName)`.
9. **F2-8 — optional coupled start:** if `settings.autoStartCaptioning` and
   `captioningStarter.currentActivity == CaptionActivity.inactive` →
   `captioningStarter.start()` (F-6.3).
10. **F2-9 — state → `LiveState`** with `LiveBroadcast(broadcastId, url, sessionId,
    sessionName, captionActivity: the seeded value, viewers: [], maxViewers,
    startedAt: DateTime.now())` (Q3 — `startedAt` stamped here, the instant the
    broadcast actually becomes live, not before), then start the two owned
    subscriptions: `target.activityChanges` (F-6.4) and `transport.viewers` (F-6.5).

**Failure at any step 2–8:** catch, **unwind completed steps in reverse**
(`business-rules.md` Rule 2 table — close status channel, `registry.remove(target)`
(which disposes it), `transport.stop()`), state → `BroadcastFailedState(variant)`
per the Rule 2 mapping. Local captioning is untouched on every failure path (no
captioning interaction exists before F2-8, and F2-8's failure is non-fatal — Rule 3).
The setup screen renders the failed state with the specific reason and a retry
(S-17 AC11; Proto-12's start-failure card copy pattern).

## F-6.3: Auto-Start Captioning (S-17 AC7)

1. Condition (F2 step 8): `autoStartCaptioning == true` **and**
   `captioningStarter.currentActivity == CaptionActivity.inactive` ("recording is
   idle"). If captioning is already active or paused, `start()` is not called — an
   already-running session is never restarted or interrupted.
2. `captioningStarter.start()` — in `zip_broadcast` the override delegates to
   `BroadcastRecordingNotifier.start()` (multi-engine; guards itself: no-op unless
   idle; partial engine failure continues with the survivors).
3. **Success:** the recording notifier publishes `SessionStateEvent(RecordingState.
   recording)` on the app bus as it does in Phase 1; the registry delivers it to the
   just-registered `RemoteBroadcastTarget`, whose activity becomes `active` and emits
   `activityChanges` → `LiveBroadcast.captionActivity = active` → banner hidden (F-6.4).
4. **Failure (no audio inputs configured, or all engines fail):** the recording
   notifier stays idle (with its `lastError`) and publishes no event →
   `captionActivity` stays `inactive` → the banner shows the "hasn't started yet"
   variant. **`goLive()` is unaffected** (Rule 3) — the broadcast goes live; the
   broadcaster starts captioning manually from the dashboard.

## F-6.4: Captioning Changes While Live (S-17 AC9, FR-6.7, F3)

1. `BroadcastRecordingNotifier` publishes `SessionStateEvent`s on the app bus exactly
   as in Phase 1. Nothing changes there.
2. `RemoteBroadcastTarget.onCaptionEvent` maps each event to a `CaptionActivity`,
   sends `CaptionActivityChanged` to all viewers, and emits on `activityChanges`
   (Unit 5 shipped behavior — unchanged).
3. `BroadcastSessionNotifier`'s owned `activityChanges` subscription updates
   `LiveBroadcast.captionActivity` in place (new `LiveState` with the updated
   `LiveBroadcast` — F-6.4 step 3 of F3, "a stream subscription it owns, not a
   provider watcher").
4. **Banner matrix** (dashboard; FR-6.7's "large, prominent notice"):
   - `active` → banner hidden.
   - `inactive`, captioning never active since this broadcast went live →
     "Captioning hasn't started yet — viewers are connected but won't see any captions
     until you start captioning." (Proto-12 `captions-inactive-start` copy.)
   - `inactive` after having been active → "Captions are not running — viewers are
     connected but won't see any captions until you start captioning." (Proto-12
     `captions-inactive` copy.)
   - `paused` → banner shown with the "not running" copy. **Flagged assumption:**
     Proto-12 defines no separate `paused` banner state; the dashboard's
     Start/Resume/Pause button (next section) carries the start-vs-resume distinction,
     so reusing the existing "not running" copy for `paused` is the conservative
     reading. The "never active since live" flag is UI-local (reset per `sessionId`).
5. **Stopping or pausing captioning never ends the broadcast** (FR-6.7) — no code path
   connects a recording-state change to `endBroadcast()`.
6. Viewers seeing "captions paused by the broadcaster" (FR-7.4) is Unit 7's
   `BroadcastViewerScreen` consuming the `CaptionActivityChanged` messages — out of
   scope here.

## F-6.5: Live Dashboard Data (S-17 AC3)

1. **Viewer count against cap:** `LiveBroadcast.viewers.length / maxViewers`,
   updated by the notifier's owned `transport.viewers` subscription (in-place
   `LiveBroadcast` update on each emission). No viewer can complete a join before
   F2-7's `publishLive` (a viewer only connects after `BroadcastResolver` reports
   live — F4 step 3), so the subscription started in F2-9 cannot realistically miss
   an initial join; the list is exact from that point (re-emitted on every
   join/leave).
2. **Per-viewer connection type:** render `ViewerConnectionInfo.connectionType` as-is
   (P2P-direct / TURN-relayed badges). Note Unit 5's shipped simplification:
   `connectionType` is currently always `p2pDirect` (no candidate-pair query on the
   seam) — the dashboard renders what the data says and never invents values.
   Proto-12's "Connecting…" and "Disconnected" viewer rows are **not renderable** from
   `viewers` (ack-confirmed viewers only; a leaving viewer is removed, not retained) —
   the dashboard does not show them (Rule 11).
3. **Caption preview:** the dashboard subscribes to the app `CaptionBus`
   (`captionBusProvider`) and shows the latest `SttResultEvent`'s text (Phase 1
   display semantics); empty state per Proto-12 ("No captions yet — start captioning
   to show live captions here."). SECURITY-03: preview text is rendered, never logged.
4. **Audio level:** `audioLevelProvider` (Phase 1 placeholder — returns an empty map
   until `AudioDeviceService`'s level API lands); the meter renders neutral when
   empty.
5. **Duration:** `DateTime.now().difference(LiveBroadcast.startedAt)` (Q3 — read
   directly off the state; computed in the UI, not stored anywhere).
6. **Broadcast-full banner:** `viewers.length == maxViewers` → the Proto-12
   non-blocking banner ("This broadcast is at its {cap}-viewer cap — new viewers
   can't join until someone disconnects."). Derived in the UI; no state change; new
   join refusals are the transport's existing behavior (Unit 5 Rule 6 / S-18).
7. **Captioning controls** (Proto-12's Pause / Resume / Start Captioning button):
   direct calls to the existing `BroadcastRecordingNotifier.pause()`/`resume()`/
   `start()` — their effect on the broadcast is entirely via F-6.4's activity flow.
   Per-input audio rows: read-only (name, level, status from
   `BroadcastRecordingNotifier`'s per-engine states) — the Proto-12 per-input *toggle*
   is deferred (Q10; no Phase 1 per-input mute state exists to drive it).

## F-6.6: endBroadcast() (S-17 AC4, F6)

1. Accepted only from `LiveState` (Rule 5): from `EndingState` → no-op (idempotent);
   from any other state → no-op.
2. **State → `EndingState`.**
3. **F6-1:** `transport.sendToAll(CaptionWireMessage.Ended)`, then the
   `BroadcastEnded` signaling message via `transport.sendBroadcastEnded()` (Q5,
   answered A — the additive method is added to `BroadcastTransport`).
4. **F6-2:** `transport.stop()` (closes every peer connection, releases native
   resources and all admission slots — Unit 5 behavior), then
   `registry.remove(target)` (unregisters and disposes the target, closing its
   `activityChanges` stream).
5. **F6-3:** `statusChannel.publishOffline()` (presence and live status cleared),
   then `statusChannel.close()`.
6. Cancel the notifier's owned subscriptions (defensive — both streams are already
   closed by steps 4's teardowns).
7. **State → `OfflineState`.**
8. **Local captioning continues unaffected** (S-17 AC8; FR-6.7) — `endBroadcast()` has
   no interaction with `BroadcastRecordingNotifier`.
9. The dashboard unmounts (the route re-renders the setup form); there is no separate
   duration state to clear (Q3's `startedAt` lives on the now-discarded
   `LiveBroadcast`) — the next `goLive()` (F-6.7) stamps a fresh `startedAt` on a
   fresh session.

## F-6.7: End and Restart (S-17 AC5)

A new `goLive()` after `endBroadcast()`: `getOrCreateMine()` returns the **same**
`BroadcastId` (Unit 3's per-owner unique registry row) → same stable URL; a **new**
`sessionId` (fresh UUID v4) → fresh status publish, transport, admission and
per-viewer channels. Nothing from the ended session is reused.

## F-6.8: Broadcaster Disappears (S-17 AC9, FR-6.6, NFR-4.3)

1. Crash or network loss with no clean end: the app holds nothing further; the
   `StatusChannel`'s Realtime subscription dies with the process.
2. After the presence timeout (`defaultBroadcastLimits.presenceTimeout`, interim 60s),
   Realtime's platform behavior expires the presence and emits `offline` on
   `status:{broadcast_id}` (Unit 3 `business-rules.md` Rule 6 — no application-level
   heartbeat; there is deliberately no code in this unit for this path).
3. Viewers already in `reconnecting` move to `notBroadcasting` when their reconnect
   window closes (F5 — Unit 7's concern); no stale live status remains.
4. This unit's only obligation is the positive one: **hold the status channel open for
   the broadcast's whole lifetime** (Rule 6) — a notifier bug that closed it early
   would make presence expire mid-broadcast and break this flow.

## F-6.9: Sign-Out Guard (Unit 2 Rule 9, carried forward — mandatory)

Exactly where the check sits in `ZbAppShell`'s flow:

1. `ZbAppShell` (existing `ConsumerStatefulWidget`) wraps its `child` — the route
   content — in a scope widget that exposes `Future<void> requestSignOut()`.
   Mechanism (Q6 recommends a new InheritedWidget — the codebase has none today):
   the method is implemented on `_ZbAppShellState` itself, so **`ZbAppShell` is the
   sole class in `zip_broadcast` that calls
   `ref.read(authNotifierProvider.notifier).signOut()`** — a package-wide invariant
   checkable by code review, per Unit 2 Rule 9's "exactly one gate."
2. `requestSignOut()`:
   - Reads the current `broadcastSessionNotifierProvider` state.
   - **If `StartingState`, `LiveState`, or `EndingState`: refuse outright — the
     `signOut()` call is not made.** Show feedback at the shell level ("End the live
     broadcast before signing out" snackbar). This is the guard; a disabled or dimmed
     button in `AccountSection` may additionally exist as cosmetics but is never the
     mechanism (Unit 2 Rule 9: a disabled-button-only guard is bypassable by any
     other call path — and there is exactly one call path).
   - **If `OfflineState` or `BroadcastFailedState`:** call
     `authNotifierProvider.notifier.signOut()`. Both states have no session resources
     (Rule 2's unwind guarantee for `BroadcastFailedState`), so sign-out cannot orphan
     a broadcast. (Unit 2's own rules 2/8 — local-first, idempotent — apply
     unchanged.)
3. `AccountSection`'s sign-out button (currently in `SettingsScreen`) switches from
   its direct `authNotifierProvider.notifier.signOut()` call (shipped in Unit 2,
   unguarded) to `scope.requestSignOut()`. The button stays enabled whenever signed
   in, so the refusal feedback is reachable and testable.
4. **Scope is deliberately not widened** (the 2026-09-28 narrowing recorded in the
   Backlog entry): the guard covers the *broadcast session* only. Signing out while
   local captioning runs with no broadcast stays allowed and unaffected
   (FR-1.4/F-BA-5).
5. **`zip_core` is untouched by this rule:** `AuthNotifier.signOut()` remains
   unconditional — `zip_core` gains no broadcast concept for this (Unit 2 Rule 9's
   reasoning; FR-1.1 reuse by Zip Captions, which never broadcasts).

## Reconnection handling — explicitly not this unit

`ConnectionStatus`, `WebRtcViewerTransport.restart()`'s backoff, and `ReconnectPolicy`
are Unit 5's and Unit 7's (already shipped / scheduled respectively). This unit
**consumes** the transport's reports — `viewers`/`viewerLeft` for the dashboard
(F-6.5) and the per-session `ViewerAdmission` (whose reconnect-window slot
reservation is Unit 5's Rule 6) — and adds no reconnection logic, timing, or state of
its own.
