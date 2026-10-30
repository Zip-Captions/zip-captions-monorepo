# Business Logic Model — Zip Captions Viewer (Unit 7)

Orchestration is `ViewerSessionNotifier` (zip_core, keepAlive) making
**explicit calls** into the shipped services (Units 2–5) — the project
Riverpod convention; no reactive watchers trigger side effects. The notifier
owns three subscriptions it manages itself (transport `status`,
`RemoteCaptionReceiver` `activity`/`ended`, the status-channel `watch()`) —
the same "notifier-owned stream subscriptions" pattern as
`BroadcastSessionNotifier`'s `activityChanges` subscription (F3). The two
screens are pure readers of notifier state plus the existing Phase 1
`displaySettingsProvider`.

## F-7.1: Join from the join screen (S-19 AC1, AC2; FR-7.1)

1. `JoinBroadcastScreen` renders the Proto-14 form (one text field, "Join"
   button).
2. On submit, the screen calls `BroadcastLink.parseInput(text)` **locally**
   (shipped Unit 3 utility; `null` on invalid, never throws).
3. Invalid: the screen shows Proto-14's inline error ("That doesn't look like
   a valid broadcast ID or URL — check it and try again"), the Join button
   re-enables, and **no navigation and no network request occur** (S-19 AC2).
   `ViewerSessionNotifier.join()` is not called at all from the form path.
