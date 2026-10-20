# NFR Requirements Plan: External Display (Unit 8, S-20)

**Prior stage**: Functional Design (revised), approved 2026-10-20.
**Run mode**: unattended (`.agent/overnight-pipeline.md` adaptation A2). Every
question below is answered here under the run-configuration pre-approval and
recorded in `audit.md` as `approved by: run configuration
(.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review`. The
design input is the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>)
plus the A7 follow-up (6282213636); no open question remains on the design, so
every answer is settled by those sources, the FD, or an existing project
convention. A genuinely new, unanswerable question would stop the run as
BLOCKED; none arose.

## Context

The FD (revised) fixed the window lifecycle (one `OverlayWindowController` as
sole owner, the T1-T17 state machine over the seven `ExternalDisplayStatus`
variants, the `createWindow` → `setFrame` → `show` open order, the
`overlayReady` handshake with a named `overlayReadyTimeout`, close detection by
`PlatformException` code `'-1'` only), the display enumeration (a
`DisplayEnumerator` over `screen_retriever`'s re-query-and-diff contract), the
hand-written versioned snapshot/launch codec (total-on-error, `maxEncodedBytes`
guard, `sessionId`/`sourceId` never cross the boundary), and the two frontend
components (`ExternalDisplayControls`, `OverlayWindowApp`). The open NFR
questions are concentrated in **testability** (a controller whose every
collaborator must be fakeable without a runner or a second display, plus a
state machine with a reference model), **reliability** (exception-safety of
open/close/teardown and of the sub-engine's method handler, both reachable by
real failures), **performance** (three concrete targets this unit owns: the
ready-timeout bound, the per-frame snapshot cadence, and the codec size guard),
**security** (the "no caption text outside the window" audit across the new
paths), **tech stack** (the single new dependency, already recorded in the FD),
**PBT** (framework decision and expressibility of FP-1..FP-5), and
**accessibility** (NFR-5.1's AAA contrast on the external display, carried as a
testable wiring requirement).

**Scalability (NFR-2)**: N/A. No new capacity, queue, or resource pool. At most
one secondary window (BR-U8-01), one display-list subscription, one method
handler on the main engine (BR-U8-23). No limit of this unit's own is defined;
`maxBufferSegments` (2000, shipped `OnScreenCaptionTarget` default) bounds the
source buffer the window mirrors.

**Performance (NFR-1)**: the unit owns no network latency (no backend, no
network — the window boundary is a local platform channel). It owns three
concrete values, all derived from the FD: the ready-handshake bound
(`overlayReadyTimeout`, ~10 s named constant, BR-U8-23), the snapshot cadence
(debounced per animation frame, business-logic-model §3), and the codec size
guard (`maxEncodedBytes`, the `CaptionWireCodec` 16 KiB precedent). Display
placement, borderless rendering, hot-plug reopen, and OS-shortcut close cannot
be machine-verified without multi-monitor hardware — they are Unit 9 manual
checks (run-configuration device policy), recorded as such, not claimed.

**Verified against source** (2026-10-20, before writing questions):

- `packages/zip_broadcast/pubspec.yaml` already declares `desktop_multi_window:
  ^0.2.0` (Phase 1 shipped) and the dev dependencies `fake_async: ^1.3.2` and
  `mocktail: ^1.0.4`; no `screen_retriever`, no `glados`, no `window_manager`.
- `test/helpers/mock_desktop_window_service.dart` is a 6-line mocktail mock of
  the shipped four-method `DesktopWindowService` (verified against
  `lib/src/output/overlay/desktop_window_service.dart`); B-6's `setFrame`/`show`
  are not on the interface yet.
- `test/helpers/pbt.dart` is the in-tree shim: `Generator<T>`, `any`
  (`choose`/`boolGen`/`letterOrDigits`/`intInRange`/`doubleInRange`/
  `combine2..6`/`listWithLengthInRange`), `Glados<T>(gen).test(desc, body)` —
  100 trials, `Random(seed)` for `seed` in `0..99`, `await body(value)` (async
  bodies supported). No shrinking.
- `packages/zip_core/lib/src/models/caption_wire_codec.dart:25` and
  `signaling_codec.dart:37` both carry `maxEncodedBytes = 16 * 1024` with a
  UTF-8 `_encodedByteLength` check on the full encoded payload — the
  nested-field precedent BR-U8-24 names.
- `packages/zip_core/lib/src/output/on_screen_caption_target.dart` debounces at
  50 ms (NFR PERF-U3.1) and caps the final-segment buffer at
  `maxBufferSegments` (default 2000); `recording_screen.dart:131` is the
  `CaptionDisplayWidget` the window mirrors (D-7, verified present).
- `zip_core/test/pbt/theme_contrast_test.dart` exists — the AAA ratio of
  `AppTheme`'s `surface`/`onSurface` pairs is already asserted there, which is
  why BR-U8-20 forbids repeating the assertion and requires the wiring test
  instead.
- The overlay directory ships `caption_overlay_target.dart`,
  `desktop_window_service.dart` (+ `_io`/`_stub` implementations of
  `desktop_multi_window_service.dart`) — the placement home for this unit's
  types is the existing `lib/src/output/overlay/`.
- Plugin claims relied on in the FD (window-created callbacks on all three
  platforms, `screen_retriever` 0.2.2's `getAllDisplays`/`ScreenListener`,
  `ScreenRetriever.instance` not deprecated) were verified against the pub
  cache sources in Stage 1; this stage reuses those verified facts and adds no
  new plugin claim.

## Planned Steps

- [x] Testability: fake strategy for `OverlayWindowController` (Q1)
- [x] Testability: widget-test scope and seams for the two components (Q2)
- [x] Reliability: exception-safety of open/close/teardown and the method
      handler (Q3)
- [x] Reliability/Availability: the ready-handshake bound and failure mode (Q4)
- [x] Performance: the three concrete targets and the Unit 9 manual-check list
      (Q5)
- [x] Security: the BR-U8-18 logging audit for the new paths (Q6)
- [x] Tech stack: the dependency footprint (Q7)
- [x] PBT: framework decision and FP-1..FP-5 expressibility (Q8)
- [x] Usability/Accessibility: NFR-5.1 AAA contrast and colour-independence (Q9)
- [x] Generate `nfr-requirements.md`, `tech-stack-decisions.md`,
      `handoff-summary.md`

## Testability

### Q1: How is `OverlayWindowController` tested — what gets faked, and where do the fakes live?

The controller's collaborators are exactly: `DesktopWindowService` (the B-6
seam), `DisplayEnumerator` (new abstract), the `OutputTargetSettings` notifier
(toggle/id/position writes), and the caption-bus side reached through
`CaptionOverlayTarget` (the snapshot source). Everything else — the state
machine, the open guard, the handshake, the held snapshot — is the controller's
own logic and must run real.

