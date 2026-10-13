# Domain Entities — Zip Broadcast Broadcast UI (Unit 6)

## BroadcastSettings (freezed model, fixed at Application Design)

```
BroadcastSettings { String sessionName; bool autoStartCaptioning }   // autoStartCaptioning default false
```

- `sessionName` default: empty string (first-run users see an empty input with
  placeholder, per approved Proto-11; Go Live requires a valid name — `business-rules.md`
  Rule 7).
- `autoStartCaptioning` default: `false` (Application Design plan Q3 — independent
  lifecycles by default, optional coupled start).
- **Validation contract (fixed at this stage, Rule 7):** a static validator on the
  model — `static String? validateSessionName(String name)` returning a localized-error
  *key* (never the message) or `null` — with exactly three error categories: empty
  (after trim), too long (max length fixed at Q7, recommended 100), contains a control
  character (U+0000–U+001F, U+007F). Shared by the setup screen's live inline validation
  and `BroadcastSessionNotifier.goLive()`'s pre-flight check, so no invalid name can
  reach the session state machine through any call path.
- **Persistence (Phase 1 settings pattern, see `BroadcastSettingsNotifier`):**
  `SharedPreferences` keys `broadcast.sessionName` (String) and
  `broadcast.autoStartCaptioning` (Bool, default false). Only `zip_broadcast` consumes
  this model in Phase 2, so a plain key prefix suffices; each app has its own
  `SharedPreferences` instance regardless.

## BroadcasterSessionState (sealed, renamed from Application Design's `BroadcastSessionState` — Q2, approved deviation)

**Deviation from the fixed Application Design shape (Q2):** Application Design names
this class `BroadcastSessionState` verbatim (`phase2-component-methods.md` §6). This
stage renames it to `BroadcasterSessionState` — purely mechanical, no field/variant/
behavior change — for two reasons: (1) it collides with an unrelated, already-shipped
Phase 1 `BroadcastSessionState` (see below), and (2) it is more accurate: this class is
specifically the *broadcaster's* own session, distinct from `ViewerSessionState`
(also fixed, same `zip_core` orchestration layer) which is the *viewer's* session.
Requires explicit human approval as a change to a fixed shape, same bar as Q3's
`startedAt` option.

```
BroadcasterSessionState = OfflineState
                      | StartingState
                      | LiveState(LiveBroadcast broadcast)
                      | EndingState
                      | BroadcastFailedState(BroadcastFailure reason)
```

Variant class names follow the codebase's existing convention for sealed state
hierarchies (`AuthState` → `SignedOutState`/`SigningInState`/…; `RecordingState` →
`IdleState`/`RecordingActiveState`/…). The five variant names above are this stage's
contribution; the sealed shape itself is fixed.

- `OfflineState`: initial state (`build()`) and the state after a complete
  `endBroadcast()`. No session resources exist in this state.
- `StartingState`: exists only between `goLive()` being accepted and the 9-step sequence
  in `business-logic-model.md` F-6.2 resolving (success → `LiveState`, failure →
  `BroadcastFailedState`). Transient; never restored across app restarts (no session
  survives a restart — a crashed broadcaster's stale live status is cleared by presence
  expiry, F-6.8).
- `LiveState(broadcast)`: carries the `LiveBroadcast`. Caption-activity and viewer
  changes while live are **in-place updates to the `LiveBroadcast` value inside the same
  `LiveState` variant** (a new `LiveState` with a copied `LiveBroadcast`), not variant
  transitions — the PBT-06 reference model treats those as state-preserving updates.
- `EndingState`: exists only during `endBroadcast()`'s sequence (F-6.6); always resolves
  to `OfflineState`.
- `BroadcastFailedState(reason)`: terminal result of a failed `goLive()`. All completed
  steps were unwound in reverse (Rule 2) — **no session resources exist in this state**,
  which is why it is a legitimate starting point for a retry `goLive()` and a
  sign-allowed state for the Rule 9 guard.

**State machine (PBT-06 reference transitions):**
`OfflineState --goLive--> StartingState --success--> LiveState --endBroadcast--> EndingState --done--> OfflineState`;
`BroadcastFailedState --goLive--> StartingState`. `goLive()` is accepted only from
`OfflineState`/`BroadcastFailedState` (Rule 1); `endBroadcast()` only from `LiveState`
(Rule 5); all other calls are no-ops.

**Phase 1's unrelated `BroadcastSessionState` (resolved, Q2):** `zip_broadcast` already
ships a *different* `BroadcastSessionState` sealed model
(`packages/zip_broadcast/lib/src/models/broadcast_session_state.dart`, unchanged by
this unit) — the local multi-engine *captioning* session machine
(`BroadcastIdleState`/`BroadcastActiveState`/`BroadcastPausedState`/
`BroadcastReconnectingState`/`BroadcastStoppedState`) used by Phase 1's
`BroadcastRecordingNotifier`. The rename above (this unit's class is now
`BroadcasterSessionState`) removes the collision entirely — no import alias or
use-site disambiguation is needed anywhere.