4. Valid: the screen navigates to `/b/{id}` (the parsed ID's string form).
   The `BroadcastViewerScreen` route builder then triggers the join (F-7.2
   step 1's route-reentry check). The Proto-14 "Connecting" switcher state is
   the transient pre-navigation frame; all real state rendering is the
   viewer screen's (one surface serves form flow and deep links, Q6).

## F-7.2: join(input) (S-19 AC1, AC2, AC3; FR-7.1, FR-7.2, FR-7.6)

Route reentry: `BroadcastViewerScreen`'s init calls
`join(input)` when the notifier's state is `IdleState` **or**
`currentBroadcastId` differs from the parsed input's ID (a different
broadcast deep-link while a session is active → implicit leave + rejoin,
Q7). Calling `join()` with the same ID while a non-terminal session is
active is a no-op (Rule 1).

`join(String input)` itself:

1. **Parse** (`ResolvingState` not yet set): `BroadcastLink.parseInput(input)`.
   - `null` → if a session is active (any non-idle, non-terminal state of a
     *live-ish* session: `Resolving`/`Connecting`/`LiveView`/`Reconnecting`/
     `NotBroadcasting`): **no-op** (an invalid input never tears down an
     active session — Rule 1) and log. Otherwise: state → `InvalidInputState`
     (no network call — Rule 2; S-19 AC).
2. **Implicit leave** (Q7): if `currentBroadcastId` is non-null and differs
   from the parsed ID, `await leave()` first (full teardown, idempotent).
3. **Resolve**: state → `ResolvingState`;
   `final resolution = await ref.read(broadcastResolverProvider).resolve(id)`.
   The shipped resolver is total (never throws — it maps every error to
   `rateLimited`/`resolutionFailed`), so this step cannot crash the app
   (NFR-4.1):
   | Resolution | Transition |
   |---|---|
   | `notFound` | → `CannotConnectState(NotFound)` (Rule 5: proto's generic cannot-connect copy; **no** retry action — the ID doesn't exist) |
   | `offline` | → `NotBroadcastingState`; open the status watch (step 4) |
   | `rateLimited` | → `CannotConnectState(RateLimited)` |
   | `resolutionFailed` | → `CannotConnectState(ResolutionFailed)` (Q2 — distinct copy + retry, never misreported as offline) |
   | `live(sessionId, sessionName)` | → continue to step 4; `sessionName` getter set |
4. **Create viewer resources** (only from `live` or `offline`): build
   `_ViewerResources` — viewer-scoped `CaptionBus` +
   `CaptionOutputTargetRegistry` + `OnScreenCaptionTarget(targetId: 'viewer',
   repository: null)` (registered on its registry) +
   `RemoteCaptionReceiver(transport, viewerBus)` + the transport from
   `viewerTransportFactoryProvider` + the status-channel watch:
   `signalingServiceProvider.statusChannel(id)` with `watch()` subscribed
   (Unit 3's shipped fix guarantees the first emission is delivered). The
   watch lifecycle follows Rule 4.
5. **Connect** (from `live` only — `offline` stops at step 4 and waits on the
   watch, Q5): state → `ConnectingState`; build
   `ViewerTransportContext(sessionId, broadcastId, signalingService,
   iceServers: await ref.read(iceServerProviderProvider)
   .iceServersForBroadcast(broadcastId))`; `await transport.connect(context)`.
   `connect()` returns after the handshake is *dispatched*; the outcome
   arrives on the `status` stream (step 6). A thrown exception from
   `connect()` itself (programming error, missing native stack, or a failed
   per-viewer `sessionChannel(...).open()`, which the shipped transport
   awaits inside `_attemptConnect()`) is caught here and mapped to
   `CannotConnectState(IceFailed)` with the generic "couldn't reach" copy
   (NFR-4.1: never crash). `ConnectFailure.Timeout` is **not** used for a
   raw throw — it stays reserved for the transport's own reported outcome.
   This is a session-layer mapping, not a change to the shipped transport.
   - Failure of `iceServersForBroadcast()` (broadcast-scoped TURN credential
     fetch, Unit 9 B2; like its predecessor it propagates uncaught) is caught
     here and maps to
     `CannotConnectState(ResolutionFailed)`'s sibling: **it maps to
     `CannotConnectState(IceFailed)`** — "couldn't reach this broadcast" is
     the user-understandable framing for a missing ICE configuration
     (the relay is the only non-direct path; FR-4.3/FR-4.4). Documented in
     Rule 5's table.
6. **Status stream** (notifier-owned subscription):
   | `ConnectionStatus` | Transition |
   |---|---|
   | `Connecting` | (already `ConnectingState`) |
   | `Connected(connectionType)` | cancel any window timer → `LiveViewState(_lastActivity, connectionType)` |
   | `Interrupted` | start the reconnect window (F-7.4) → `ReconnectingState` |
   | `Failed(BroadcastFull)` | → `FullState` (Rule 5 — the dedicated state, never CannotConnect) |
   | `Failed(other)` | → `CannotConnectState(other)` |
7. **Activity stream** (`receiver.activity`): update `_lastActivity`
   (default `inactive` until the broadcaster's join-time snapshot arrives —
   Unit 5 Rule 8 sends exactly one snapshot per newly joined viewer); if
   state is `LiveViewState`, in-place update `captionActivity`.
8. **Ended stream** (`receiver.ended`): F-7.5.

**No sign-in anywhere** (FR-7.6, S-19 AC): `join()` never reads
`authNotifierProvider`; every service it calls is anonymous-accessible
(resolution, status channel, join-request RPC, TURN credentials — all
designed for anonymous viewers in Units 2–4).

## F-7.3: Caption flow while live (S-19 AC4; FR-7.3)

1. `WebRtcViewerTransport` delivers decoded `CaptionWireMessage`s on
   `messages` (ordered + reliable data channel — Unit 5 Rule 5).
2. `RemoteCaptionReceiver` republishes `Caption` as `SttResultEvent` on the
   viewer bus; `CaptionActivityChanged` on `activity`; `Ended` on `ended`.
3. The viewer-scoped registry fans `SttResultEvent` to the session-scoped
   `OnScreenCaptionTarget`, which maintains its display buffer (50ms
   debounced emissions — Phase 1 behavior, unchanged).
4. `BroadcastViewerScreen` renders `CaptionDisplayWidget(entries, settings)`
   where `entries` is the session target's `visibleCaptions` /
   `onVisibleCaptionsChanged` stream and `settings` is the **viewer's own**
   `displaySettingsProvider` (FR-7.3 — the same app-level settings the
   recording screen uses; Rule 10). No attribution/label rendering exists in
   the viewer (the wire format carries no speaker label — Unit 6 Rule 8
   deferral, unchanged).

## F-7.4: Reconnection (S-19 AC7; FR-7.5)

Division of labor (Rule 3, Q3 = A): **the transport retries; the notifier
gives up.**

1. Transport `status` emits `Interrupted` → state → `ReconnectingState`;
   the notifier starts one plain `Timer(defaultBroadcastLimits
   .reconnectWindow)` (the `ReconnectPolicy` window check).
2. The shipped `WebRtcViewerTransport`'s own backoff loop (Unit 5 Rule 2:
   1s/2s/4s/8s/8s…) runs `restart()` internally — the session layer makes
   **no** `restart()` calls (double-driving would race the loop; see
   `domain-entities.md`'s F5 note).
3. On `Connected` before the timer fires: cancel the timer →
   `LiveViewState` (fresh window for the next interruption).
4. **On timer expiry** (window exceeded, Q3): read the status watch's last
   emission (the notifier has been watching the status channel for the whole
   session — Rule 4):
   - last status `offline` → `NotBroadcastingState` (watch stays open, Q5).
   - **no emission observed yet** (the initial presence sync has not
     completed, so liveness is unknown rather than confirmed live — verified
     against the shipped `SupabaseStatusChannel`, whose `watch()` waits for
     the first presence sync and may not have produced one within 120s) →
     `CannotConnectState(ResolutionFailed)` with its Q2 copy and a
     "Try again" action. This is deliberately **not** the `IceFailed`
     reconnect-timeout copy: claiming "lost connection … couldn't
     reconnect" when liveness was never established would misreport the
     cause, the same principle that keeps `resolutionFailed` distinct from
     `offline` (`domain-entities.md`).
   - last status `live` →
     `await transport.disconnect()` — Unit 5 Rule 2's *own* terminal path
     (explicit `disconnect()` → `Failed`) — → `CannotConnectState(IceFailed)`
     rendered with Proto-15's reconnect-timeout copy
     ("Lost connection to the broadcast and couldn't reconnect. Check your
     network and try again.") and a "Try again" action (F-7.9).
5. **Status-channel offline event while `ReconnectingState`** (Rule 4b): the
   broadcaster's liveness is now authoritatively known — do not wait out the
   remaining window: cancel the timer, transition immediately to
   `NotBroadcastingState` (watch stays open).
6. **Status-channel offline event while `LiveViewState`** (Rule 4c): **no
   state change** — the data channel is authoritative while captions are
   actually flowing (a brief Realtime uplink hiccup on the broadcaster must
   not yank a viewer who is still receiving captions out of `Live`). If the
   data channel subsequently drops, step 1 applies and step 4/5 will surface
   the offline status. This preserves FR-6.6's bounded-timeout guarantee
   with a concrete bound: `presenceTimeout` (60s, when the status flips
   offline) + `reconnectWindow` (120s) worst case.
7. The broadcaster side (unchanged, Unit 5 Rule 6) keeps the reconnecting
   viewer's admission slot reserved for `reconnectWindow`; the rejoin is
   re-admitted like any join.

## F-7.5: Broadcast ended (S-19 AC8; FR-6.5)

1. `receiver.ended` fires (the `broadcastEnded` wire message; F6 step 1/4).
2. State → `EndedState`; the transport is `disconnect()`ed (data channel and
   native resources released — S-19 AC "releases the connection"); the
   status watch is **closed** (Rule 6: `Ended` is terminal with respect to
   auto-behavior — no auto-rejoin if the same broadcaster goes live again;
   the approved Proto-15 copy promises auto-connect only for
   `notBroadcasting`, and "Broadcast ended … Thanks for watching" is a
   closing, not a waiting, state).
3. The viewer-scoped bus/registry/target remain alive until `leave()` so the
   last captions are not torn out from under the screen (the ended screen
   shows the message, not the caption view — the buffer is irrelevant but
   harmless; teardown is the user's leave/back action).

## F-7.6: Broadcaster disappears (FR-6.6)

Covered by F-7.4 steps 4/5/6: presence expiry (60s) flips the status channel
offline; a `Reconnecting` viewer moves to `NotBroadcasting` (immediately per
step 5, or at the window bound per step 4 — both bounded); a `Live` viewer
stays live as long as the data channel holds (step 6), then follows F-7.4.
A viewer in `NotBroadcasting` is unaffected (already there).

## F-7.7: leave() (S-19 AC; idempotent)

1. `leave()` is callable from any state; a second call is a no-op (Rule 1).
2. Teardown (the `_ViewerResources.disposeAll` pattern, each step
   individually caught-and-logged, terminal state always completed — the
   Unit 6 NFR Design discipline): cancel the window timer → cancel the
   status-watch subscription and `close()` the status channel →
   `transport.disconnect()` → `receiver.dispose()` → on-screen target
   `dispose()` → registry `dispose()` → bus `dispose()` → null
   `_resources` → state → `IdleState`; `sessionName`/`currentBroadcastId`
   cleared.
3. The screen-level confirm dialog (Rule 9, Q8) gates the *user actions*
   that call `leave()` — the notifier itself has no dialog concern.

## F-7.8: notBroadcasting auto-join (Q5 = A)

1. The status watch stays open in `NotBroadcastingState` (Rule 4a).
2. On a `live(sessionId, sessionName)` emission: run F-7.2 steps 4–6 for the
   **new** session (the viewer already exists for this broadcast — no
   re-resolve, no re-parse; `sessionName` getter updated). The state path is
   `NotBroadcasting → Connecting → LiveView`.
3. On an `offline` emission: no change (already there).
4. The watch stays open until `leave()`, `Ended`, a `Full`/`CannotConnect`
   outcome of the auto-join, or a different-broadcast `join()` (which
   leaves first).

## F-7.9: "Try again" (Q4 = A)

The cannot-connect screen's "Try again" button calls `join(currentInput)`
— a **full rejoin from the top** (re-resolve). This deliberately handles the
session-changed case (broadcaster ended and went live again under a new
session id) at the cost of one extra resolution RPC. No `transport.restart()`
path exists in the UI.

## State transition table (PBT-06's reference model)

From \ Event → To

| From | Event | To |
|---|---|---|
| — (build) | — | `Idle` |
| `Idle` | `join(valid)` | `Resolving` |
| `Idle` | `join(invalid)` | `InvalidInput` |
| `InvalidInput` | `join(valid)` | `Resolving` |
| `Resolving` | resolution `notFound` | `CannotConnect(NotFound)` |
| `Resolving` | resolution `offline` | `NotBroadcasting` |
| `Resolving` | resolution `rateLimited` | `CannotConnect(RateLimited)` |
| `Resolving` | resolution `resolutionFailed` | `CannotConnect(ResolutionFailed)` |
| `Resolving` | resolution `live` | `Connecting` |
| `Connecting` | status `Connected(t)` | `LiveView(activity, t)` |
| `Connecting` | status `Failed(BroadcastFull)` | `Full` |
| `Connecting` | status `Failed(f)` | `CannotConnect(f)` |
| `Connecting` | status `Interrupted` | `Reconnecting` (window timer starts) |
| `Connecting` | receiver `ended` | `Ended` |
| `LiveView` | activity `a` | `LiveView(a, t)` (in place) |
| `LiveView` | status `Interrupted` | `Reconnecting` (window timer starts) |
| `LiveView` | status `Failed(f)` | `Full` / `CannotConnect(f)` per f |
| `LiveView` | receiver `ended` | `Ended` |
| `LiveView` | status-channel `offline` | **no change** (Rule 4c) |
| `Reconnecting` | status `Connected(t)` | `LiveView(activity, t)` (timer cancelled) |
| `Reconnecting` | window expiry + last status offline | `NotBroadcasting` |
| `Reconnecting` | window expiry + last status live | `CannotConnect(IceFailed)` (via `disconnect()`) |
| `Reconnecting` | window expiry + no status emission yet | `CannotConnect(ResolutionFailed)` |
| `Reconnecting` | status-channel `offline` | `NotBroadcasting` (timer cancelled, Rule 4b) |
| `Reconnecting` | receiver `ended` | `Ended` |
| `NotBroadcasting` | status-channel `live(s)` | `Connecting` (auto-join, F-7.8) |
| `NotBroadcasting` | status-channel `offline` | no change |
| any terminal (`Ended`/`Full`/`CannotConnect`/`InvalidInput`) | any transport/status event | **no change** (Rule 6 — subscriptions are inert/closed) |
| any state | `leave()` | `Idle` |
| non-idle | `join(different valid input)` | `Idle` → `Resolving` (implicit leave, Q7) |
| non-terminal, same ID | `join(same valid input)` | no change (Rule 1) |

**Invariants** (checked after every command in the stateful PBT):

1. `_ViewerResources` is non-null in **every** state except `Idle` and
   `InvalidInput` — including the four terminal states (`Ended`, `Full`,
   `CannotConnect`), which keep the viewer-scoped caption pipeline (and the
   caption buffer behind `Reconnecting`'s "last captions remain visible" and
   `F-7.5` step 3's "teardown is the user's leave/back action") until
   `leave()`. What differs per state is the *sub-resource set*, not the
   holder's presence: `Resolving` carries none yet (it precedes step 4); the
   terminal states release the transport and close the status watch but keep
   the bus/registry/target. This is the model's second column in the Code
   Generation plan.
2. At most one transport, one receiver, one bus, one registry, one target,
   and at most one status-watch subscription exist at any time.
3. The status watch is open iff the broadcast's existence has been confirmed
   (resolution `offline`/`live`) **and** the state is not one of
   `Idle`/`InvalidInput`/`Ended`/`Full`/`CannotConnect`.
4. No state is reachable that carries caption content; no event handler
   touches `authNotifierProvider`.
5. Every transition out of a state with live resources completes teardown of
   exactly the resources that state owned (no leaks — NFR-1.4's
   no-connection-leaks requirement, model-level form).

## Testable Properties (PBT-01)

- **PBT-02 (round-trip)**: for every generated `BroadcastId` (Crockford
  Base32, 6 chars, the domain generator) and every generated URL form
  (bare ID, `host/b/{id}`, full `https://…` with the configured base),
  `BroadcastLink.parseInput(BroadcastLink.toUrl(id)) == id` and
  `parseInput(id.value) == id`; conversely, `parseInput` of a generated
  *invalid* string (wrong length, out-of-alphabet characters, garbage
  schemes) is `null`. (The shipped Unit 3 utility gets its story-assigned
  PBT row here.)
- **PBT-06 (stateful)**: random command sequences —
  `join(valid/invalid/different)`, transport status events
  (`Connecting`/`Connected`/`Interrupted`/`Failed(f)`), activity events,
  `ended`, status-channel events (`live`/`offline`), window-timer expiry,
  `leave()` — executed against both `ViewerSessionNotifier` (with fakes for
  resolver/transport/receiver/status channel, `fakeAsync` clocks) and the
  reference model above; after **each** command, assert the observer state
  and the resource invariants 1–5 match. Sequences of varying length
  including empty.
- **Rule 5 mapping is exhaustive**: every `ConnectFailure` variant produced
  by any reachable path resolves to exactly one (state, copy, retry) triple
  — example-based table test pins all seven; the stateful PBT covers the
  interleavings.