A) Extend the existing `test/helpers/mock_desktop_window_service.dart` (the
   B-6/A7 direction) so the mocktail mock covers the additive `setFrame`/`show`;
   add a hand-written `FakeDisplayEnumerator` (scriptable `displays()` result
   plus a broadcast `changes` stream the test can push new display lists into)
   to `test/helpers/fake_services.dart` or a new `test/helpers/` file following
   the existing naming. Drive `OverlayWindowController` against these fakes:
   the full T1-T17 transition table, the open guard (BR-U8-01), the handshake
   (ready in time / ready late / no ready), close detection (`'-1'` code →
   `WindowClosed`; any other `PlatformException` logged and ignored), the
   display-lost/waiting/reopen path (D-4), and the closed invariant
   (BR-U8-15) after every command. The ready-timeout and any `Timer` are driven
   with `fakeAsync` (A7: "use `fake_async` for the ready-timeout tests"); the
   stateful PBT (FP-5) wraps each trial in `fakeAsync`, the Unit 7 NFR Design
   precedent for timer-bearing stateful suites. No `desktop_multi_window`, no
   `screen_retriever`, no runner, no device, no second display. **(recommended —
   the Unit 5/6/7 "test the seam, not the already-tested dependency" pattern;
   the mock already exists and B-6 names it explicitly)**

B) New parallel mock file for the extended `DesktopWindowService`
C) Other (write in)

