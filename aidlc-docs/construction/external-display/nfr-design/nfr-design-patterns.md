# NFR Design Patterns — External Display (Unit 8, S-20)

**Prior stage**: NFR Requirements, approved 2026-10-20. Answers recorded
2026-10-20 under the run-configuration pre-approval (`approved by: run
configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to
morning review`). Resolves Design Q1–Q5 of
`construction/plans/external-display-nfr-design-plan.md`.

## Resilience

**R1 — The release helper is window-scoped; the display watch is
controller-lifetime (Design Q1).**
`OverlayWindowController` has exactly one private release helper:

```dart
Future<void> _release(Logger log) async {
  // each step in its own try/on Object, logging a fixed string +
  // ${e.runtimeType} only, never throwing:
  // 1. _readyTimer?.cancel()                 (the ready Timer, if active)
  // 2. _updateTimer?.cancel()                (the captionUpdate coalescer, if active)
  // 3. if (id != null) await windowService.closeWindow(id)
  // 4. registry.remove(target)               (no-op if the shell already removed it)
}
```

`close()` captures the window id into a local and nulls `_windowId`
**synchronously before its first await** (Unit 6's discipline), calls
`_release`, then performs the terminal transition
(`Off`/`Failed(reason)`/`WaitingForDisplay`) **last and unconditionally**.
The four close paths — T13 toggle off, T14 `WindowClosed`, T6/T8 failed
open, T10 display lost — share this one helper; a throwing `closeWindow`
cannot strand the machine in `Opening` (NFR Requirements Q3).

The `DisplayEnumerator.changes` subscription is **not** a release step: it is
created in the controller's bootstrap, cancelled only in `dispose()`
(together with `enumerator.dispose()` and the method-handler uninstall).
BR-U8-02's "no open subscription for that window" is satisfied because the
only per-window async handle is the ready `Timer` (and the coalescing `Timer`),
both cancelled inside `_release`. Keeping the watch alive is what makes T11's
auto-reopen from `WaitingForDisplay`, T4's `NoDisplays` → `Off` repopulation,
and T16's retry from `Failed` possible — all three fire from states with no
window.

**`isVisible` is derived, not stored (Design Q1).** `CaptionOverlayTarget`
loses its `_isVisible` field; `isVisible` returns
`_controller.isWindowOpen` (`_windowId != null` in the controller). One
writer, one invariant half — the thin-delegator rewrite (B-9) holds.

**R2 — The open guard is a chained future, opens refuse rather than queue
(D-4/BR-U8-01).** The controller serialises lifecycle operations with the
package's shipped idiom
(`browser_source_target.dart`): `Future<void> _lifecycleLock =
Future.value();`, each open/close chained onto it. A `show` issued while the
state is `Opening` is a **no-op** (BR-U8-01: "a toggle on issued mid-open is a
no-op") — the guard records nothing; the next user action is the next attempt.
`close` is allowed from any state and is a no-op when already closed
(PBT-04). Because every open/close runs on the one chain, `createWindow`
calls are structurally serial: a second window id cannot exist (BR-U8-01, the
FD §9 single-instance invariant).

**R3 — The ready `Timer` is cancelled structurally, and late ready is inert
(Design Q2).** `Timer? _readyTimer` is the controller's only time source for
the open (plus the caption coalescer, P1). It is started when the open enters
`Opening` — **before `createWindow`**, so `overlayReadyTimeout` bounds the
whole open, satisfying NFR Requirements' "no path may hold `Opening` longer
than the bound" — and cancelled:

- structurally, in the controller's single private `_setState(next)`: when
  `next is! Opening`, the timer is cancelled before the state is assigned.
  Ready receipt (T7), `Failed(create_failed)` (T6), `Failed(ready_timeout)`
  (T8), `WaitingForDisplay` (T10) and any future exit all go through it —
  Unit 7's NFR Design Q2 chose structural cancellation over remembered
  call-site cancellation for exactly this reason;
- defensively, in `_release` (R1).

A ready arriving after expiry is a no-op by construction: the handler acts
only when `state is Opening` **and** `fromWindowId` equals the current window
id. The `Timer` is driven by `fakeAsync` in tests (NFR Requirements Q1); there
is no injectable clock.

**R4 — One catch-and-map seam for every window call; pre-ready `'-1'` is
ignored (Design Q3).** Every post-ready window-service call the controller
makes goes through one private wrapper:

```dart
Future<void> _windowCall(String operation, Future<void> Function() call)
```

- `PlatformException` with code `'-1'` and `state is Open` → the
  `WindowClosed` transition (T14): `_release` + `Off` + emit
  `WindowClosed`. Only code `'-1'` means "window gone" (BR-U8-04, D-9);
  no ping/keep-alive probe exists.
- Any other `PlatformException` → fixed-string warning log (plus
  `${e.runtimeType}`) and **ignored** (B-5) — the window keeps its last good
  frame; the next push or reframe re-discovers a dead window, the
  accepted best-effort bound BR-U8-04 names.
- `createWindow` is not routed through the wrapper: its throw is caught in
  the open sequence itself → `Failed(create_failed)`, idempotent close,
  `overlayEnabled = false` (BR-U8-03, T6).

A `'-1'` received while still `Opening` (the sub-engine died before ready) is
logged with a fixed string and otherwise ignored: the ready timeout resolves
the open at the bound (BR-U8-04 scopes its rule to "after the ready
handshake"; B-5 says such a sub-engine is "caught by the same timeout, not by
a separate mechanism"). Nothing the controller awaits from a window call can
throw into the shell's `unawaited` chain (BR-U8-04's last sentence) — the
wrapper and the open sequence are the only two places a window call's error
is observed.

**R5 — The sub-engine is total-on-input (NFR Requirements Q3, restated).** On
the overlay side, a launch-argument decode failure renders the fixed
"Window unavailable" frame, logs the fixed string `invalid_window_arguments`,
and never sends `overlayReady` (the main engine's timeout converts it to
`OpenFailed`, BR-U8-03/BR-U8-19); a `captionUpdate` decode failure is dropped
and the last good frame is kept. Neither path throws out of a method handler —
an unhandled exception in a secondary engine's handler can tear that engine
down (BR-U8-19). The codec is the enforcement point (total-on-error,
`null` on any malformed input, B-7/BR-U8-24); the entry and the handler call
`decode` and branch on `null`.

**R6 — Fail-closed everywhere (SECURITY-15).** A failed open reverts
`overlayEnabled` to `false` (BR-U8-03); a lost display closes and releases
before entering `WaitingForDisplay` (BR-U8-02 before BR-U8-22); an
unsupported platform renders no section and no window at all (BR-U8-11);
an absent handler installer on a supported platform fails the open with
`create_failed` **before** any `createWindow` call (P4/D7 — the handler is a
precondition of the open, and no window is left half-open). The state machine
never fails open into a stuck `Opening` or an `overlayEnabled = true` with a
released window.

## Scalability (restated from NFR Requirements — no new pattern)

NFR-2 is N/A and stays N/A after the patterns above: at most one secondary
window (R2's guard), one `changes` subscription (R1 — controller-lifetime,
disposed with the controller), one method handler on the main engine (D7),
one ready `Timer` and one coalescing `Timer` (R3/P1). No queue, pool, cache,
or concurrency axis is introduced; the source buffer the window mirrors is
capped by the shipped `maxBufferSegments` (2000) and a multi-monitor setup is
a configuration of one window, not a scaling axis. No cache, queue, batching
pool, or circuit breaker is added at this stage.

## Performance

**P1 — Snapshot delivery is a dirty flag plus one re-arming 16 ms timer
(Design Q4).** NFR Requirements fixed "at most one `captionUpdate` per
animation frame (60 Hz → at most 60 pushes/s) regardless of the upstream
recognition event rate". The controller implements it as:

- `push(CaptionOverlaySnapshot snapshot)` (the `CaptionOverlayTarget`'s
  entry point): stores `snapshot` as the latest held snapshot — while closed
  it *is* the held snapshot T7 sends immediately on ready — and, while
  `Open`, arms a single `Timer(captionUpdateInterval)` if none is active.
  Pushes arriving while the timer is armed only update the stored snapshot.
- On fire: the controller sends exactly one `captionUpdate` carrying the
  latest stored snapshot (through the R4 seam) and disarms.

At most one send per 16 ms window holds under any upstream rate, including a
continuous one, and a stream that stops flushes its last state within one
interval. `captionUpdateInterval` is `const Duration(milliseconds: 16)`
(one 60 Hz frame) — a named constant in `overlay_window_controller.dart`.
The alternative shape — a reset timer per push, the Phase 1
`OnScreenCaptionTarget` debounce — would never fire under a continuous
stream shorter than the interval and was rejected on that ground (plan
Design Q4). The timer is cancelled in `_release` (R1) and in `dispose()`.
`fakeAsync` drives it in FP-5; a `SchedulerBinding` frame callback would not
be drivable in the controller's unit tests and was rejected for that reason.

**P2 — Enumeration is event-driven, one query per event, zero polls
(NFR Requirements, restated).** `ScreenRetrieverDisplayEnumerator` performs
at most one `getAllDisplays()` per platform event (re-query-and-diff), never
synthesises a poll, and coalesces adjacent equal lists — a no-change event
produces zero emissions (BR-U8-05, FD event contract). On macOS the frame
conversion additionally calls `getPrimaryDisplay()` once per
`setFrame` (its `primaryFullHeight` input) — a platform call inside the open/
reframe path, not a poll; the controller's open/reframe path is itself
event-driven (toggle on, `changes` with changed bounds).

**P3 — Named constants (NFR Requirements Q4/Q5, placed by Design Q4).**

| Constant | Value | File | Enforces |
|---|---|---|---|
| `overlayReadyTimeout` | `const Duration(seconds: 10)` | `overlay_window_controller.dart` | BR-U8-23's bound; R3's timer |
| `captionUpdateInterval` | `const Duration(milliseconds: 16)` | `overlay_window_controller.dart` | P1's ≤1-per-frame cadence |
| `maxEncodedBytes` | `static const int = 16 * 1024` on the codec | `caption_overlay_codec.dart` | B-7/BR-U8-24 size guard (mirrors `CaptionWireCodec.maxEncodedBytes` placement) |

**P4 — The state machine is synchronous per event (NFR Requirements,
restated).** Every event (toggle, `changes` emission, ready, timeout,
`WindowClosed`, Cancel, recognition activity change) is processed in a single
synchronous span: no `await` inside a transition; the only awaits are the
plugin calls inside the open sequence and the release steps, both behind R2's
lifecycle lock. The open guard serialises open/close/reframe (BR-U8-01).

**P5 — The frame conversion is a pure function (FD, restated).**
`toPlatformFrame(Rect frame, TargetPlatform target,
{double? primaryFullHeight, double? displayScaleFactor}) → Rect` lives in
`desktop_multi_window_service_io.dart` (the only file that may see
platform-specific coordinate reasoning): identity on Linux; Windows multiplies
every edge by the target display's own `scaleFactor` (0/missing → 1); macOS
flips `y` against the primary's **full** height. No I/O inside; the platform
inputs are arguments (FP-3's oracle is the B-1/B-2 reference rules). It is
called at most once per open and once per reframe.

## Security

**S1 — Fixed-string logging only, audited at the record level (Design Q5,
NFR Requirements Q6).** No new logging infrastructure; the existing
`logging` package only. Every new call site logs a fixed string plus
`${e.runtimeType}` and nothing else:

| Call site | Fixed string (shape) | Trigger |
|---|---|---|
| `_release` steps (closeWindow, registry.remove) | `overlay release <step> failed` | any release step throws |
| `_windowCall` ignored errors | `overlay window call failed (<operation>)` | non-`'-1'` `PlatformException` (R4) |
| `_windowCall` pre-ready `'-1'` | `overlay ready lost before handshake` | code `'-1'` while `Opening` (R4) |
| open sequence catch | `overlay create failed` | `createWindow` throws (T6) |
| `ScreenRetrieverDisplayEnumerator` | `display enumeration failed` (level `warning`) | platform query fails; stream stays open (FD event contract) |
| sub-engine launch decode | `invalid_window_arguments` | launch argument fails to decode (BR-U8-19) |
| sub-engine `captionUpdate` decode | `overlay caption update dropped` | snapshot fails to decode (BR-U8-19) |

Never logged: caption text, the snapshot, the raw launch argument, a
`DisplayInfo.label` inside an error message, or an exception's full
`toString()` from a platform-channel path. `OpenFailed.reason` is a short
fixed code in `{create_failed, ready_timeout}` — never a payload, never
shown raw (frontend-components.md's `Failed` row shows fixed copy).
`DisplayLost.displayId` is the opaque id, never a label or caption
(BR-U8-18).

**S2 — The redaction audit test (Design Q5).**
`test/output/overlay/external_display_redaction_test.dart` registers a
capturing `Logger.root.onRecord` listener into a `List<LogRecord>` (the Unit 7
pattern, `viewer_session_notifier_test.dart:572-587`) and drives, with a
sentinel caption string in flight: (a) a `captionUpdate` decode failure and a
launch-argument decode failure (the `invalid_window_arguments` path), (b) the
open-failure paths (`createWindow` throws → `create_failed`; ready timeout →
`ready_timeout`), and (c) a release path with a throwing `closeWindow`.
Asserts: no `LogRecord.message` and no `LogRecord.error` string contains the
sentinel; every emitted `OpenFailed` has `reason` in the fixed set;
`DisplayLost.displayId` is the opaque id. The widget-key/semantics half of
BR-U8-18 is covered structurally — no widget in this unit takes caption text
into a key or semantics label (the controls render status copy only; the
overlay window's content is the window itself) — and stated in the test's
doc, not re-grepped.

**S3 — Signed-out-only, one capability gate (BR-U8-14, BR-U8-11).** No auth
provider is read anywhere in this unit's paths; no new auth call path exists.
Web is excluded by `DesktopWindowService.isSupported` (the stub returns
`false`); no code path checks `kIsWeb`. The feature behaves identically
signed in and signed out.

## Testability

**T1 — Fakes, not plugins (NFR Requirements Q1).** `OverlayWindowController`
is a plain class tested entirely against: `MockDesktopWindowService`
(mocktail, extended in place with `setFrame`/`show` when the B-6 interface
edit lands — mocktail's `noSuchMethod` covers the additive interface methods
with no class change; the extension step is one step with the B-6 edit);
`FakeDisplayEnumerator` (hand-written in `test/helpers/`: a scripted
`displays()` result or error, a broadcast `changes` stream with a
`pushDisplays` helper that **replays the latest list to late subscribers**
— mirroring the FD event contract's first-emission clause — and an idempotent,
recorded `dispose()`); `FakeOverlayMethodHandlerInstaller` (records the
installed `OverlayMethodHandler` so a trial can invoke
`handler('overlayReady', id)` directly); and the `OutputTargetSettings`
notifier via the standard provider override. The controller's own logic —
state machine, open guard, handshake, held snapshot, release helper,
coalescer — runs real. No `desktop_multi_window`, no `screen_retriever`, no
runner, no device, no second display, no network.

**T2 — Widget tests (NFR Requirements Q2).** `ExternalDisplayControls`
(embedded in the shipped `OutputTargetsPanel` via `zb_test_harness.dart`):
one test per approved state — `Unsupported` renders nothing, `NoDisplays`
copy with no toggle, `Off` rows with the "Display N" empty-label fallback and
meta lines, `Opening` affordance, `Open` active row with the live position
selector, `WaitingForDisplay` disconnected banner + "waiting for display" +
Cancel, `Failed` fixed-copy banner with no raw reason; plus row tap writes
`externalDisplayId` only (BR-U8-07) and Cancel keeps the saved id.
`OverlayWindowApp` (real `MaterialApp` + `ProviderScope` overrides): standby,
live (shipped `CaptionDisplayWidget`, D-7/BR-U8-25), paused (frozen buffer +
`__pause__` marker row), "Window unavailable" frame on launch decode failure
(BR-U8-19), caption position top vs bottom (BR-U8-26), and the BR-U8-20
theme-wiring test (dark → light swap in a new snapshot observes the rendered
surface colour change). No golden tests (the project has none). The BR-U8-20
test and the opaque-surface test are scheduled as **acceptance** tests, not
optional ones.

**T3 — Timer discipline (NFR Requirements Q1).** The ready `Timer` and the
coalescing `Timer` are both `fakeAsync`-driven; the controller owns both
time sources and nothing else (R3, P1). The FP-5 suite wraps each Glados
trial in one `fakeAsync` (the
`viewer_session_state_machine_properties_test.dart` shape), so
`advanceReadyTimeout` and `elapse` are exact.

## Security Baseline Compliance

Carried from NFR Requirements (no verdict changed by the patterns above):

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A | No new store. Persistence is the two existing `SharedPreferences` keys (`output.externalDisplayId`, `output.externalDisplayCaptionPosition`) via the Phase 1 mechanism — opaque display id and a UI preference, no transcript or sensitive data. No network transit: the window boundary is a local platform channel, and this unit touches no Supabase surface. |
| SECURITY-02 (Access logging on intermediaries) | N/A | No new route, gateway, or network intermediary. No backend, no network at all in this unit. |
| SECURITY-03 (Application-level logging) | Compliant (S1/S2) | Existing `logging` infrastructure only; fixed strings plus error type at every new call site (S1's table is the call-site list); caption/snapshot/launch-argument exclusion enforced by the record-level redaction test (S2). |
| SECURITY-04 (HTTP security headers) | N/A this unit | No HTML-serving endpoint. Web is excluded by `DesktopWindowService.isSupported` (BR-U8-11); the web scaffold and its headers remain deferred to Phase 5. |
| SECURITY-05 (Input validation) | Compliant | The hand-written versioned codecs are the single untrusted-input boundary (BR-U8-24, B-7): total-on-error decode, `maxEncodedBytes` UTF-8 byte guard, enums by name, exactly one `mode` source; a malformed launch renders the fixed "Window unavailable" frame (BR-U8-19), a malformed `captionUpdate` is dropped; display ids are opaque strings, never labels, persisted only by explicit user action (BR-U8-07/08). |
| SECURITY-06 (Least privilege) | N/A | No IAM policy, role, or database privilege defined by this unit. |
| SECURITY-07 (Network configuration) | N/A | No network configuration of any kind — no backend, no ICE, no relay. |
| SECURITY-08 (Application-level access control) | Compliant (BR-U8-14) | Signed-out is the only mode: no auth provider read, no session required, no new auth call path (S3). |
| SECURITY-09 (Hardening) | Compliant | Failures surface only as fixed `ExternalDisplayStatus` variants with fixed copy; no exception message, stack trace, or platform detail reaches the UI; the switch starts off at launch (D-6, BR-U8-21) — no auto-open surface at all. |
| SECURITY-10 (Supply chain) | Compliant | Exactly one new dependency: `screen_retriever: ^0.2.2`, with its record in the FD (`screen-retriever-security-10.md`); single-file import fence (the io enumerator file only); `window_manager` removed (D-13). |
| SECURITY-11 (Secure design, rate limiting) | Compliant | No public-facing endpoint (rate limiting N/A-within-rule); misuse designed out: malformed input degrades to a fixed frame + `OpenFailed` timeout (BR-U8-19); a second concurrent open is structurally refused (BR-U8-01, R2); a lost display is closed and released, never orphaned (BR-U8-22); oversized payloads rejected by the size guard (BR-U8-24). |
| SECURITY-12 (Auth/credential management) | N/A | Manages no credential; the feature is signed-out-only by design (BR-U8-14). |
| SECURITY-13 (Data integrity) | N/A | No persisted table beyond the two non-sensitive settings keys; the wire shape is versioned (`v`) and the decode is total, so an engine mismatch degrades to `OpenFailed`, never a partial or corrupted render. |
| SECURITY-14 (Alerting/monitoring) | N/A | Standing project-wide Backlog item as every prior unit; no new security-relevant event. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant (R1–R6) | Every release step caught and logged individually (R1); the terminal transition always completes; decode is total (R5); `'-1'` converts to `WindowClosed` without reaching the UI (R4); a failed open reverts `overlayEnabled` (R6) — fail-closed: nothing observable is left "on". |

## PBT Compliance

Framework: the in-tree shim `packages/zip_broadcast/test/helpers/pbt.dart`
(PBT-09, re-affirmed from NFR Requirements). Verdicts carried (no verdict
changed by the patterns above):

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | Compliant | FD `business-rules.md` "Testable Properties" table: FP-1..FP-5 with categories; components-without-properties marked with rationale. |
| PBT-02 (Round-trip) | Compliant (planned) | FP-1: snapshot and launch codec round-trip across generated inputs including multibyte text and 0..max entries. |
| PBT-03 (Invariant) | Compliant (planned) | FP-2 (total-on-error), FP-4 (BR-U8-07 resolution keeps the absent id — the subject is now the named pure function `resolveOpenDisplay`, logical-components), FP-5 (closure + closed invariant at every step); FP-3's edge invariants ride inside it. |
| PBT-04 (Idempotence) | Compliant (planned) | Close/release idempotence (BR-U8-02/03: a second close, a toggle-off from `Off`, a `closeWindow` on an already-released id) asserted inside FP-5's sequences and once directly; `DisplayEnumerator.dispose()` idempotence is part of T1's fake contract. |
| PBT-05 (Oracle) | Compliant (planned) | FP-3 verifies `toPlatformFrame` against the B-1/B-2 reference rules (P5); the review comment is the oracle; there is no second implementation. |
| PBT-06 (Stateful) | Compliant (planned) | FP-5: the T1–T17 machine driven by generated event sequences against a real controller on the T1 fakes inside `fakeAsync`, checked after every command (the harness shape is fixed in the plan, Design Q9). |
| PBT-07 (Generator quality) | Compliant (planned) | Domain generators in `test/helpers/generators.dart` (the list is fixed in the plan, Design Q9): `DisplayInfo` lists, `CaptionOverlaySnapshot`s, `OverlayWindowLaunch`es, malformed-input strings, logical frames + platform inputs, and the FP-5 command-sequence generator. |
| PBT-08 (Shrinking/reproducibility) | Compliant, with a recorded limit | Seeds fixed `0..99`, deterministic, reproducible by seed index; the shim has **no shrinking** — the documented reduction path is hand-reducing the failing seed's input and pinning it as an example test (PBT-10). CI runs the suite via the existing `flutter test`; no PBT is excluded. |
| PBT-09 (Framework selection) | Compliant | The in-tree shim; no framework package exists or is added. |
| PBT-10 (Complementary testing) | Compliant (planned) | The named example cases stay explicit: the macOS negative-Cocoa-y flip, Windows at 1.5x, the mixed-DPI setup, the three close paths, the T1–T17 transition table, the BR-U8-20 theme-wiring test, the position-selector persistence, the T1 fake contract tests. PBT is not the sole coverage for any business-critical path. |

## Open questions carried to Infrastructure Design / Code Generation

- B-4's sub-engine plugin registration ("register exactly what the overlay's
  code path touches; `google_fonts` (via `path_provider`) is expected.
  Confirm by running the overlay on macOS") is a Code Generation step with a
  **Unit 9 manual check** for the confirmation — carried forward, not
  attempted here.
- **Minimal interpretation (recorded for the morning review):** BR-U8-12's
  "…caption-position change in the main window must reach the window without
  a reopen" is implemented as "the window applies the persisted caption
  position carried in the launch config at open". The authoritative B-7 wire
  shape carries no position in the snapshot's `settings` block, so a position
  changed while open takes effect at the next open — the launch config is
  the carrier the FD already fixes, and no mechanism beyond the settled shape
  is invented. Font/size/scroll/theme/max-lines changes do reach a live
  window, because they travel in the snapshot's `settings` on every
  `captionUpdate` (BR-U8-12's primary clause).
- **`isPrimary` derivation (Design Q6 adapter note):** `screen_retriever`
  0.2.2's `Display` model has no `isPrimary` field (verified in the pub
  cache); the io adapter derives it per re-query: call `getPrimaryDisplay()`
  once, match by `id` when both the primary's and the display's ids are
  non-empty, else by geometry (`visiblePosition` + `visibleSize` equality);
  if nothing matches (the Linux `id: ""` case), mark the **first display in
  platform order** primary. This preserves the FD's "exactly one `true` in a
  non-empty list" constraint and matches BR-U8-07's final fallback.
  `getPrimaryDisplay()` is itself a platform-channel query in 0.2.2
  (`screen_retriever_method_channel.dart:51`), so the adapter calls it at
  most once per enumeration event — one-shot per event, never a poll, and
  only on the event-driven re-read path (never on a timer).
