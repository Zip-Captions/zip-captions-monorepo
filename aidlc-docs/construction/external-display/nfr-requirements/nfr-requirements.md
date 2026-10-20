# NFR Requirements — External Display (Unit 8, S-20)

**Prior stage**: Functional Design (revised), approved 2026-10-20.
**Answers recorded**: 2026-10-20 under the run-configuration pre-approval
(`approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review`).
Design input: the PR #37 review comment (2026-10-19,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>)
plus the A7 follow-up (6282213636).

## Scalability

N/A (NFR-2). No new capacity, concurrency, queue, or resource pool. At most one
secondary window (BR-U8-01), one display-list subscription, and one method
handler on the main engine (BR-U8-23). No limit of this unit's own is defined;
the source buffer the window mirrors is capped by the shipped
`maxBufferSegments` (2000, `OnScreenCaptionTarget` default). A multi-display
setup is a configuration of one window, not a scaling axis.

## Performance

The unit owns no network latency — it has no backend and no network; the window
boundary is a local platform channel. Its concrete targets, all derived from
the FD:

- **Display enumeration** (BR-U8-05 + the event contract): at most **one**
  `getAllDisplays()` platform query per platform event (re-query-and-diff on
  `display-added`/`display-removed`), and **zero** periodic polls (the adapter
  never synthesises a poll). Adjacent equal lists are coalesced, so a no-change
  event produces **zero** emissions. Testable against `FakeDisplayEnumerator`
  (first emission to a late subscriber; connect; disconnect; rearrangement
  emits; no-change does not; platform error → fixed `warning` log, stream stays
  open and does not close).
- **Window open including the handshake** (B-6, BR-U8-23): the open sequence is
  exactly `createWindow` → `setFrame` → `show` (three plugin calls); open
  completion is **bounded by the `overlayReadyTimeout` constant, 10 s** —
  success on `overlayReady`, `OpenFailed(ready_timeout)` at the bound, and no
  path may hold `Opening` longer than the bound. No snapshot is sent before
  ready (B-5); the window shows the standby surface from `show` until the first
  snapshot renders, and the first visible frame is already on the target
  display at work-area size (B-6).
- **Snapshot delivery cadence** (business-logic-model §3): a caption event
  triggers at most **one** `captionUpdate` per animation frame (60 Hz → at most
  60 pushes/s) regardless of the upstream recognition event rate. Every encoded
  payload is under **`maxEncodedBytes` = 16 KiB** (the `CaptionWireCodec` /
  `SignalingCodec` precedent: UTF-8 byte length of the full encoded payload,
  including nested fields and multibyte characters — BR-U8-24). The snapshot
  build is O(visible final captions); the buffer cap is the shipped
  `maxBufferSegments`.
- **State-machine responsiveness**: every event (toggle, `changes` emission,
  ready, timeout, `WindowClosed`, Cancel, recognition activity change) is
  processed in a single synchronous span — no timer other than the
  ready-timeout one, no `await` inside a transition, the open guard
  serialising open/close/reframe (BR-U8-01). Testable: FP-5's stateful suite
  asserts the closed invariant (BR-U8-15) and the single-window invariant after
  **every** generated command.

**Not machine-verifiable** (run-configuration device policy: no device, no
second display — recorded as **Unit 9 manual checks**, not claimed verified):

- display placement and work-area framing on real multi-monitor hardware,
  including fractional scaling and Wayland (the FD records the remaining
  cross-backend discrepancy as unreconciled by design);
