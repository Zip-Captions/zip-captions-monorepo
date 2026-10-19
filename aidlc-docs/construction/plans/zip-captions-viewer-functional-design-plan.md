# Functional Design Plan: Zip Captions Viewer (Unit 7)

**Unit**: zip-captions-viewer
**Stories**: S-19
**Packages**: zip_core (viewer orchestration), zip_captions (screens, routes, web platform)
**Branch**: `feature/zip-captions-viewer` (off `develop`)
**Dependencies**: Unit 5 (merged, PR #31), Proto-14 and Proto-15 (approved) — all satisfied

## What's Already Decided (from phase2-component-methods.md / phase2-services.md / phase2-components.md)

Not open for reinterpretation here — Functional Design elaborates these, it doesn't
re-decide them:
- `ViewerSessionNotifier` (`build()` / `join(String input)` / `leave()` /
  `CaptionBus? get viewerBus`), the sealed `ViewerSessionState` (10 fixed variants:
  `Idle | Resolving | Connecting | Live(captionActivity, connectionType) |
  Reconnecting | NotBroadcasting | Ended | Full | CannotConnect(ConnectFailure) |
  InvalidInput`), `ReconnectPolicy.nextDelay(int attempt, Duration elapsed)` —
  fixed per `phase2-component-methods.md` §6.
- The flows: F4 (viewer join), F5 (viewer reconnection), F6 (end broadcast — viewer
  side), F7 (broadcaster disappears) from `phase2-services.md`.
- `JoinBroadcastScreen`, `BroadcastViewerScreen` and the go_router routes
  `/join` and `/b/:broadcastId` — fixed per `phase2-components.md` §8 and
  `phase2-component-methods.md` §8.
- The viewer session owns a **viewer-scoped** `CaptionBus` +
  `CaptionOutputTargetRegistry` + `OnScreenCaptionTarget`, created per viewing
  session and disposed on leave — viewing never mixes with self-captioning
  (fixed, `phase2-components.md` §6).

## Shipped Contracts This Unit Consumes (read against the actual code, not the docs)

- `BroadcastLink.parseInput` (Unit 3) — `null` on invalid, never throws; the
  join-screen validation boundary (FR-7.1).
- `BroadcastResolver` / `BroadcastResolution` (Unit 3) — 5 variants including
  `resolutionFailed` (presence-read failure, kept distinct from `offline` on
  purpose).
- `SignalingService` (Unit 3.1 final shape) — `submitJoinRequest(broadcastId,
  peerId)`, `sessionChannel(sessionId, peerId)`, status channel; no lobby, no
  `SignalingRole` anywhere.
- `ViewerTransport` / `WebRtcViewerTransport` (Unit 5) — `connect(ViewerTransportContext)`
  / `restart()` / `disconnect()` / `messages` / `status`. **Unit 5 Rule 2**: the
  transport's own retry loop is indefinite (1s/2s/4s/8s/8s…), `Interrupted` never
  times out on its own, and `ConnectionStatus.Failed` is reachable **only** via
  explicit `disconnect()` or the broadcast ending.
- `RemoteCaptionReceiver` (Unit 5) — decodes transport messages into the viewer
  bus; `activity` and `ended` streams for the session notifier.
- `ConnectionStatus` (Unit 5, shipped sealed): `Connecting | Connected(type) |
  Interrupted | Failed(ConnectFailure)`.
- `ConnectFailure` (Unit 5, shipped sealed): `BroadcastFull | IceFailed |
  SignalingRejected | Timeout` — **transport-scoped, 4 variants** (see Brownfield
  Finding 2: this is *not* the enum Application Design's fixed
  `CannotConnect(ConnectFailure)` references).
- `BroadcastLimits` / `const defaultBroadcastLimits` (Unit 5): `maxViewers=50`,
  `presenceTimeout=60s`, `reconnectWindow=120s` (Spike 2.1 interim values,
  revisable constant).
- Phase 1: `CaptionBus`, `OnScreenCaptionTarget`, `CaptionDisplayWidget`,
  `displaySettingsProvider`, `supabaseClientProvider` (already initialized in
  `zip_captions`' `main.dart` per Unit 2).
- Approved prototypes: Proto-14 (join screen: input, invalid-input error, join
  button) and Proto-15 (8 viewer states, each icon + text, not color alone; two
  distinct "cannot connect" copy variants — generic and reconnect-timeout;
  `notBroadcasting` copy promises "This page will connect automatically once it
  goes live"; live-with-paused is an inline notice on the caption view, not a
  separate full-screen state).

## Brownfield Findings (discovered while planning this stage)

1. **No web platform exists in `zip_captions`** — no `packages/zip_captions/web/`
   directory and no web job in `build-verify.yml` (verified by listing the package
   and reading the workflow). S-19 nonetheless carries web-specific acceptance
   criteria (`/b/{broadcast_id}` route, SECURITY-04 headers) and the unit
   definition names "path URL strategy and security headers for the web route."
   → Q9.
2. **`ConnectFailure` mismatch**: Application Design's fixed
   `CannotConnect(ConnectFailure)` references `enum ConnectFailure { noNetworkPath,
   relayUnavailable, signalingUnavailable, rateLimited, unknown }`, but Unit 5
   shipped a *different*, transport-scoped sealed class with 4 variants and **no
   way to express `rateLimited`** — yet F4 step 3 requires
   `cannotConnect(rateLimited)`. The fixed state shape is not expressible as
   shipped. → Q1/Q2.
3. **F5 vs Unit 5 Rule 2**: F5 says "when the window is exceeded … otherwise
   `cannotConnect(reason)`", but the shipped transport retries indefinitely and
   only produces `Failed` via `disconnect()`/broadcast-end. The window must be
   owned by the session layer. → Q3.
4. **Proto-15's `notBroadcasting` copy promises auto-connect** on offline→live,
   but F4–F7 only cover viewers already in `reconnecting`. → Q5.
5. **SECURITY-04 has no enforcement point today**: no web deploy target is chosen
   (roadmap defers domain/hosting to Phase 5) and no headers configuration exists
   anywhere in the repo. → Q9.

## Plan Approval

Answers recorded 2026-10-15 (Q1 A, Q2 A, Q3 A, Q4 A, Q5 A, Q6 A, Q7 A, Q8 C —
option A plus a confirm dialog when leaving an active session, Q9 B — web
deferred to Phase 5 with the five guardrails, Q10 A); plan approved for
execution the same day ("done, proceed").

## Planned Functional Design Artifacts

- [x] `aidlc-docs/construction/zip-captions-viewer/functional-design/domain-entities.md`
- [x] `aidlc-docs/construction/zip-captions-viewer/functional-design/business-logic-model.md`
- [x] `aidlc-docs/construction/zip-captions-viewer/functional-design/business-rules.md`
- [x] `aidlc-docs/construction/zip-captions-viewer/functional-design/frontend-components.md`
      (unit includes UI — per the stage rule: the 8-state rendering matrix,
      per-state copy from Proto-14/15, screen-reader announcement spec (NFR-5.2),
      join-screen form handling)
- [x] `aidlc-docs/construction/zip-captions-viewer/functional-design/handoff-summary.md`
      (project stage-handoff override)

The artifacts will include a **Testable Properties** section per PBT-01:
PBT-02 (URL/ID parse round-trip through `BroadcastLink.parseInput`) and PBT-06
(stateful property test of the `ViewerSessionState` machine against a reference
model — the story's own PBT rows).

## Open Questions

All ten are closed. Each is kept below with the question, the options as
presented, and the recorded answer; the "Resolution" lines are what this
stage actually carries forward (some answers needed elaboration against the
shipped code — see "Verification Pass" after Q10).

### Q1: How does `CannotConnect` carry resolution-level reasons?
Application Design's fixed `CannotConnect(ConnectFailure)` assumes a
`ConnectFailure` that includes `rateLimited`; the shipped Unit 5 `ConnectFailure`
is transport-scoped (4 variants, no `rateLimited`), yet F4 step 3 requires
`cannotConnect(rateLimited)` for a Kong-rejected resolution.

- A. Additively extend the shipped sealed `ConnectFailure` with the missing
      resolution-level variant(s) — a second additive change to Unit 5's shipped
      components (precedent: Unit 6's `primeActivity`/`sendBroadcastEnded`); the
      existing four variants keep their exact behavior, and Unit 5 Rule 3's
      "exhaustive transport mapping" is restated to cover resolution-origin
      failures as well **(recommended)**
- B. Leave `ConnectFailure` transport-only; `ViewerSessionState.CannotConnect`
      carries a new, wider sealed reason type (deviation from the fixed state
      shape's field type)
- C. Other (write in)

[Answer]: A

### Q2: How is `BroadcastResolution.resolutionFailed` rendered? (Backlog item, 2026-09-30)
Unit 3 deliberately kept `resolutionFailed` distinct from `offline` so a transient
presence-read glitch is never misreported as the broadcast having ended. The fixed
`ViewerSessionState` list has no rendering for it, and Proto-15 has no distinct
state for it either.

- A. Map it to `CannotConnect` with its own reason variant and its own copy
      ("couldn't check whether this broadcast is live right now — try again"),
      distinct from the "link may be incorrect" copy, with a retry action
      **(recommended — honors the variant's own design rationale and FR-7.4's
      "specific reason")**
- B. Fold it into the generic cannot-connect copy (one fewer variant; weaker
      "specific reason")
- C. Add an 11th `ViewerSessionState` variant for it (deviation from the fixed
      10-variant list)
- D. Other (write in)

[Answer]: A

### Q3: Reconnect window exceeded while the broadcast is still live
F5 says the viewer checks the status channel when the window is exceeded: offline
→ `notBroadcasting`, otherwise `cannotConnect(reason)`. Unit 5 Rule 2 (shipped)
says the transport retries indefinitely and only produces `Failed` via
`disconnect()` or the broadcast ending — so the window must be enforced by the
session layer, and Proto-15's "reconnect timeout" cannot-connect copy is the
approved rendering of exactly this case.

- A. The notifier owns the window (`ReconnectPolicy` +
      `BroadcastLimits.reconnectWindow`): on expiry it checks the status channel —
      offline → `notBroadcasting` (with the Q5 watch kept), still live → the
      notifier calls `transport.disconnect()` (Rule 2's own terminal path) →
      `cannotConnect(IceFailed)` with Proto-15's reconnect-timeout copy and a
      "Try again" action. No change to the shipped transport **(recommended)**
- B. The transport owns the window (modify Unit 5's shipped retry loop) — breaks
      the don't-reopen-a-merged-unit precedent
- C. Never give up: stay in `reconnecting` indefinitely while the broadcast is
      confirmed live (deviates from F5 and the approved prototype)
- D. Other (write in)

[Answer]: A

### Q4: "Try again" in a terminal cannot-connect state — full rejoin or transport restart?

- A. Full rejoin: `join(broadcastId)` again from the top (re-resolves; also
      handles the session having changed — e.g. the broadcaster ended and went
      live again under a new session id) **(recommended)**
- B. `transport.restart()` only (cheaper; breaks if the session id changed)
- C. Both: try `restart()` first, fall back to full rejoin if it fails
- D. Other (write in)

[Answer]: A

### Q5: `notBroadcasting` auto-connect (Proto-15's approved copy promises it)
Proto-15's not-broadcasting state says "This page will connect automatically once
it goes live." That requires the viewer to keep a `StatusChannel.watch()` alive in
`notBroadcasting` and join the new session on a live event — a behavior F4–F7
don't specify (F7 only covers viewers already in `reconnecting`).

- A. Yes — keep the status watch alive in `notBroadcasting`; on a live event,
      auto-join the new session; the watch stays until `leave()` or a terminal
      state **(recommended — matches the approved prototype copy)**
- B. Yes, but bound the watch with a TTL (e.g. 10 minutes), after which the state
      stays put as static "not broadcasting"
- C. No auto-connect; change the copy to "check back later" (requires
      re-approving the already-approved prototype copy)
- D. Other (write in)

[Answer]: A

### Q6: Route placement and the join entry point

- A. `/join` lives **inside** the app shell (entry points: a join affordance on
      the home screen and the nav drawer); `/b/:broadcastId` lives **outside**
      the shell (full-screen immersive viewer with its own leave control). A valid
      submit on `/join` navigates to `/b/{id}` — one viewer surface serves both
      the form flow and deep links **(recommended)**
- B. Both routes outside the shell
- C. Both routes inside the shell (viewer renders under the bottom nav)
- D. Other (write in)

[Answer]: A

### Q7: Notifier lifecycle — one global viewing session or route-scoped?

- A. One app-lifetime `ViewerSessionNotifier` (riverpod): at most one active
      viewing session; `join(different input)` implicitly `leave()`s first;
      `leave()` is idempotent; the session survives navigation (re-entering the
      viewer shows the current state) **(recommended — matches the fixed shape,
      which is a single `join(String input)`/`leave()` with no session key)**
- B. Route-scoped notifier (autoDispose; one per mounted viewer screen — leaving
      the screen disposes the session)
- C. Other (write in)

[Answer]:A

### Q8: Back / leave semantics on the viewer screen

- A. A visible "Leave" control in every viewer state; the platform back
      gesture/button also calls `leave()` (releasing the connection) and returns
      to the app **(recommended)**
- B. Back only navigates; the session keeps running in the background and is only
      released by the explicit Leave control
- C. Other (write in)

[Answer]: C - let's use option A but include a confirm dialog on leaving an active broadcast session to prevent users accidentally disconneting

### Q9: Web platform enablement (Brownfield Finding 1)
`zip_captions` has no `web/` directory and CI builds no web target, but S-19's
acceptance criteria include the `/b/{broadcast_id}` web route and SECURITY-04
headers, and the unit definition names "path URL strategy and security headers
for the web route."

- A. Enable web in this unit: `flutter create --platforms=web` scaffold, path URL
      strategy, a host-agnostic security-headers configuration artifact plus a
      local static-server verification test, and a `flutter build web` job added
      to `build-verify.yml` **(recommended — the web ACs are otherwise
      unsatisfiable; final production host configuration stays a deployment/Unit 9
      item)**
- B. Defer web to Unit 9: this unit ships native platforms only, with a documented
      AC gap
- C. Other (write in)

[Answer]: B (web scaffold, CI job, security headers and hosting deferred to Phase 5; Unit 7 stays native-only), with these guardrails:
1. Viewer code is platform-neutral — no `dart:io` or native-only imports in the viewer path.
2. `/join` and `/b/:broadcastId` stay plain go_router paths (path URL strategy is a later one-line switch).
3. No hardcoded domain data anywhere in the codebase; project-global constant values come from environment variables. `BroadcastLink.baseUrl` (currently hardcoded to `https://zipcaptions.app/b/`, which is v1's apex) becomes env-driven via `--dart-define`, following the existing `supabaseUrl` / `iceServerUrls` pattern. The initial web release targets the `v2` subdomain of `zipcaptions.app`, supplied by configuration rather than in code. `parseInput` stays host-agnostic. Other hardcoded domain constants (e.g. the model-catalog CDN URL in `catalog_constants.dart`) are out of Unit 7's scope but get logged as a backlog item.
4. S-19's two web acceptance criteria (the `/b/` route opening in a browser; SECURITY-04 headers) are recorded as deferred to Phase 5 in `aidlc-state.md`. The plan's "domain and hosting deferred to Phase 5" wording is corrected: the domain is decided, only hosting is deferred (V1 currently runs on Azure; provider for V2 is open).
5. Until web ships, the shareable link doesn't resolve. Handling that in the broadcaster UI (e.g. make the bare broadcast ID the primary shared item during the alpha) is a Unit 6 UI follow-up, tracked as a backlog item.

### Q10: Pop-out live captions / floating window (Backlog item, 2026-09-25)
Raised during Proto-15 review: a small floating/PiP-style caption window in the
viewer. Not in S-19's acceptance criteria; a native implementation would need a
new dependency (FR-9.5 approval + supply-chain justification), and web and desktop
need different mechanisms.

- A. Defer — keep on the backlog, out of Unit 7 scope **(recommended)**
- B. Scope it into Unit 7 for native platforms (new dependency approved now)
- C. Scope it into Unit 7 for web only (browser Document Picture-in-Picture, no
      new dependency)
- D. Other (write in)

[Answer]: A

## Already-Resolved Backlog Items (not open questions — decided in the draft, with reasoning)

- **"Joining..." progress copy during the join-request resend window** (raised
  2026-10-05, Unit 3.1 NFR Design Q1): resolved as **static** — Proto-15's
  approved connecting state ("Connecting…" + "Joining {sessionName}") already
  satisfies the request for progress copy distinct from a bare spinner, and the
  prototype shows no copy variation across the 2s/5s/10s resends. Making the copy
  vary would require an additive change to Unit 5's shipped `ViewerTransport`
  (retry visibility) for no product value; the resends stay internal. If the user
  wants the "Still joining…" variation after all, it can be picked up in a later
  UI pass without touching the transport.

## Verification Pass (2026-10-18) — artifacts checked against shipped code

The Functional Design artifacts were written 2026-10-15 and never committed.
Before recording approval, every load-bearing claim in them was checked against
the actual `zip_core`/`zip_captions` source. What was confirmed, and the three
corrections that came out of it:

**Confirmed against source** (no change needed):
- `BroadcastResolution` has exactly the five shipped variants the model assumes
  (`broadcast_resolution.dart`), including `resolutionFailed` documented as
  "callers may retry … not a stable result" — the basis for Q2's manual-retry
  rendering and the new Rule 14.
- `ConnectFailure` is the four-variant sealed class described in
  `domain-entities.md`, with no `rateLimited`, confirming Q1's premise.
- `ConnectionStatus` is `Connecting | Connected(type) | Interrupted | Failed`
  as described; `TransportSelector.viewerTransport()` returns the concrete
  `WebRtcViewerTransport`, confirming the need for
  `viewerTransportFactoryProvider` (same reasoning as Unit 6).
- `RemoteCaptionReceiver` exposes `activity`/`ended`/`dispose` exactly as
  F-7.3/F-7.5 use them; `StatusChannel` exposes `watch()`/`close()` as Rule 4
  requires; `ViewerTransportContext(sessionId, broadcastId, signalingService,
  iceServers)` matches F-7.2 step 5; `iceServerProviderProvider` is the real
  provider name.
- `OnScreenCaptionTarget` takes `repository` nullable — the `repository: null`
  no-persistence decision (Rule 7) is expressible without changing Phase 1.
- `defaultBroadcastLimits` is `50/60s/120s`; `WebRtcViewerTransport` retries
  indefinitely and emits `Failed` only via `disconnect()`/broadcast end, so
  Rule 3's division of labor is the only workable split.
- `BroadcastLink.baseUrl` is indeed a hardcoded `https://zipcaptions.app/b/`
  and `parseInput` is host-agnostic — Q9 guardrail 3 is a real code change,
  not already satisfied.
- `zc_router.dart` is a single `ShellRoute` with `/`, `/recording`,
  `/settings`, `/history(/:sessionId)` — the Q6 route placement (one route
  inside, one outside) is a clean addition.

**Corrections applied (2026-10-18, in place — no design decision changed):**
1. **`connect()` throw mapping was under-specified.** F-7.2 step 5 said
   "`CannotConnectState(Unknown-shape failure)`" and then named a specific
   variant; the text contradicted itself. It now names
   `CannotConnectState(IceFailed)` with the generic copy, and Rule 5's table
   lists "a raw throw out of `transport.connect()`" as an `IceFailed` origin.
   (Relevant because the shipped viewer transport awaits
   `sessionChannel(...).open()` inside `connect()`, so a channel-open failure
   genuinely surfaces as a throw rather than a status event.)
2. **Window-expiry with no status emission was unhandled.** F-7.4 step 4 read
   the status watch's "last emission", but `SupabaseStatusChannel.watch()`
   waits for its first presence sync and may not have produced one within the
   120s window. Previously the only stated meanings were "offline" and
   "live (or never saw offline)" — the latter would have rendered the
   reconnect-timeout copy for a viewer whose liveness was never known. Added a
   third branch: `CannotConnect(ResolutionFailed)` with Q2's copy, applied to
   `business-logic-model.md` (F-7.4 step 4 and the PBT-06 transition table)
   and Rule 5's table.
3. **Resource invariant #1 contradicted itself.** It claimed
   `_ViewerResources` is null in `Ended`/`Full`/`CannotConnect` and then, in
   the same sentence, that "non-null holds for them too". Settled on:
   non-null in every state except `Idle` and `InvalidInput`; the per-state
   *sub-resource* set is what varies, which also matches F-7.5 step 3 (the
   caption buffer survives until `leave()`).

**New rule added as a result:** Rule 14 — `join()` owns no retry loop;
re-resolution happens only on user action ("Try again") or via the status
watch. States the consequence of Q2's manual-retry rendering explicitly so
Code Generation does not invent an auto-retry.

**Q9 guardrail 3 remains open work for Code Generation, not Functional
Design:** `BroadcastLink.baseUrl` → `broadcastBaseUrl` via
`String.fromEnvironment('BROADCAST_BASE_URL', ...)` following the shipped
`supabase_config.dart` / `turn_config.dart` pattern. Recorded as such in the
handoff summary and as a Code Generation step; no FD artifact changes.

**Approval re-recorded 2026-10-18:** Q1–Q10 answers stand unchanged; the
three corrections above are completeness fixes inside the approved answers,
not new choices. Stage approved for handoff to NFR Requirements.
