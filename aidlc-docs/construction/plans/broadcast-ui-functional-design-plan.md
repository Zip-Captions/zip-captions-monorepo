# Functional Design Plan: Zip Broadcast Broadcast UI (Unit 6)

**Unit**: broadcast-ui
**Stories**: S-17
**Packages**: zip_core (session orchestration), zip_broadcast (screens, shell)
**Branch**: `feature/broadcast-ui` (off `develop`)
**Dependencies**: Unit 5 (merged, PR #31), Proto-11 and Proto-12 (approved)

## What's Already Decided (from phase2-application-design.md / phase2-component-methods.md / phase2-services.md)

Not open for reinterpretation here — Functional Design elaborates these, it doesn't
re-decide them:
- `BroadcastSettings` (`sessionName`, `autoStartCaptioning`), `BroadcastSessionNotifier`
  (`build()`/`goLive()`/`endBroadcast()`), the sealed session-state class (`Offline` |
  `Starting` | `Live(LiveBroadcast)` | `Ending` | `BroadcastFailed(BroadcastFailure)`),
  `LiveBroadcast` (7 fields: `broadcastId`, `url`, `sessionId`, `sessionName`,
  `captionActivity`, `viewers`, `maxViewers`), `BroadcastFailure` enum (`signedOut`,
  `signalingUnavailable`, `relayUnavailable`, `identityUnavailable`, `unknown`) — all
  fixed verbatim per `phase2-component-methods.md` §6, **except two approved
  deviations**: (1) the sealed session-state class's own name — Application Design
  calls it `BroadcastSessionState`; this stage renames it to `BroadcasterSessionState`
  (Q2); (2) `LiveBroadcast` gains an eighth field, `startedAt` (Q3), not present in the
  fixed shape. Both are additive/rename-only — no removed fields, no changed variant
  behavior.
- `goLive()`'s 9-step sequence (`phase2-services.md` F2) and `endBroadcast()`'s sequence
  (F6) — this unit implements them, read against Unit 3.1/Unit 5's actual shipped
  shape where F2's text predates those units (see `business-logic-model.md` F-6.2).
- Unit 2 Business Rule 9 (sign-out guard) is **carried forward as mandatory**, not an
  open question: `ZbAppShell` must be the sole call path to
  `AuthNotifier.signOut()` in `zip_broadcast`, refusing the call outright (not just a
  disabled button) while the broadcast session is non-idle.
- `RemoteBroadcastTarget`'s caption-activity mapping (`RecordingActiveState` →
  `active`, `Paused`/`ReconnectingState` → `paused`, `Idle`/`StoppedState` →
  `inactive`) — fixed at Application Design, Unit 5 shipped.

## Planned Functional Design Artifacts

- [x] `aidlc-docs/construction/broadcast-ui/functional-design/domain-entities.md`
- [x] `aidlc-docs/construction/broadcast-ui/functional-design/business-logic-model.md`
- [x] `aidlc-docs/construction/broadcast-ui/functional-design/business-rules.md`

## Open Questions

### Q1: Add a new `CaptioningStarter` seam in `zip_core`?
Application Design's F2 step 8 and its coupling note never specify how a `zip_core`
notifier (`BroadcastSessionNotifier`) reaches the app's recording machinery —
`zip_broadcast`'s `BroadcastRecordingNotifier` is a `zip_broadcast` class, unreachable
from `zip_core` by dependency direction; `zip_core`'s own `RecordingStateNotifier` is
the unrelated single-engine Zip Captions one.

- A. New `CaptioningStarter` interface in `zip_core` (`currentActivity` getter +
  `start()`), default impl wraps `RecordingStateNotifier`, `zip_broadcast`'s `main.dart`
  overrides it with a `BroadcastRecordingNotifier`-backed implementation — same
  override pattern as `authServiceProvider`/`supabaseClientProvider` (Unit 2)
  **(recommended)**
- B. Have `BroadcastSessionNotifier` depend on `zip_broadcast` directly (breaks the
  existing package dependency direction — not recommended)
- C. Other (write in)

[Answer]: A

### Q2: `BroadcastSessionState` name collides with an existing Phase 1 model — rename?
`zip_broadcast` already has a *different*, unrelated `BroadcastSessionState` sealed
class (the local multi-engine captioning state machine used by
`BroadcastRecordingNotifier`: `BroadcastIdleState`/`BroadcastActiveState`/etc.). Only
the sealed base class name collides; this unit's own variant names (`OfflineState`,
`StartingState`, `LiveState`, `EndingState`, `BroadcastFailedState`) are all distinct
from the Phase 1 ones.

- A. No rename on either side; disambiguate only at use sites that need it with an
  import alias on the Phase 1 model
- B. Rename the Phase 1 model (e.g. `CaptioningSessionState`) to remove the collision
  entirely
- C. Rename *this unit's* class to `BroadcasterSessionState` instead — resolves the
  collision fully (no alias needed anywhere) and is more accurate: it names the
  *broadcaster's* own session, as distinct from `ViewerSessionState` (also fixed, same
  `zip_core` orchestration layer). Requires explicit approval as a deviation from
  Application Design's fixed name (`phase2-component-methods.md` §6 names it
  `BroadcastSessionState` verbatim) — no field/variant/behavior change, purely a
  rename. **(chosen)**
- D. Other (write in)

[Answer]: C — approved; propagated into `domain-entities.md`, `business-logic-model.md`,
`business-rules.md` as `BroadcasterSessionState`.

### Q3: How does the dashboard get a broadcast "duration" / start time?
`LiveBroadcast`'s fixed shape carries no `startedAt` field, but Proto-12's dashboard
has a "Duration" stat card.

- A. UI-local timestamp: a small keepAlive provider in `zip_broadcast` records
  `DateTime.now()` the first time it observes `LiveState` for the current
  `sessionId`, cleared when the session ends or a new one starts