## LiveBroadcast (final class, fixed shape plus one approved addition — Q3)

```
LiveBroadcast {
  final BroadcastId broadcastId;
  final Uri url;
  final String sessionId;
  final String sessionName;
  final CaptionActivity captionActivity;   // banner when != active
  final List<ViewerConnectionInfo> viewers;
  final int maxViewers;
  final DateTime startedAt;                // added this stage, Q3 — not in the fixed shape
}
```

The first seven fields are fixed at Application Design; this unit designs behavior
around them, not their shape. `startedAt` is an **approved deviation** (Q3, option B)
— Application Design's fixed shape has only seven fields; this stage adds an eighth:

- `broadcastId`: from `BroadcastIdentityRepository.getOrCreateMine()` — permanent per
  signed-in account, so it (and `url`) is identical across all of a broadcaster's
  broadcasts (S-17 AC5: "the same broadcast ID and URL are used with a new
  session_id").
- `url`: `BroadcastLink.toUrl(broadcastId)` — the stable `https://zipcaptions.app/b/{id}`
  form (ADR-011). Invariant: always consistent with `broadcastId`; never computed by
  string concatenation elsewhere.
- `sessionId`: a fresh UUID v4 per `goLive()` (the `uuid` package, already a zip_core
  dependency; same mechanism as `peerId()`). New on every broadcast; never an account
  identifier.
- `sessionName`: the validated name from `BroadcastSettings` (Rule 7).
- `captionActivity`: seeded from the app's actual captioning state at registration
  (Rule 4 / Q4 — not the target's `inactive` default), then updated from
  `RemoteBroadcastTarget.activityChanges` (F-6.4). Drives the captions-inactive banner:
  banner visible ⟺ `LiveState` and `captionActivity != CaptionActivity.active`
  (FR-6.7).
- `viewers`: an exact mirror of `BroadcastTransport.viewers` — the set of
  **ack-confirmed** viewers (Unit 5 `business-rules.md` Rule 1); nothing in between
  (no "connecting" or "disconnected" entries — those rows in Proto-12 are not renderable
  from this data; Rule 11).
- `maxViewers`: `defaultBroadcastLimits.maxViewers` (Unit 5's named interim constant,
  50 — never a literal in this unit). "Broadcast full" banner ⟺
  `viewers.length == maxViewers` (derived in the UI, no new field).

- `startedAt`: set once, to `DateTime.now()`, at F2-9 (`business-logic-model.md`
  F-6.2 step 10) when the notifier constructs the initial `LiveBroadcast` and
  transitions to `LiveState` — not before (there is no meaningful "started" instant
  before the broadcast is actually live). Unchanged for the lifetime of the
  `LiveState`/in-place `LiveBroadcast` updates (F-6.4 copies it through untouched,
  same as every other non-viewer/non-activity field). A fresh value on every new
  `goLive()` (F-6.7) — never reused across sessions. Drives Proto-12's "Duration"
  stat card (`DateTime.now().difference(startedAt)`, computed in the UI — not stored).

## BroadcastFailure (enum, fixed)

```
BroadcastFailure { signedOut, signalingUnavailable, relayUnavailable, identityUnavailable, unknown }
```

Fixed at Application Design. The step→variant mapping for `goLive()`'s failure table is
`business-rules.md` Rule 2 (this stage's contribution — the enum itself is not).

## BroadcastSettingsNotifier (notifier, new this unit — zip_core)

- `@Riverpod(keepAlive: true)`, state `BroadcastSettings` (Application Design:
  "Loads and persists `BroadcastSettings`… Persisted per concern (Phase 1 settings
  pattern)").
- `build()`: loads both keys from `sharedPreferencesProvider` (the app-overridden,
  pre-initialized instance — same provider Unit 2's `BaseSettingsNotifier` descendants
  use), falling back to defaults (`''` / `false`).
- Updates persist immediately on write: `updateSessionName(String)` and
  `setAutoStartCaptioning(bool)` (or a single `update(BroadcastSettings)` — naming is
  an implementation detail; the contract is load-on-build, persist-on-update).
- Read by: `BroadcastSetupScreen` (two-way bound form) and `BroadcastSessionNotifier`
  (`goLive()` reads the current settings; it never writes them).

## BroadcastSessionNotifier (notifier, fixed shape — behavior designed in business-logic-model.md)

```
class BroadcastSessionNotifier /* keepAlive */ {
  BroadcasterSessionState build();   // Offline
  Future<void> goLive();
  Future<void> endBroadcast();
}
```

- `zip_core` (Application Design Q1:A), keepAlive so the session survives navigation.
- Dependencies (all existing providers, explicit calls per the project Riverpod
  convention — no reactive watchers triggering side effects): `authNotifierProvider`
  (sign-in check), `broadcastIdentityRepositoryProvider`, `signalingServiceProvider`,
  `iceServerProviderProvider`, `TransportSelector` (Unit 5), `defaultBroadcastLimits`
  (named const), `captionOutputTargetRegistryProvider`, and the new
  `captioningStarterProvider` (Q1).
- Owns, per live session (created in `goLive()`, disposed on every terminal path —
  `business-rules.md` Rule 5): the `StatusChannel` (opened for `publishLive`, held open
  for the broadcast's lifetime — it *is* the presence that FR-6.6's expiry relies on),
  the `ViewerAdmission(defaultBroadcastLimits)` instance, the `BroadcastTransport`
  instance (from `TransportSelector`), the `RemoteBroadcastTarget` instance, and its
  two stream subscriptions (`activityChanges`, `transport.viewers`).

## CaptioningStarter (new seam, Q1 — zip_core)

Application Design's F2 step 8 ("explicit call to the recording notifier's start") and
the coupling note ("couples to RecordingStateNotifier only through the optional
auto-start call") never specify *how* a `zip_core` notifier reaches the app's recording
notifier — `zip_broadcast`'s recording machinery is `BroadcastRecordingNotifier`
(a `zip_broadcast` class, unreachable from `zip_core` by dependency direction), while
`zip_core`'s own `RecordingStateNotifier` is the single-engine `zip_captions` one.
This stage introduces (Q1, answered A):

```
abstract interface class CaptioningStarter {
  CaptionActivity get currentActivity;  // derived from the app's recording state
  Future<void> start();                 // no-op unless currentActivity == inactive
}
```

- `currentActivity` mapping mirrors `RemoteBroadcastTarget._mapActivity` exactly
  (`active`/`paused`/`inactive`), so the banner seed (Rule 4) and the auto-start
  condition (F2 step 8: "only if autoStartCaptioning is on and recording is idle" =
  `currentActivity == inactive`) both read one source.
- Provider: `captioningStarterProvider` in `zip_core`, keepAlive. Default implementation
  wraps `RecordingStateNotifier` (zip_captions parity); **`zip_broadcast`'s `main.dart`
  overrides it** with an implementation backed by `BroadcastRecordingNotifier` (its
  `BroadcastSessionState` mapped as above; `start()` is already a guarded no-op unless
  idle). Precedent for the override: `authServiceProvider`/`supabaseClientProvider`
  (Unit 2).
- Used only by `BroadcastSessionNotifier` — it never writes captioning state, never
  stops/pauses/resumes captioning (those remain direct UI calls to
  `BroadcastRecordingNotifier`), and its failure modes are non-fatal to `goLive()`
  (Rule 3).

## Changes to Unit 5 components (flagged, not silent — Q4 and Q5, both answered A)

Both are **additive** (no fixed signature changes, no behavior changes to existing
methods); both resolve gaps where F2/F6 as fixed cannot be honored by Unit 5's shipped
code:

- **`RemoteBroadcastTarget.primeActivity(CaptionActivity activity)` (Q4)** — the
  shipped target defaults `currentActivity` to `inactive` until the first
  `SessionStateEvent` (Unit 5's documented simplification, fixed single-argument
  constructor). If captioning was *already running* before `goLive()`, no state-change
  event will ever fire, so the target would seed new viewers' join snapshots with
  `inactive` — contradicting its own fixed responsibility ("tracks the latest activity
  and sends it to each newly joined viewer as a snapshot") and Application Design's
  F2 step 6 ("created with its initial activity from the current recording state").
  `BroadcastSessionNotifier` calls `primeActivity` immediately after registration with
  `captioningStarter.currentActivity`. (Publishing a synthetic `SessionStateEvent` on
  the app bus was considered and rejected — `TranscriptWriterTarget` would treat it as
  a new session start and re-run `createSession`.)
- **`BroadcastTransport.sendBroadcastEnded()` (Q5)** — F6 step 1 assigns the
  `BroadcastEnded` *signaling* message to the end-broadcast sequence, but the fixed
  `BroadcastTransport` interface (Unit 5) exposes no signaling-message send, and the
  per-viewer `SessionSignalingChannel`s are owned by the transport. The wire
  `CaptionWireMessage.Ended` (sent via `sendToAll`) covers viewers on healthy data
  channels; the signaling message covers the niche of a viewer mid-restart whose data
  channel is briefly down (otherwise it learns the broadcast ended only when its
  reconnect window closes, as `notBroadcasting`). Q5 answered A: add this additive
  method.