- borderless rendering on all three platforms (including "borderless applied on
  macOS", settled in A7);
- the reopen-on-reconnect flow with a real hot-plug;
- closing the window by OS shortcut (the `'-1'` code path on a real OS close);
- B-4's sub-engine plugin-registration completeness ("Confirm by running the
  overlay on macOS").

## Reliability (NFR-4.1 — never crash)

- **Q3 (A)**: one shared private release helper on the controller
  (`_release(Logger)`-shaped) attempts every step in order — `closeWindow`
  (idempotent), target deregistration, display-subscription cancel, window-id
  nulling, `isVisible` false — each individually caught and logged (fixed
  string + exception `runtimeType` only, per Q6), never throwing. The terminal
  transition (`Off`, `Failed(reason)`, or `WaitingForDisplay` on the
  display-lost path) always happens last and unconditionally. The display-lost
  path (T10) shares the helper: the window is released, *then*
  `WaitingForDisplay(savedId)` is entered with **`overlayEnabled` still
  `true`** (D-4) — the output stays on while waiting; waiting is indefinite by
  design, with **Cancel** (T12) as the only exit besides the saved display
  reappearing (T11).
  - BR-U8-02's four-part invariant (window id null; `isVisible` false; target
    not on the registry; no open subscription) is restated as a **directly
    asserted** property inside FP-5, checked after every command where
    `overlayEnabled` is false (BR-U8-15).
  - A half-open window from the timeout path is closed idempotently (BR-U8-03)
    — the same helper, so a throwing `closeWindow` cannot strand the state
    machine in `Opening`.
  - `createWindow` throwing (T6) maps to `Failed(create_failed)` with
    `overlayEnabled` reverted to `false` — example tests, not just a claim.
- **Q3 (A), sub-engine side**: a `captionUpdate` or launch argument that fails
  to decode is total — the launch decode failure renders the fixed "Window
  unavailable" frame and never sends `overlayReady` (the main engine's timeout
  converts it to `OpenFailed`, BR-U8-03); a `captionUpdate` decode failure is
  dropped and the last good frame is kept. Neither path throws out of a method
  handler, because an unhandled exception in a secondary engine's method handler
  can tear down that engine (BR-U8-19).