[Answer]: A — settled by A7 ("Extend `test/helpers/mock_desktop_window_service.dart`
for the new `setFrame`/`show` methods (B-6)") and the project's standing
fake-helper convention (Units 5/6/7 precedent).

### Q2: What is the widget-test seam and coverage for `ExternalDisplayControls` and `OverlayWindowApp`?

`frontend-components.md` specifies the render per status (seven variants, with
`Unsupported` rendering nothing) and the `OverlayWindowApp` render per
`OverlayActivity` (three) plus the decode-failure frame. The Unit 6/7
precedent is one test per approved state, driven by a hand-written fake
notifier/provider override in the existing `zb_test_harness.dart` harness.

A) `ExternalDisplayControls`: one test per status — `Unsupported` (section
   absent), `NoDisplays` (copy, toggle absent), `Off` (rows, "Display N"
   fallback for an empty label, meta lines, position selector default),
   `Opening` (opening affordance), `Open` (active row, position selector live),
   `WaitingForDisplay` (disconnected banner + "waiting for display" + Cancel),
   `Failed` (fixed-copy banner, no raw reason). Plus the two interaction rows:
   a row tap writes `externalDisplayId` only (no settings write on mere render,
   BR-U8-07), and Cancel keeps `externalDisplayId` (BR-U8-07).
   `OverlayWindowApp`: standby (theme background, no text), live
   (`CaptionDisplayWidget` fed by decoded entries + interim), paused (frozen
   buffer + `__pause__` row), the "Window unavailable" frame for a launch decode
   failure, the caption position top vs bottom, and the BR-U8-20 wiring test
   (dark → light `themeModeSetting` swap in a new snapshot observes the rendered
   surface colour change; an overlay-introduced literal would fail it). Mounted
   in a real `MaterialApp` with `ProviderScope` overrides; no golden tests
   (this project has none). **(recommended — one test per acceptance-criterion-
   bearing state, the Unit 6/7 bar; the BR-U8-20 test is the S-20 contrast AC
   made mechanical)**

B) Provider-state only, skipping the per-status render assertions
C) Other (write in)

[Answer]: A — project convention (Unit 6 `broadcast_screen_test.dart` 13-states
precedent; Unit 7 Proto-14/15 one-test-per-state precedent).

## Reliability

### Q3: What happens when an open, close, or release step itself throws — and when the sub-engine's method handler hits a malformed message?

Three reachable failure modes: (1) a close/release step throws (`closeWindow`
can throw — the `'-1'` code itself, or a transport error; deregistering the
target or cancelling the display subscription can also throw); a naive
implementation can strand `overlayEnabled = true` with a released window or
leave the target on the registry, breaking BR-U8-15. (2) `createWindow` throws
mid-open (T6) or the ready timeout fires on a half-open window (T8) — the
window must be closed idempotently (BR-U8-03). (3) on the sub-engine side, a
`captionUpdate` or launch argument that fails to decode: an unhandled
exception in a secondary engine's method handler can tear down that engine
(BR-U8-19).

A) One shared private release helper on the controller (an
   `_release(Logger)`-shaped method) that attempts every step in order —
   `closeWindow` (idempotent), target deregistration, display-subscription
   cancel, window-id nulling, `isVisible` false — catching and logging each
   individually (fixed string + exception `runtimeType` only, per Q6), never
   throwing; the terminal transition (`Off`, `Failed(reason)`, or
   `WaitingForDisplay` for the display-lost path) always happens last and
   unconditionally. The display-lost path (T10) shares the same helper: the
   window is released and *then* the waiting state is entered with
   `overlayEnabled` still `true` (D-4). On the sub-engine side, decode failure
   is total: the launch codec's `null` result renders the fixed "Window
   unavailable" frame and never sends `overlayReady` (so the main engine's
   timeout converts it to `OpenFailed`); a `captionUpdate` decode failure is
   dropped and the last good frame is kept — neither path throws out of the
   method handler. **(recommended — the Unit 6 Q3 / Unit 7 Q3 catch-and-continue
   discipline applied to the unit's own release sequence; BR-U8-02's four-part
   invariant is directly asserted in the stateful suite)**

B) Let a release exception propagate to the settings shell
C) Other (write in)

[Answer]: A — Unit 6/7 precedent; BR-U8-02/03/04/19 as written in the FD.

### Q4: What is the ready-handshake bound, and how is its failure mode tested?

BR-U8-23 fixes the mechanism: exactly one `DesktopMultiWindow.setMethodHandler`
(installed by the controller before the first `createWindow`), success only on
`overlayReady`, `overlayReadyTimeout` a named constant (~10 s), expiry →
`OpenFailed(ready_timeout)`; a sub-engine that dies before installing its
handler is caught by the same timeout. B-5 adds that the main engine sends
nothing until ready (the window shows standby until the first snapshot).

