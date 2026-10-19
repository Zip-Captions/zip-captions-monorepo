# Domain Entities — Zip Captions Viewer (Unit 7)

## ViewerSessionState (sealed, 10 fixed variants — Application Design)

```
ViewerSessionState = IdleState
                   | ResolvingState
                   | ConnectingState
                   | LiveViewState(CaptionActivity captionActivity, ConnectionType connectionType)
                   | ReconnectingState
                   | NotBroadcastingState
                   | EndedState
                   | FullState
                   | CannotConnectState(ConnectFailure reason)
                   | InvalidInputState
```

The sealed variant list is fixed (`phase2-component-methods.md` §6). Variant
**class** names are this stage's contribution, following the codebase's sealed
state convention (`AuthState` → `SignedOutState`/…; `RecordingState` →
`IdleState`/…). Two naming decisions:

- **`LiveViewState` (not `LiveState`)**: Unit 6's shipped
  `BroadcasterSessionState` already owns a `LiveState` variant in the same
  package. The viewer's live variant is named `LiveViewState` to avoid the
  collision — purely mechanical, no field/variant/behavior change to the fixed
  shape (same bar as Unit 6's Q2 `BroadcasterSessionState` rename).
- **`InvalidInputState` carries no data**: the rejected input string is
  untrusted and is never echoed into state or logs (SECURITY-05 / NFR-3.3).
  The join screen's own inline validation renders the specific message from
  the *screen's own* input buffer, not from this state; the state exists for
  the deep-link path where `/b/:broadcastId`'s path parameter fails
  `BroadcastLink.parseInput`.

Variant meanings:

- `IdleState`: `build()`'s initial state and the state after `leave()`. No
  session resources exist in this state.
- `ResolvingState`: between `join()` accepting a parsed input and
  `BroadcastResolver.resolve()` returning. Transient.
- `ConnectingState`: resolution returned `live`; the join handshake
  (join request → accept → SDP/ICE → data channel) is in flight.
- `LiveViewState(captionActivity, connectionType)`: connected. Both fields are
  **in-place updates** inside the same variant (new value, same state class)
  as the broadcaster's activity changes or the connection re-routes — the
  same pattern as Unit 6's `LiveBroadcast` in-place updates.
  `captionActivity` is the broadcaster's captioning activity as reported over
  the wire (`active`/`paused`/`inactive`); the "captions paused by the
  broadcaster" rendering is `LiveViewState` with `captionActivity != active`
  (Proto-15's "3. Captions paused" is an inline notice on the caption view,
  not a separate state — matching the fixed shape, which has no paused
  variant).
- `ReconnectingState`: the transport reports `Interrupted`; the data channel
  is down and reconnection is underway (transport-owned retry cadence,
  `business-rules.md` Rule 3). The last received captions remain visible.
- `NotBroadcastingState`: the broadcast's existence is confirmed but no
  broadcaster is live. Carries the Q5 auto-join promise: the status watch
  stays open and a live event starts a join automatically
  (`business-logic-model.md` F-7.8).
- `EndedState`: the broadcaster ended the broadcast (`broadcastEnded` wire
  message received). Terminal with respect to auto-behavior
  (`business-rules.md` Rule 6).
- `FullState`: the broadcaster refused the join as full
  (`JoinRejected(full)`). Terminal with respect to auto-behavior — the
  approved Proto-15 copy says "Try again later — someone may disconnect",
  i.e. manual retry only, never an auto-retry loop hammering the
  broadcaster.
- `CannotConnectState(reason)`: "cannot connect, with a specific reason"
  (FR-7.4). `reason` is the extended `ConnectFailure` below; each variant
  maps to exactly one rendering and retry affordance
  (`business-rules.md` Rule 5).
- `InvalidInputState`: deep-link input that failed `BroadcastLink.parseInput`.
  No network request was made (S-19 AC).

**`sessionName` is not a field of any state variant** (the fixed shapes carry
only the fields above). The notifier exposes `String? get sessionName` —
set on a successful `live` resolution (including auto-joins), retained while
the session is active or in a terminal state of the *same* broadcast (the
`NotBroadcasting`/`Ended`/`Connecting` copy all need it), cleared on
`leave()`. This keeps the fixed state shape untouched while every screen that
needs the name (connecting, not-broadcasting, live, ended) can render it.

## ConnectFailure (shipped sealed class — extended additively, Q1 = A)

Unit 5 shipped `ConnectFailure` as a transport-scoped sealed class with four
variants. Application Design's fixed `CannotConnect(ConnectFailure)` assumes a
superset that includes resolution-level reasons (its enum listed
`rateLimited`), and `phase2-services.md` F4 step 3 requires
`cannotConnect(rateLimited)`. Per the approved Q1 answer, the shipped sealed
class is extended **additively** with three new final classes (second
additive-change precedent on Unit 5's shipped components, after Unit 6's
`primeActivity`/`sendBroadcastEnded`):

```
ConnectFailure = BroadcastFull      // shipped, unchanged
               | IceFailed          // shipped, unchanged
               | SignalingRejected  // shipped, unchanged
               | Timeout            // shipped, unchanged
               | RateLimited        // NEW (Q1) — Kong rejected resolve_broadcast_id
               | ResolutionFailed   // NEW (Q1/Q2) — resolution/presence-read errored
               | NotFound           // NEW (Q1) — the code doesn't exist
```

- The four shipped variants keep their exact behavior and their Unit 5 Rule 3
  transport mapping (`business-rules.md` Rule 5 restates that mapping to
  cover the three new resolution-origin variants as well).
- `BroadcastFull` is a `ConnectFailure` variant (transport reports it via
  `Failed(BroadcastFull)`), but the session layer always renders it as the
  dedicated `FullState`, never inside `CannotConnectState` — a full
  broadcast is a distinct FR-7.4 state with its own copy and (deliberately
  absent) auto-retry.

## ReconnectPolicy (service, fixed shape)

```
class ReconnectPolicy {
  Duration? nextDelay(int attempt, Duration elapsed); // null = window exceeded
}
```

Fixed signature (`phase2-component-methods.md` §6). Concretization:

- **The policy is a window policy, not a retry scheduler.** Unit 5's shipped
  `WebRtcViewerTransport` already owns the retry cadence (Rule 2: 1s/2s/4s/8s/
  8s…, `Interrupted` indefinitely) and the approved Q3 = A answer keeps the
  shipped transport unchanged. The session layer's only job is to decide when
  to *give up*: `nextDelay(attempt, elapsed)` returns
  `reconnectWindow - elapsed` while positive and `null` once
  `elapsed >= reconnectWindow` (window =
  `BroadcastLimits.reconnectWindow`, the Spike 2.1 interim 120s shipped as
  `defaultBroadcastLimits`).
- `attempt` is retained in the signature because the shape is fixed; the
  current design uses a single window deadline per interruption, so the
  parameter is not consulted by the window logic (documented, not a TODO —
  if a future transport defers its internal retries to this policy, the
  attempt-based schedule is where it belongs).
- The notifier drives this with **one plain `Timer` per interruption**
  (started on entry to `ReconnectingState`, cancelled on `Connected` /
  `leave()` / any terminal transition), tested with `fakeAsync()` per the
  Unit 5/Unit 6 precedent (`supabase_auth_service.dart`,
  `BroadcastSessionNotifier`).
- Note on F5: `phase2-services.md` F5 step 2 says "ReconnectPolicy schedules
  `restart()`". That text predates Unit 5's shipped transport, whose retry
  loop already runs `restart()` internally. Having the session layer *also*
  schedule `restart()` calls would race the transport's own loop (two
  concurrent re-signal attempts). The observable behavior F5 specifies —
  automatic rejoin without user action, status check when the window is
  exceeded — is fully preserved; only the mechanism differs, in favor of the
  shipped component. `business-logic-model.md` F-7.4 restates the flow.