- **Q4 (A)**: the ready handshake is the single owner of the open's success
  determination. `overlayReadyTimeout` = **10 s** as a named `const Duration`
  in `zip_broadcast` (BR-U8-23's "~10 s" read as its own number — see ASSUMPTIONS).
  Expiry is `OpenFailed(ready_timeout)`; a ready that arrives after expiry is a
  no-op. The main engine has exactly one `DesktopMultiWindow.setMethodHandler`,
  installed by the controller **before** the first `createWindow`; a sub-engine
  that dies before installing its handler is caught by the same timeout, not by
  a separate mechanism. Close detection after ready is the `'-1'`
  `PlatformException` code only (BR-U8-04), which the controller must convert
  to `WindowClosed` without ever propagating into the shell's `unawaited` calls.
- **Q1 (A)**: the ready-timeout `Timer` is driven by `fakeAsync` in unit tests
  and in FP-5's stateful suite — no injectable clock seam, no time source the
  controller does not already own (the `supabase_auth_service.dart` / Unit 5/7
  precedent).

## Testability (NFR-7.3 — testable with fakes, without a network)

- **Q1 (A)**: `OverlayWindowController` is tested entirely against fakes:
  `MockDesktopWindowService` **extended with `setFrame`/`show`** in the existing
  `test/helpers/mock_desktop_window_service.dart` (B-6, the interface's
  additive methods land in Code Generation); a hand-written `FakeDisplayEnumerator`
  (scriptable `displays()` result + a broadcast `changes` stream the test
  pushes display lists into) following the existing `test/helpers/` naming; and
  the `OutputTargetSettings` notifier via the standard provider override. The
  controller's own logic — state machine, open guard, handshake, held snapshot,
  release helper — runs real against those fakes. No `desktop_multi_window`, no
  `screen_retriever`, no runner, no device, no second display, no network.
- **Q2 (A)**: widget tests follow the Unit 6/7 one-test-per-approved-state bar.
  `ExternalDisplayControls` (embedded in the shipped `OutputTargetsPanel`,
  `zb_test_harness.dart`): `Unsupported` renders **nothing** (the S-20 web
  exclusion made mechanical — the capability gate is
  `DesktopWindowService.isSupported`, never `kIsWeb`, BR-U8-11); `NoDisplays`
  copy with no toggle; `Off` rows with the "Display N" empty-label fallback
  (BR-U8-08) and meta lines; `Opening` affordance; `Open` active row with the
  live position selector; `WaitingForDisplay` disconnected banner + "waiting
  for display" + Cancel; `Failed` fixed-copy banner with no raw reason. Plus: a
  row tap writes `externalDisplayId` only (no settings write from rendering,
  BR-U8-07), and Cancel keeps the saved id (BR-U8-07). `OverlayWindowApp`
  (real `MaterialApp` + `ProviderScope` overrides): standby (theme background,
  no text), live (shipped `CaptionDisplayWidget` fed by decoded entries +
  interim, D-7/BR-U8-25), paused (frozen buffer + the `__pause__` marker row),
  the "Window unavailable" frame on launch decode failure (BR-U8-19), caption
  position top vs bottom (BR-U8-26), and the BR-U8-20 theme-wiring test
  (dark → light swap in a new snapshot observes the rendered surface colour
  change). No golden tests (this project has none).
- No new test dependency: `mocktail ^1.0.4` and `fake_async ^1.3.2` are
  already `zip_broadcast` dev dependencies.

## Security

- **Q6 (A)**: no new logging infrastructure. Every new call site (controller
  open/release/close paths, the ignored non-`'-1'` `PlatformException`s, the
  `ScreenRetrieverDisplayEnumerator`'s fixed `warning` on platform failure, the
  sub-engine's `invalid_window_arguments`) logs a **fixed string plus an error
  type** only (exception `runtimeType`), matching `BR-U3-36` and SECURITY-03.
  Never logged: caption text, the snapshot, the raw launch argument, a
  `DisplayInfo.label` inside an error message, or an exception's full
  `toString()` from a platform-channel path. The only permitted `debugPrint` is
  `desktop_multi_window`'s own (it prints methods and window ids, not argument
  contents — verified in `WindowChannel.swift`).
  - `OpenFailed.reason` is a short fixed code (`create_failed` /
    `ready_timeout`) — never a payload, never shown raw in the UI
    (frontend-components.md's `Failed` row shows fixed copy).
  - **BR-U8-18 audit requirement**: a test drives the decode-failure path, the
    open-failure path, and the release path and asserts that no log record,
    `OverlayEvent` payload, or error message contains a caption string that was
    in flight — the Unit 7 redaction-test pattern, making
    "no caption text outside the window" (logs, exception messages,
    `OpenFailed.reason`, `WindowClosed` payloads, widget keys, semantics
    labels, test failure messages) a mechanical check rather than a review
    judgement.
- **BR-U8-14 (signed-out is the only mode)** is enforced at the call sites: no
  auth provider is read anywhere in this unit's paths; no new auth call path is
  introduced; the feature behaves identically signed in and signed out.

### Security Baseline Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| SECURITY-01 (Encryption at rest/transit) | N/A | No new store. Persistence is the two existing `SharedPreferences` keys (`output.externalDisplayId`, `output.externalDisplayCaptionPosition`) via the Phase 1 mechanism — opaque display id and a UI preference, no transcript or sensitive data. No network transit: the window boundary is a local platform channel, and this unit touches no Supabase surface. |
| SECURITY-02 (Access logging on intermediaries) | N/A | No new route, gateway, or network intermediary. No backend, no network at all in this unit. |
| SECURITY-03 (Application-level logging) | Compliant (Q6) | Existing `logging` infrastructure only; fixed strings plus error type at every new call site; caption/snapshot/launch-argument exclusion restated for this unit's paths (BR-U8-18, NFR-3.3) with a redaction test as the audit. |
| SECURITY-04 (HTTP security headers) | N/A this unit | No HTML-serving endpoint. Web is excluded from this feature by `DesktopWindowService.isSupported` (BR-U8-11); the web scaffold and its headers remain deferred to Phase 5, the same treatment Unit 7 recorded. |
| SECURITY-05 (Input validation) | Compliant | The hand-written versioned codecs are the single untrusted-input boundary (BR-U8-24, B-7): total-on-error decode (`null` on malformed input, unknown `v`, unknown enum), `maxEncodedBytes` size guard on UTF-8 byte length, enums by name, exactly one `mode` source. A malformed launch argument renders the fixed "Window unavailable" frame and never renders (BR-U8-19); a malformed `captionUpdate` is dropped. Display ids are opaque strings, never labels, and are only persisted by an explicit user action (BR-U8-07/08). |
| SECURITY-06 (Least privilege) | N/A | No IAM policy, role, or database privilege defined by this unit. |
| SECURITY-07 (Network configuration) | N/A | No network configuration of any kind — no backend, no ICE, no relay. |
| SECURITY-08 (Application-level access control) | Compliant (BR-U8-14) | Signed-out is the only mode: no auth provider read, no session required, no new auth call path. The feature is available identically signed in and out (S-20, M-REG-01) — there is no authorization decision to make client-side. |
| SECURITY-09 (Hardening) | Compliant | Failures surface only as fixed `ExternalDisplayStatus` variants with fixed copy (`Failed` shows a code-derived banner, never the raw reason; `Window unavailable` is a fixed frame). No exception message, stack trace, or platform detail reaches the UI. The switch starts off at launch (D-6, BR-U8-21) — no auto-open surface at all. |
| SECURITY-10 (Supply chain) | Compliant (Q7) | Exactly one new dependency: `screen_retriever: ^0.2.2`, with its SECURITY-10 record in the FD (`screen-retriever-security-10.md`: 16 releases, SDK-floor analysis excluding 0.3.0, `ScreenRetriever.instance` verified not deprecated under the pin, single-file import fence). Lockfile change is `screen_retriever` and its four federated entries only; `window_manager` removed (D-13); any other dependency need is BLOCKED per the run configuration. |
| SECURITY-11 (Secure design, rate limiting) | Compliant | No public-facing endpoint, so rate limiting is N/A-within-rule; the misuse cases are designed out: a malformed launch argument degrades to a fixed frame + `OpenFailed` timeout, never a crash (BR-U8-19); a second concurrent open is structurally refused (BR-U8-01); a display that disappears while open is closed and released, never an orphaned window (BR-U8-22); oversized payloads are rejected by the size guard (BR-U8-24). |
| SECURITY-12 (Auth/credential management) | N/A | Manages no credential; the feature is signed-out-only by design (BR-U8-14). |
| SECURITY-13 (Data integrity) | N/A | No persisted table, row, or local record beyond the two non-sensitive settings keys; the wire shape is versioned (`v`) and the decode is total, so an old/new-engine mismatch degrades to `OpenFailed`, never to a partial or corrupted render. |
| SECURITY-14 (Alerting/monitoring) | N/A | Same standing project-wide Backlog item as every prior unit (no alerting infrastructure exists yet); this unit introduces no new security-relevant event beyond what is already deferred. |
| SECURITY-15 (Exception handling/fail-safe defaults) | Compliant (Q3) | Every release step is caught and logged individually; the terminal transition always completes, so the state machine never fails open into a stuck `Opening` or an `overlayEnabled = true` with a released window. Decode is total (never throws out of a method handler — the sub-engine cannot be torn down by its own input, BR-U8-19). Close detection converts `'-1'` to `WindowClosed` and never propagates into the UI (BR-U8-04). A failed open reverts `overlayEnabled` to `false` (BR-U8-03) — fail-closed: nothing observable is left "on". |

## PBT

### PBT-09 decision

**The framework is the in-tree shim `packages/zip_broadcast/test/helpers/pbt.dart`.**
This re-affirms the project's Dart PBT decision (recorded at Unit 7 NFR
Requirements) for the `zip_broadcast` copy of the shim: `Generator<T>`, the
`any` generators (`choose`, `boolGen`, `letterOrDigits`, `intInRange`,
`doubleInRange`, `combine2..6`, `listWithLengthInRange`), and
`Glados<T>(generator).test(description, body)` — 100 trials with
`Random(seed)` for `seed` in `0..99`, async bodies supported. Its limits are
recorded rather than hidden: seeds are fixed (a failure is reproducible by seed
index) and there is **no automatic shrinking** — a failing trial reports the
seed, the minimal case is reduced by hand, and it is pinned as an example test
per PBT-10. There is no `glados` dependency anywhere in the monorepo and Q7
forbids adding one.

### Property scope (FD's PBT-01 list, FP-1..FP-5)

All five properties are expressible with the shim; none requires a fallback.

1. **FP-1 — codec round-trip (PBT-02)**: for every generated valid
   `CaptionOverlaySnapshot` (any `activity`, 0..max entries, any `settings`
   value, multibyte caption text) and every generated `OverlayWindowLaunch`
   (any `mode`/`position`), `decode(encode(x)) == x`.
2. **FP-2 — codec total-on-error (PBT-03)**: for every generated malformed
   input (truncated JSON, wrong field type, unknown `v`, unknown enum value for
   `activity`/`settings`/`position`/`mode`, over-size payload), `decode`
   returns `null` and never throws.
3. **FP-3 — frame conversion (PBT-05/PBT-03)**: `toPlatformFrame` is identity
   on Linux; on Windows every edge equals `bounds × that display's own
   scaleFactor` (including 0/missing → 1); on macOS `y_out =
   primaryFullHeight − top − height` with `x_out = left` — for arbitrary
   top-left logical frames including a non-primary target and negative-result
   cases. The review comment's B-1/B-2 conversion rules are the oracle.
4. **FP-4 — open resolution (PBT-03)**: for any generated display list (0..n,
   any primary placement) and any persisted id (present, absent, empty), the
   resolved open target follows BR-U8-07 exactly, and an absent id is kept,
   never cleared. **Implementation directive**: the resolution must be a pure
   function (list + persisted id → resolved target + keep decision) so the
   property can call it directly; NFR Design names it.
5. **FP-5 — state machine closure (PBT-03, stateful)**: over every generated
   event sequence over the T1-T17 transition table (including duplicate and
   `changes`-coalesced no-ops, and events in any order), executed against a
   real `OverlayWindowController` on the Q1 fakes **inside `fakeAsync`** (the
   ready-timeout `Timer`), in the
   `viewer_session_state_machine_properties_test.dart` shape: only declared
   `ExternalDisplayStatus` variants are reached, the machine never holds two
   states, the closed invariant (BR-U8-15) holds at every step where
   `overlayEnabled` is false, and a second concurrent open is refused
   (BR-U8-01). Sequences of varying length, including the empty sequence.
   PBT-04's idempotence (close from an already-closed state; toggle-off from
   `Off`) is asserted inside these sequences and once directly.

