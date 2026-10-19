# Business Rules — Zip Captions Viewer (Unit 7)

**Rule 1 — `join()` is idempotent per broadcast, and an invalid input never
tears down an active session.**
`join(input)` for the broadcast currently held (any non-terminal state:
`Resolving`, `Connecting`, `LiveView`, `Reconnecting`, `NotBroadcasting`) is
a no-op. `join()` for a *different* parsed ID first `await leave()`s, then
proceeds (Q7). `join(invalid input)` with an active session is a no-op (with
a log) — the session keeps running; without one it sets `InvalidInputState`.
`leave()` from any state is safe to repeat (idempotent — the PBT-04 row the
story map inherits from `phase2-services.md`'s cross-cutting
"idempotency" pattern).

**Rule 2 — No network before parse validity.**
`BroadcastLink.parseInput` (shipped, Unit 3) is the single boundary between
untrusted input and any network action: a `null` result short-circuits
`join()` before `BroadcastResolver`, `SignalingService`,
`IceServerProvider`, or the transport are touched (S-19 AC "no network
request is made"; SECURITY-05). The join screen performs the same check
locally before navigating, so the form path never reaches `join()` with
invalid input at all (F-7.1).

**Rule 3 — The transport owns the retry cadence; the notifier owns the
give-up window.**
During `ReconnectingState`, `WebRtcViewerTransport`'s shipped internal
backoff (Unit 5 Rule 2) performs all `restart()` attempts; the notifier
makes none (double-driving would race the loop). The notifier runs exactly
one plain `Timer` per interruption, set to
`BroadcastLimits.reconnectWindow` (the Spike 2.1 interim 120s,
`defaultBroadcastLimits`), started on entry to `ReconnectingState`,
cancelled on `Connected`, `leave()`, or any terminal transition. On expiry
the notifier executes F-7.4 step 4 (status check → `NotBroadcasting` or
`disconnect()` → `CannotConnect(IceFailed)`). Q3 = A: no change to the
shipped transport.

**Rule 4 — The status channel is the liveness authority, with a scoped
split.**
The session keeps a `statusChannel(broadcastId).watch()` subscription open
from first confirmed existence (resolution `offline`/`live`) until
`leave()`/`Ended`/`Full`/`CannotConnect`/different-broadcast join.
- (a) In `NotBroadcastingState`: a `live` emission auto-joins the new
  session (Q5 = A, F-7.8); `offline` is a no-op.
- (b) In `ReconnectingState`: an `offline` emission transitions
  **immediately** to `NotBroadcastingState` (timer cancelled) — the
  broadcaster's liveness is authoritatively known; waiting out the window
  would be pointless.
- (c) In `LiveViewState`: an `offline` emission is a **no-op** — the data
  channel is authoritative while captions are actually flowing; a
  broadcaster Realtime uplink hiccup must not yank a still-receiving viewer
  out of `Live`. FR-6.6's bounded timeout is then `presenceTimeout`
  (60s) + `reconnectWindow` (120s) worst case.

**Rule 5 — The cannot-connect reason mapping is exhaustive and exact; no
generic fallback.**
Extends Unit 5 Rule 3 (the four transport variants) to the three
resolution-origin variants added at Q1. Every rejection/failure path a
viewer can observe resolves to exactly one (state, copy, retry) triple:

| Reason (ConnectFailure) | Origin | State | Rendering (copy source) | Retry action |
|---|---|---|---|---|
| `BroadcastFull` | `Failed(BroadcastFull)` | `FullState` (never CannotConnect) | Proto-15 "Broadcast full" copy, verbatim | none automatic; manual "Try again" (F-7.9) |
| `NotFound` | resolution `notFound` | `CannotConnect(NotFound)` | Proto-15 generic cannot-connect copy ("…the link may be incorrect…") | **none** — the ID doesn't exist; affordances are leave/back only |
| `RateLimited` | resolution `rateLimited` (Kong 429) | `CannotConnect(RateLimited)` | "Too many attempts — please wait a moment and try again." (new, ARB) | "Try again" (F-7.9) |
| `ResolutionFailed` | resolution `resolutionFailed` (RPC/presence-read error); window expiry with **no** status emission ever observed (liveness unknown, not confirmed live — F-7.4 step 4) | `CannotConnect(ResolutionFailed)` | "We couldn't check whether this broadcast is live right now. Try again." (new, ARB — Q2) | "Try again" (F-7.9) |
| `IceFailed` | window expiry with last status live (F-7.4 step 4); ICE failure with no retry in progress; `iceServersFor()` fetch failure (F-7.2 step 5); a raw throw out of `transport.connect()` (F-7.2 step 5) | `CannotConnect(IceFailed)` | window-expiry origin: Proto-15 reconnect-timeout copy, verbatim; other origins: generic "couldn't reach" copy (Proto-15 generic text) | "Try again" (F-7.9) |
| `SignalingRejected` | `Failed(SignalingRejected)` | `CannotConnect(SignalingRejected)` | "The broadcast rejected the connection — it may have ended or changed. Try again." (new, ARB) | "Try again" (F-7.9) |
| `Timeout` | `Failed(Timeout)` | `CannotConnect(Timeout)` | "The broadcast didn't respond. Check your network and try again." (new, ARB) | "Try again" (F-7.9) |

The copies marked "new, ARB" are this unit's wording for reasons Proto-15
did not mock (the prototype approved only the generic and reconnect-timeout
cannot-connect texts); all are externalized to the ARB files (English
source) like every other string. "Cannot connect" always states its
specific reason (FR-7.4); the icon + text pairing, never color alone,
follows Proto-15's approved pattern (NFR-5.2).

**Rule 6 — Terminal states have no auto-behavior.**
`Ended`, `Full`, `CannotConnect`, and `InvalidInput` never
auto-transition: no auto-rejoin after `Ended` (the approved prototype
promises auto-connect for `NotBroadcasting` only), no auto-retry on `Full`
(Proto-15 says "try again later" — manual), no auto-retry on
`CannotConnect` (a retry loop against a rate-limited or unreachable
endpoint is abuse — SECURITY-11), and the status watch is closed in all
four. The only exits are user-initiated: leave/back, and (for
`CannotConnect` reasons other than `NotFound`) the "Try again" button,
which is a full rejoin (Q4).

**Rule 7 — A viewer session never touches the app's own captioning
pipeline.**
The viewer-scoped `CaptionBus`/`CaptionOutputTargetRegistry`/
`OnScreenCaptionTarget` are fresh instances per viewing session, disposed
on `leave()`; the app-wide Phase 1 pipeline (recording bus, registry,
transcript writer) is never subscribed to, registered on, or modified by
viewing. The session target is constructed with `repository: null` —
remote captions are never persisted to the transcript store (viewers are
anonymous; there is no device-auth transcript-save path for them).
Conversely, local captioning keeps running unaffected while a broadcast is
being viewed (the independence runs both ways, mirroring FR-6.7's
broadcaster-side rule).

**Rule 8 — No caption or transcript content in logs or state (NFR-3.3,
project constraint).**
The notifier logs state transitions and failures with state names,
reasons, and IDs only — never caption text, never the join input string
after parse failure, never signaling payloads. `InvalidInputState` carries
no data (see `domain-entities.md`). This is the same redaction discipline
Unit 5 applied to `SignalingCodec`/`CaptionWireCodec` handling, extended to
the session layer.

**Rule 9 — Leaving an active session requires explicit confirmation
(Q8 = C: option A + confirm dialog).**
"Active" = the state is `Resolving`, `Connecting`, `LiveView`, or
`Reconnecting` (a join is in flight or a connection exists — accidentally
dropping it costs the user their place, and on `Full`-adjacent broadcasts
their admitted slot). Both user actions — the screen's Leave control and
the platform back gesture/button — show a confirm dialog
("Leave the broadcast?" / "You'll stop receiving captions." / Leave–Stay,
ARB copy) in those states, and proceed immediately otherwise
(`Idle`, `NotBroadcasting`, `Ended`, `Full`, `CannotConnect`,
`InvalidInput`). The dialog is screen-level; the notifier's `leave()`
stays unconditional (the Unit 2 precedent: guards live at the call path,
not in the service).

**Rule 10 — The viewer renders with the viewer's own display settings
(FR-7.3).**
`BroadcastViewerScreen` reads the existing app-level `displaySettingsProvider`
(zip_captions' `DisplaySettingsNotifier` over zip_core's `BaseSettingsNotifier`)
— the same settings the recording screen uses; there is no separate
viewer-scoped settings store. `CaptionDisplayWidget` receives those settings
reactively, so a change (text size, font, flow direction, contrast per the
theme) applies live to a running broadcast. WCAG AAA contrast (NFR-5.1)
is inherited from the Phase 1 caption display, unchanged.

**Rule 11 — `BroadcastLink.baseUrl` is build-time configuration; no
hardcoded domain data in the viewer path (Q9 guardrail 3).**
`toUrl`/URL rendering uses `broadcastBaseUrl`
(`String.fromEnvironment('BROADCAST_BASE_URL', defaultValue:
'https://zipcaptions.app/b/')` — the v1 apex kept as the local-dev
default; release builds supply the v2 subdomain via `--dart-define`, and
the v2 host name appears nowhere in source). `parseInput` is unchanged and
host-agnostic. No other domain literal may be introduced in any file this
unit adds. Other pre-existing hardcoded domain constants (e.g. the
model-catalog CDN URL in `catalog_constants.dart`) are out of scope and
logged to the Backlog.

**Rule 12 — The viewer path is platform-neutral (Q9 guardrails 1–2).**
No `dart:io`, `dart:html`, platform-channel, or native-only imports in
`ViewerSessionNotifier`, the viewer screens, or their providers. The
routes are plain go_router paths (`/join`, `/b/:broadcastId`); the path URL
strategy for the later web enablement is a one-line switch. (This unit is
native-only — the two web acceptance criteria of S-19 are deferred to
Phase 5 per the Q9 answer and recorded in `aidlc-state.md`.)

**Rule 13 — Every viewer state is distinct by icon + text and announced
to screen readers (NFR-5.2; S-19 AC).**
Each of the eight FR-7.4 states (plus `InvalidInput`) renders a distinct
icon **and** a distinct text status — never color alone — following
Proto-15's approved data-testid state pattern. On every state *change*
the screen announces the new state's status text to assistive tech
(`SemanticsService.announce` with the live-region announcement type, or an
equivalent `LiveRegion`-wrapped status container — the exact Flutter
mechanism is a Code Generation detail; the requirement is the
announcement). Statuses render inside a `Semantics` container so the
current state is always readable, not only announced on change.

**Rule 14 — `join()` has no engine of its own; the status watch does.**
Resolving `offline` → `NotBroadcasting` is a confirmed result and needs no
retry (Rule 6: no auto-retry). Resolving `resolutionFailed` is explicitly
*not* stable (`broadcast_resolution.dart`'s own contract: "callers may
retry; unlike `BroadcastOffline`, this is not a stable result"), and the
approved Q2 rendering is a **manual** "Try again" only — the viewer may
retry, the session never auto-retries. Every repeated attempt therefore
originates with a user action or with the status watch (Rule 4), never with
a notifier-owned retry loop.