## ViewerSessionNotifier (notifier, keepAlive — Q7 = A)

```
@Riverpod(keepAlive: true)
class ViewerSessionNotifier extends _$ViewerSessionNotifier {
  ViewerSessionState build();      // IdleState
  Future<void> join(String input);
  Future<void> leave();            // idempotent
  CaptionBus? get viewerBus;       // fixed shape
  OnScreenCaptionTarget? get viewerCaptionTarget;  // added (see below)
  String? get sessionName;                  // added (see above)
  BroadcastId? get currentBroadcastId;      // added (see below)
}
```

- **One app-lifetime notifier** (Q7 = A): at most one active viewing session.
  `join(different input)` implicitly `leave()`s first; `leave()` is
  idempotent from any state. The session survives navigation — re-entering
  the viewer route shows the current state (Q7), and the route builder
  triggers `join(input)` only when the notifier has no session for that
  broadcast (`currentBroadcastId` is what makes that check possible; added
  getter, same elaboration bar as the others).
- **Getters beyond the fixed shape**: the fixed shape exposes only
  `viewerBus`. The screen additionally needs the session-scoped
  `OnScreenCaptionTarget` (to subscribe to caption entries — Phase 1's
  pattern; the screen never builds entries from the raw bus) and
  `currentBroadcastId`/`sessionName` (route-reentry and copy). Three added
  read-only getters, no fixed field/variant/behavior change.