A) `overlayReadyTimeout = 10 s` as a named `const Duration` in `zip_broadcast`
   (the FD's "~10 s" read as its own number — recorded under ASSUMPTIONS).
   Failure mode is exactly BR-U8-03's: target not registered, `isVisible`
   false, window id null after the idempotent close of the possibly half-open
   window, `overlayEnabled` back to `false`, UI in `Failed(ready_timeout)`,
   nothing logged that contains caption text or the raw launch argument.
   Testability: no clock seam, no injectable time source — one `Timer` (or
   equivalent) driven by `fakeAsync` in the unit tests and in FP-5's stateful
   suite, the `supabase_auth_service.dart` / Unit 5/7 precedent. Tests: ready
   before expiry → `Open` + held snapshot sent exactly once; no ready → expiry
   at the constant → `OpenFailed(ready_timeout)`; ready *after* expiry is a
   no-op (the open already failed). **(recommended — the constant is the FD's
   value; `fakeAsync` is the A7 direction; a clock seam would add a parameter
   with exactly one implementation)**

B) An injectable `DateTime Function()? now` seam on the controller
C) Other (write in)

[Answer]: A — FD BR-U8-23/BR-U8-03 + A7 (`fake_async` for the ready-timeout
tests). The 10 s value is the FD's own "~10 s" (ASSUMPTIONS).

## Performance

### Q5: What are this unit's concrete performance targets, and what is explicitly not machine-verifiable?

A) **Display enumeration** (BR-U8-05 + the event contract): at most **one**
   `getAllDisplays()` platform query per platform event (`display-added` /
   `display-removed` — re-query-and-diff), and **zero** periodic polls (the
   adapter never synthesises a poll); adjacent equal lists are coalesced so a
   no-change event produces **zero** emissions. No network is involved.
   Testable: the `FakeDisplayEnumerator` contract tests (first emission to a
   late subscriber; connect; disconnect; rearrangement emits; no-change does
   not; error → fixed warning log, stream stays open).
   **Window open including the handshake** (B-6, BR-U8-23): the open sequence
   is exactly `createWindow` → `setFrame` → `show` (three plugin calls), and
   open completion is **bounded by the `overlayReadyTimeout` constant (10 s)**:
   success on `overlayReady`, failure (`OpenFailed(ready_timeout)`) at the
   bound — no path may hold the `Opening` state longer than the bound. No
   snapshot is sent before ready (B-5); the first visible frame is already on
   the target display at work-area size (B-6).
   **Snapshot delivery cadence** (business-logic-model §3): a caption event
   triggers at most **one** `captionUpdate` per animation frame (60 Hz → at
   most 60 pushes/s) regardless of the upstream recognition event rate, and
   every encoded payload is under **`maxEncodedBytes` = 16 KiB** (the
   `CaptionWireCodec`/`SignalingCodec` precedent; applied to the full encoded
   payload including nested fields and multibyte characters, BR-U8-24). The
   snapshot build is O(visible final captions) — the buffer cap is the shipped
   `maxBufferSegments` (2000).
   **State-machine responsiveness**: every event (toggle, `changes`, ready,
   timeout, `WindowClosed`, Cancel, recognition activity change) is processed
   in a single synchronous span — no timer other than the ready-timeout one,
   no `await` inside a transition, the open guard serialising open/close/
   reframe. Testable: FP-5's stateful suite asserts the closed invariant
   (BR-U8-15) and single-window invariant (BR-U8-01) after **every** command.
   **Not machine-verifiable (Unit 9 manual checks, per the device policy —
   no device, no second display, recorded, not claimed):** display placement
   and work-area framing on real multi-monitor hardware (including fractional
   scaling and Wayland — the FD records the remaining discrepancy as
   unreconciled by design); borderless rendering on all three platforms
   (including "borderless applied on macOS"); the reopen-on-reconnect flow with
   a real hot-plug; closing the window by OS shortcut; B-4's sub-engine plugin
   registration completeness ("Confirm by running the overlay on macOS").
   **(recommended — every number is the FD's or its named precedent's; nothing
   is invented, and the unverifiable items are recorded as the run
   configuration's Unit 9 manual checks rather than claimed verified)**

B) Invented end-to-end latency targets (open-to-first-painted, etc.)
C) Other (write in)

[Answer]: A — derived from the FD (BR-U8-05/23/24, B-5/B-6, §3) and the
`CaptionWireCodec` precedent; the run configuration's device policy names the
manual-check list.

## Security

### Q6: What is the logging constraint for this unit's new log call sites, and how is BR-U8-18 audited?

The new call sites: the controller (open failures, the ignored non-`'-1'`
`PlatformException`s, release-step exceptions, close detection), the
`ScreenRetrieverDisplayEnumerator` (the event contract's fixed `warning` on a
platform failure), and the sub-engine's `OverlayWindowEntry` (the
`invalid_window_arguments` fixed string). The only permitted `debugPrint` is
`desktop_multi_window`'s own (verified in Stage 1 against
`WindowChannel.swift`).