- B. Add a `startedAt` field to `LiveBroadcast` — a change to the fixed Application
  Design shape (`phase2-component-methods.md` §6 lists 7 fields; this adds an 8th).
  **(chosen — approved deviation)** Simpler for the dashboard (one source of truth,
  no separate UI-local provider to keep in sync with `sessionId` changes) at the cost
  of a real, if small, Application Design shape change.
- C. Other (write in)

[Answer]: B — approved; propagated into `domain-entities.md` (`LiveBroadcast.startedAt`,
set in `goLive()`'s F2-9 step) and `business-logic-model.md` (F-6.5's duration source).

### Q4: `RemoteBroadcastTarget` doesn't honor "initial activity from current recording state" as written
`phase2-component-methods.md` says the target's initial caption activity "comes from
the current recording state when the target is created," but the actual shipped Unit 5
code (`remote_broadcast_target.dart`) has only a single-argument constructor that
always defaults `currentActivity` to `inactive`. If captioning is already running when
`goLive()` registers the target, newly-joined viewers would get a wrong `inactive`
snapshot until the next state change — this is a real gap between documented intent
and shipped code, verified by reading the actual constructor.

- A. Add an additive `primeActivity(CaptionActivity activity)` method;
  `BroadcastSessionNotifier` calls it immediately after registering the target, with
  `captioningStarter.currentActivity` (Q1) **(recommended — no signature change to the
  existing constructor, no behavior change to anything already shipped)**
- B. Publish a synthetic `SessionStateEvent` on the app caption bus at registration
  time instead (rejected in the draft — `TranscriptWriterTarget` would mistake it for
  a new recording session and re-run `createSession`)
- C. Other (write in)

[Answer]: A

### Q5: How does a viewer mid-reconnect learn the broadcast ended?
F6 step 1 assigns the `BroadcastEnded` *signaling* message to `endBroadcast()`, but the
fixed `BroadcastTransport` interface (Unit 5) exposes no way to send a signaling-layer
message — only the wire-level `sendToAll(CaptionWireMessage.Ended)`, which only reaches
viewers with a currently-open data channel.

- A. Add an additive `BroadcastTransport.sendBroadcastEnded()` method so a viewer
  mid-restart (data channel briefly down) still learns the broadcast ended via
  signaling, rather than only discovering it when their reconnect window times out
  as `notBroadcasting` **(recommended)**
- B. Accept the niche: a viewer mid-restart learns the broadcast ended only via
  reconnect-window timeout, no new method
- C. Other (write in)

[Answer]: A

### Q6: Mechanism for `ZbAppShell`'s sign-out guard (Rule 9)
The guard requires `ZbAppShell` to be the sole caller of
`AuthNotifier.signOut()`, with `AccountSection`'s sign-out button routed through it
instead of calling `signOut()` directly as it does today.

- A. New `InheritedWidget` (or `InheritedNotifier`) exposing
  `Future<void> requestSignOut()`, implemented by `_ZbAppShellState` — the codebase has
  no existing inherited-widget pattern for this, but it's the standard Flutter
  mechanism for "a descendant needs to call back up to an ancestor" **(recommended)**
- B. Pass a callback down explicitly through widget constructors from `ZbAppShell` to
  `AccountSection` (more plumbing through intermediate widgets, no new widget type)
- C. Other (write in)

[Answer]: A

### Q7: Session name maximum length
`BroadcastSettings.validateSessionName`'s "too long" category needs a concrete limit;
Application Design doesn't fix one.

- A. 100 code units **(recommended — matches the codebase's other free-text field
  limits; generous for a session label, short enough to render cleanly in the URL
  row and viewer-facing contexts)**
- B. Other (write in a different limit)

[Answer]: A

### Q8: When is the broadcast URL fetched/shown, and is there a separate dashboard route?
Proto-11 shows the stable broadcast URL on the setup screen before going live;
Proto-12 shows it again on the live dashboard.

- A. Fetch `getOrCreateMine()` once per screen mount while signed in (not gated on
  `goLive()`); one route whose content switches on `BroadcasterSessionState` rather than
  a separate dashboard route **(recommended — matches the existing
  `ZbAppShell`/state-driven routing pattern, avoids a redundant second fetch)**
- B. Separate `BroadcastSetupScreen` and `LiveBroadcastDashboard` routes, with explicit
  navigation on successful `goLive()`
- C. Other (write in)

[Answer]: A

### Q9: Per-input mute/toggle controls on the live dashboard
Proto-12 mocks a per-audio-input toggle on the dashboard, but no per-input mute state
exists anywhere in Phase 1 to back it.

- A. Defer: Unit 6 ships the per-input rows read-only (name/level/status only); the
  toggle ships in whichever unit adds per-input mute state **(recommended — no
  Phase 1 state exists to drive a real toggle yet; a cosmetic-only toggle would be
  misleading)**
- B. Add minimal per-input mute state now as part of this unit, scoped only to the
  broadcast dashboard
- C. Other (write in)

[Answer]: A

## Already-Resolved Backlog Items (not open questions — decided in the draft, with reasoning)

- **Caption attribution / speaker-name prefix** (2026-09-25 Backlog item): resolved as
  **deferred** in `business-rules.md` Rule 8 — the wire format (`CaptionWireCodec` v1,
  Unit 5 shipped) has no label field, and adding one now would require a coordinated
  wire-version bump with Unit 7's viewer-side decode, which this unit is not scoped to
  do. Phase 1's existing on-screen attribution (per-input label + color) is unaffected
  and keeps working for local viewers and the broadcaster's own display; only remote
  viewers see unattributed text in Phase 2. Revisit together with the unit that bumps
  the wire codec version.