- **`_ViewerResources` private holder** (mirrors Unit 6's `SessionResources`
  and its `disposeAll(Logger)` discipline): holds `broadcastId`, `sessionId`,
  `transport`, `RemoteCaptionReceiver`, the viewer-scoped `CaptionBus` +
  `CaptionOutputTargetRegistry` + `OnScreenCaptionTarget`, the status-channel
  watch subscription, and the reconnect-window `Timer`. Invariant:
  `_ViewerResources` is non-null in every state except `IdleState` and
  `InvalidInputState`, and null in both — directly checkable in tests, the
  same invariant Unit 6 established for the broadcaster side.
- **Viewer-scoped caption pipeline** (fixed, Application Design): a *new*
  `CaptionBus` + *new* `CaptionOutputTargetRegistry` + a *new*
  `OnScreenCaptionTarget` per viewing session, disposed on `leave()` —
  viewing never mixes with the app's own captioning pipeline (Rule 7).
  `OnScreenCaptionTarget` is constructed with **`repository: null`**: remote
  captions are never persisted to the transcript store (the viewer is
  anonymous; there is no device-auth-gated transcript save path here either,
  and NFR-3.3 bars caption content from logs/telemetry). No scrollback for
  the viewer — the in-memory buffer only.

## New provider: viewerTransportFactoryProvider

Unit 6 established `broadcastTransportFactoryProvider`
(`BroadcastTransport Function()`) because `TransportSelector.broadcastTransport()`
returns the concrete `WebRtcBroadcastTransport`, which a test fake could
never substitute. The viewer side needs the same seam:

```
@Riverpod()
class ViewerTransportFactory extends _$ViewerTransportFactory {
  ViewerTransport build() => const TransportSelector().viewerTransport();
}
```

Overridden in tests with a fake `ViewerTransport` (NFR-7.3). The
`ViewerTransportContext` it receives is built by the notifier from the
resolved `sessionId`/`broadcastId`, `signalingServiceProvider`, and
`iceServerProviderProvider.iceServersFor(sessionId)` — the same
anonymous-accessible TURN-credential path the broadcaster uses (Unit 4).

## BroadcastLink.baseUrl (existing shipped utility — now build-time-configured, Q9 guardrail 3)

Unit 3 shipped `BroadcastLink.baseUrl` as a hardcoded
`'https://zipcaptions.app/b/'` (v1's apex). Per the approved Q9 = B
guardrails: no hardcoded domain data in the viewer path; project-global
constant values come from environment variables; the initial web release
targets the `v2` subdomain supplied by configuration. Following the existing
`supabaseUrl`/`iceServerUrls` pattern exactly:

```
const broadcastBaseUrl = String.fromEnvironment(
  'BROADCAST_BASE_URL',
  defaultValue: 'https://zipcaptions.app/b/',
);
```

- `BroadcastLink.toUrl` and any URL *rendering* (none in the viewer; the
  broadcaster's setup screen in `zip_broadcast` reads the same constant) use
  `broadcastBaseUrl`.
- `BroadcastLink.parseInput` is **unchanged and stays host-agnostic** — it
  takes the last non-empty path segment of whatever URL is pasted, so a v2-
  subdomain URL parses identically to a v1-apex or bare ID.
- The `defaultValue` keeps current local-dev and v1 behavior; release builds
  supply the v2 subdomain via `--dart-define` (configuration, not code — the
  v2 host name itself appears nowhere in source).
- Other hardcoded domain constants elsewhere in the codebase (e.g. the model-
  catalog CDN URL in `catalog_constants.dart`) are **out of Unit 7's scope**
  and are logged as a Backlog item per the Q9 answer.

## Zip Captions app-side entities (UI + routing, Q6 = A)

- **`JoinBroadcastScreen`** (new, `zip_captions`): ID-or-URL entry and
  validation (Proto-14). A pure form — it holds no session state; a valid
  submit navigates to `/b/{id}` and the viewer screen owns everything after
  that. Entry points: a "Join a broadcast" affordance on the home screen
  plus a nav-drawer item (mobile drawer; the desktop nav rail gains no
  destination — the home-screen affordance is the desktop entry point).
- **`BroadcastViewerScreen(input)`** (new, `zip_captions`): full-screen,
  **outside** the app shell (no bottom nav / nav rail / drawer chrome —
  viewing is immersive; the screen provides its own Leave control and back
  handling, Q8). Renders the `ViewerSessionState` matrix defined in
  `frontend-components.md`.
- **Router** (modified `zc_router.dart`): `/join` added inside the existing
  `ShellRoute`; `/b/:broadcastId` added as a top-level route **outside** the
  shell. Both are plain go_router paths (Q9 guardrail 2 — the path URL
  strategy for web is a later one-line switch, not part of this unit).
  **Platform-neutrality** (Q9 guardrail 1): no `dart:io` or platform-only
  imports anywhere in the viewer path (notifier, screens, providers).