A) No new logging infrastructure. The existing `logging` setup is reused; every
   call is a **fixed string plus an error type** (exception `runtimeType`),
   matching `BR-U3-36` and SECURITY-03. Never logged: caption text, the
   snapshot, the raw launch argument, `DisplayInfo.label` inside an error
   message, or an exception's full `toString()` from a platform-channel path.
   `OpenFailed.reason` is a short fixed code (`create_failed` /
   `ready_timeout`), never a payload; `DisplayLost.displayId` and
   `WaitingForDisplay.displayId` carry the opaque display id, which the FD
   already scopes as the waiting key. **Audit requirement** (the "no caption
   text outside the window" check across the new paths): a test drives the
   decode-failure path, the open-failure path, and the release path and asserts
   that no log record, `OverlayEvent` payload, or error message contains a
   caption string that was in flight — the Unit 7 CodeRabbit redaction-test
   pattern. Widget keys, semantics labels, and test failure messages are
   excluded by construction (the `Failed` banner shows fixed copy, no raw
   reason). **(recommended — no new mechanism, consistent with every prior
   unit's identical confirmation; the audit test makes BR-U8-18 mechanical)**

B) Other (write in)

[Answer]: A — BR-U8-18 as written in the FD; the audit-test pattern is the
project's existing redaction-test precedent (Unit 7).

## Tech Stack

### Q7: Does this unit introduce any new dependency?

A) Exactly one: **`screen_retriever: ^0.2.2`** in `zip_broadcast` — the FD's
   SECURITY-10 record (`functional-design/screen-retriever-security-10.md`)
   stands: 16 releases counted against pub.dev, 0.3.0 excluded by the SDK floor
   (Dart `^3.13.0` / Flutter `>=3.47.0` against the monorepo's
   `>=3.10.0`/`>=3.38.0`), `ScreenRetriever.instance` verified not deprecated
   in 0.2.2, and the plugin import is fenced to
   `screen_retriever_display_enumerator_io.dart`. Its four federated packages
   (`_platform_interface`, `_macos`, `_windows`, `_linux`) arrive in the
   lockfile; anything else that moves is reported, not committed.
   `desktop_multi_window: ^0.2.0` is already declared (Phase 1). `window_manager`
   is removed (D-13). **Any other dependency need is BLOCKED, not a fix** (run
   configuration). **(recommended)**

B) Other (write in)

[Answer]: A — the FD's SECURITY-10 record + run-configuration scope fence
(`screen_retriever: ^0.2.2` only).

## PBT

### Q8: What is the PBT framework decision, and are FP-1..FP-5 expressible with it?

PBT-09 requires a documented framework selection. Unit 7's NFR Requirements
recorded the project's Dart PBT decision: the in-tree shim. `zip_broadcast`
carries its own copy at `test/helpers/pbt.dart` (verified above: 100 trials,
`Random(seed)` for `seed` in `0..99`, async bodies, `combine2..6`,
`listWithLengthInRange`; no shrinking). There is no `glados` in any
`pubspec.yaml` and Q7 forbids adding one.