Components with no identifiable properties (FD): `ScreenRetrieverDisplayEnumerator`
(thin plugin wrapper — pinned by the BR-U8-05 example/contract tests) and
`ExternalDisplayControls`/`OverlayWindowApp` (rendering — pinned by the Q2
widget tests, including BR-U8-20's wiring test).

### PBT Compliance

| Rule | Verdict | Rationale |
|---|---|---|
| PBT-01 (Property identification) | Compliant | FD `business-rules.md` carries the "Testable Properties" table: FP-1..FP-5, each with a category, and the components-without-properties are explicitly marked with rationale. |
| PBT-02 (Round-trip) | Compliant (planned) | FP-1: snapshot and launch codec round-trip across generated inputs including multibyte text and 0..max entries. |
| PBT-03 (Invariant) | Compliant (planned) | FP-2 (total-on-error), FP-4 (BR-U8-07 resolution keeps the absent id), FP-5 (closure + closed invariant at every step); the frame-conversion edge invariants ride inside FP-3. |
| PBT-04 (Idempotence) | Compliant (planned) | Close/release idempotence (BR-U8-02/03: a second close, a toggle-off from `Off`, a `closeWindow` on an already-released id) asserted inside FP-5's sequences and once directly; `DisplayEnumerator.dispose()` idempotence is part of the Q1 fake contract. |
| PBT-05 (Oracle) | Compliant (planned) | FP-3 verifies `toPlatformFrame` against the B-1/B-2 reference rules (macOS y-flip against the primary full height; Windows multiply by the target display's own scale; Linux identity) — the review comment is the oracle; there is no second implementation. |
| PBT-06 (Stateful) | Compliant (planned) | FP-5: the T1-T17 machine driven by generated event sequences against a real controller on fakes inside `fakeAsync`, checked after every command. |
| PBT-07 (Generator quality) | Compliant (planned) | Domain generators, not raw primitives: `DisplayInfo` lists (opaque ids including Linux-normalised `display-<n>`, empty labels, work-area bounds, scale factors including 0/1/1.5/2, primary flag placement), `CaptionOverlaySnapshot` (activity, entry counts 0..max, multibyte caption text, settings enum values, payloads at/over the `maxEncodedBytes` boundary), `OverlayWindowLaunch` (mode, position), malformed-input strings (truncated JSON, wrong types, unknown `v`/enums, over-size), and the FP-5 event-sequence generator. Centralized in `test/helpers/generators.dart` (the existing file) where multiple suites share them. |
| PBT-08 (Shrinking/reproducibility) | Compliant, with a recorded limit | Seeds are fixed (`0..99`) so every run is deterministic and every failure is reproducible by seed index; the shim has **no shrinking**, so the documented reduction path is hand-reducing the failing seed's input and pinning it as an example test (PBT-10). CI runs the suite via the existing `flutter test`; no PBT is excluded. |
| PBT-09 (Framework selection) | Compliant (documented above) | The in-tree shim at `packages/zip_broadcast/test/helpers/pbt.dart`; no framework package exists or is added. Re-affirms the project's Dart PBT decision for this package's copy. |
| PBT-10 (Complementary testing) | Compliant (planned) | The named example cases stay explicit: the macOS negative-Cocoa-y flip, Windows at 1.5x, the mixed-DPI setup, the three close paths, the T1-T17 transition table, the BR-U8-20 theme-wiring test, the position-selector persistence, and the Q1 fake contract tests. PBT is not the sole coverage for any business-critical path. |

## Usability / Accessibility

- **Q9 (A) — NFR-5.1 (WCAG AAA 7:1) on the external display, carried as a
  testable wiring requirement with two tests:**
  1. The **BR-U8-20 theme-wiring test**: `OverlayWindowApp` builds with the
     dark attachment, a new snapshot swaps to the light
     `themeModeSetting`, and the rendered surface colour is observed to change
     with it. The test fails if the overlay introduces a colour literal and
     stays green when the theme's own ratio is what changes. The AAA ratio of
     `AppTheme`'s `surface`/`onSurface` pairs (dark 0xFFDAE3F0 on 0xFF0B141D;
     light 0xFF0B141D on 0xFFFAFCFF) is **already asserted** in
     `zip_core/test/pbt/theme_contrast_test.dart`, and this unit does **not**
     repeat that assertion — a second copy of the same two constants cannot
     fail independently (the review recorded exactly that as the defect).
  2. The **opaque-surface test**: with the shipped `OverlayConfig.opacity`
     default (0.9) present in the config, the rendered surface in external
     display mode is opaque (alpha 255) — `opacity` is not applied (BR-U8-26),
     because whatever is behind the window would otherwise undermine the 7:1
     ratio.
- **Status without colour** (the NFR-5.2 principle applied to the controls):
  every `ExternalDisplayStatus` variant is distinguishable by text/icon, never
  colour alone — the "Active" pill and "· selected"/"· disconnected" meta lines,
  the "waiting for display" status line with its Cancel action, and the
  fixed-copy `Failed` banner (frontend-components.md). `Unsupported` renders
  nothing (no disabled placeholder), which is the S-20 web exclusion.
- **Copy**: all new strings live in `packages/zip_broadcast/l10n/arb/app_en.arb`
  (English source), then `flutter gen-l10n`; no string literal in
  `ExternalDisplayControls` or `OverlayWindowApp`. The prototype's strings are
  the English copy source (frontend-components.md "Copy" paragraph).

## No Blocking Findings

Every Security Baseline verdict is Compliant, Compliant (unchanged), or N/A
(SECURITY-04 N/A this unit — web deferred); every PBT verdict is
Compliant/Compliant(planned) or Compliant-with-recorded-limit (PBT-08's
shrinking limit is the shim's documented property, identical to the Unit 7
recording). No blocking finding under either extension.

## Notes for Code Generation

- Q1's `MockDesktopWindowService` extension and `FakeDisplayEnumerator` are
  test-helper work that lands **with** the additive `setFrame`/`show` interface
  methods (B-6) — the mock must compile against the extended interface, so the
  two steps are one step.
- Q4's `overlayReadyTimeout` (10 s) and Q5's `maxEncodedBytes` (16 KiB) are
  named constants in `zip_broadcast`, placed by NFR Design; both mirror named
  precedents (BR-U8-23's "named constant"; `CaptionWireCodec.maxEncodedBytes`).
- FP-4's implementation directive: extract the BR-U8-07 resolution as a pure
  function before writing FP-4's property — the stateful suite (FP-5) exercises
  it through the controller, but the direct property needs the pure form.
- The redaction audit test (Q6) should assert against the actual `logging`
  records (a capturing `Logger.onRecord`), not against string greps of the
  source — the Unit 7 pattern.
- B-4's sub-engine plugin registration ("register exactly what the overlay's
  code path touches; `google_fonts` (via `path_provider`) is expected. Confirm
  by running the overlay on macOS") is a Code Generation step with a **Unit 9
  manual check** for the confirmation, per the device policy — NFR Design
  carries it forward, this stage does not attempt it.
- The BR-U8-20 test is the S-20 contrast AC: Code Generation must schedule it
  as an acceptance test, not an optional one.