A) **PBT-09 decision: the in-tree shim `packages/zip_broadcast/test/helpers/`
   `pbt.dart` is this unit's PBT framework**, re-affirming the project-wide
   Dart decision for the `zip_broadcast` copy. Expressibility of the FD's
   FP-1..FP-5 with that shim — checked property by property:
   1. **FP-1 (codec round-trip)**: expressible — a `Generator<CaptionOverlaySnapshot>`
      (and `Generator<OverlayWindowLaunch>`) over generated activity, 0..max
      entries, any settings value, multibyte caption text; the body asserts
      `decode(encode(x)) == x`.
   2. **FP-2 (codec total-on-error)**: expressible — a `Generator<String>` of
      malformed inputs (truncated JSON, wrong field type, unknown `v`, unknown
      enum for `activity`/`settings`/`position`/`mode`, over-size payload);
      the body asserts `decode` returns `null` and never throws.
   3. **FP-3 (frame conversion)**: expressible — a `Generator` of
      (platform, frame, primaryFullHeight, displayScaleFactor) tuples over the
      three platforms, including 0/missing scale → 1, a non-primary macOS
      target, and negative-result cases; `toPlatformFrame` is a pure function
      (no I/O, per the FD), so no fake is needed.
   4. **FP-4 (open resolution)**: expressible — a `Generator` of display lists
      (0..n, any primary placement) × persisted id (present/absent/empty);
      **implementation directive**: the BR-U8-07 resolution must be a pure
      function (list + persisted id → resolved target + keep/clear decision)
      so the property can call it directly; NFR Design should name it.
   5. **FP-5 (state machine closure)**: expressible — a stateful suite in the
      `viewer_session_state_machine_properties_test.dart` /
      `broadcast_session_state_machine_properties_test.dart` shape: the Glados
      body generates an event-sequence command, executes it against a real
      `OverlayWindowController` on the Q1 fakes **inside `fakeAsync`** (the
      ready-timeout `Timer`), and checks after every command that only declared
      `ExternalDisplayStatus` variants are reached, the closed invariant
      (BR-U8-15) holds wherever `overlayEnabled` is false, and a second
      concurrent open is refused (BR-U8-01). Sequences of varying length,
      including the empty sequence.
   **No property requires a fallback** (no `glados`, no new package). The
   shim's limits are recorded, not hidden: seeds are fixed (`0..99`) so every
   run is deterministic and reproducible by seed index, and there is **no
   automatic shrinking** — a failing trial reports its seed; the minimal case
   is reduced by hand and pinned as an example test (PBT-10). Example-based
   tests keep the named cases explicit per PBT-10: the macOS negative-Cocoa-y
   flip, Windows at 1.5x, the mixed-DPI setup, the three close paths, the
   T1-T17 table, the BR-U8-20 wiring test, and the position-selector
   persistence. **(recommended — records the already-made project decision
   against this package's own shim copy; every FP is expressible, so no
   fallback is needed)**

B) Other (write in)

[Answer]: A — Unit 7 NFR Requirements' recorded Dart PBT decision (same shim
shape in `zip_broadcast`); all five FPs checked expressible above.

## Usability / Accessibility

### Q9: How is NFR-5.1 (WCAG AAA 7:1 on the external display) made a testable requirement, and how is the status conveyed without colour?

S-20's last AC and NFR-5.1 require 7:1 contrast for caption text on the
external display. BR-U8-20 already fixes the mechanism: colours from
`AppTheme`'s `surface`/`onSurface`, no literals, and the ratio itself is
**already asserted** in `zip_core/test/pbt/theme_contrast_test.dart` — this
unit must not repeat it (a second copy of the same two constants cannot fail
independently). BR-U8-26 makes the surface opaque, because whatever is behind
the window would otherwise undermine the ratio.

A) **NFR-5.1 as a wiring requirement with two tests:** (1) the BR-U8-20
   widget test — build `OverlayWindowApp` with the dark attachment, swap to
   the light `themeModeSetting` in a new snapshot, and observe the rendered
   surface colour change; it fails if the overlay introduces a colour literal
   and stays green when the theme's own ratio changes; (2) an opaque-surface
   test — build with the shipped `OverlayConfig.opacity` default (0.9) present
   in the config and assert the rendered surface is opaque (alpha 255) in
   external display mode, i.e. the opacity is not applied (BR-U8-26). The AAA
   ratio itself stays owned by `zip_core`'s contrast test (single source of
   truth). **Status without colour** (the NFR-5.2 analogue for the controls):
   every `ExternalDisplayStatus` variant is distinguishable by text/icon, never
   colour alone — the "Active" pill and "· disconnected"/"· selected" meta
   lines, the "waiting for display" status line with its Cancel action, and
   the fixed-copy failure banner (frontend-components.md). All new copy is ARB
   externalized (English source), per the project's localization convention;
   no string literal in the two components. **(recommended — gives S-20's
   contrast AC a mechanical assertion without duplicating the ratio test the
   review recorded as a defect when it was duplicated)**

B) Repeat the AAA ratio assertion in `zip_broadcast`
C) Other (write in)

[Answer]: A — BR-U8-20/BR-U8-26 as written in the FD (the review recorded the
duplicated assertion as the defect); NFR-5.2's colour-independence principle
applied to the controls' states.

## Approval

All nine questions answered under the run-configuration pre-approval: seven by
the review comment / A7 / the FD directly, two (Q5's manual-check list, Q9's
test split) by the run configuration's device policy and the FD's own rules.
No answer required a follow-up clarification, and no question was left open.
Recorded in `audit.md` with the approval line and carried into
`nfr-requirements.md`, `tech-stack-decisions.md`, and `handoff-summary.md`.
