# NFR Requirements — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (revised after the pre-build review: RQ-1 A / RQ-2 A / RQ-3 A-amended; revision 2 same day).
**Answers carried**: Q1 A (macOS full registrant, Windows/Linux per-plugin), Q2 A
(`window_manager` in `zip_core` only), Q3 A (router: unit + two-controller + moved suite), Q4 A
(assert the seam; floating is Unit 9), Q5 A (per-app tests), Q6 A (accept the adapter duplication,
constrain by matching tests), Q7 A (inherit Unit 8's numbers + two ordering targets), Q8 A (fail
closed except always-on-top), Q9 A (one redaction audit per app), Q10 A (in-tree shim, POP-1..POP-6
and POP-8), Q11 A (rename/diff checks), Q12 A (label + semantics + visible reason), plus
clarification Q1 A (bootstrap seam for `zip_captions`'s main routing).
**Binding contract**: `pip-ux-parity.md` §8, as amended by the approved Q9 decision (75% width, two
rendered lines, bottom-anchored).

---

## 1. Testability

### 1.1 Strategy per layer

| Layer | Technique | Why this layer is testable |
|---|---|---|
| Promoted controller, codec, geometry, availability, router | Real classes on hand-written fakes (`DesktopWindowService`, `DisplayEnumerator`, `OverlayMethodHandlerInstaller`, `WindowConfigurator`) + the in-tree PBT shim | No plugin object is constructed anywhere in the suite (Unit 8's rule, inherited) |
| `OverlayMethodRouter` | Unit tests + a two-real-controller test with one recording installer | The failure mode being guarded (silent misrouting) is only visible with two controllers |
| Both window bodies (`OverlayWindowApp`, `PopOutWindowBody`) | Widget tests with an injected `ValueNotifier` snapshot and injected copy | The widgets take no `BuildContext`-derived settings and no ARB |
| Both apps' toggles, banner, availability rendering | Widget tests inside each app's own `ProviderScope`, one per §8.8 item per app | §8.8's per-app clause is enforced by the test tree, not by memory |
| `WindowConfigurator` | A fake configurator + the seam assertions in §1.2 | The call's effect is platform-observable only; see Unit 9 |
| Sub-engine entry | `overlayWindowMain` with an injected bridge, pump and installer | The ordering (install before ready) is the contract |
| `zip_captions` main routing | `runZipCaptions(args, runApp:)` in `lib/src/bootstrap.dart` with a recording `runApp` | Makes BR-U8.1-06 literal |
| Runners (native) | Compile only: macOS via `flutter build macos --debug`; Windows/Linux via CI `build-verify.yml` | No toolchain locally for the latter two; stated, not claimed |

### 1.2 Window configuration: exactly what the suite asserts (Q4 A, amended 2026-10-21)

The seam is a `WindowConfigurator` (a native `configure` channel call), not a `window_manager`
installer — RQ-1 A removed the dependency. The suite asserts four things and nothing about visible
floating:

1. For a `PopOutMode` launch, `configure` is awaited **once**, with `floating: true` and
   `decorated: true`, and **before** `overlayReady` is sent (ordering asserted through a recorder
   that appends to one list).
2. For an `ExternalDisplayMode` launch, `configure` is called with `floating: false` and
   `decorated: false` — pinned, matching tech-stack §2. **Consequence to record**: Unit 8's
   borderless surface now depends on `configure` succeeding; if it fails, the external display
   window is decorated (cosmetic, logged fixed string, no state change, and no `OpenFailed`). The
   test asserts the call and its arguments; it does not assert the native result.
3. A configurator that throws still results in `overlayReady` being sent (a cosmetic failure must
   not block the window).
4. The production configurator is not constructed in any test; the test platform's exported
   `windowConfigurator` (the `_stub`) is a no-op.

**The close notification** (RQ-3 as amended, transport corrected 2026-10-21): the runner — not the
sub-engine — raises `subWindowClosed {windowId}` on a **first-party channel registered on the main
engine**, because `desktop_multi_window`'s window channel is plugin-internal (macOS
`WindowChannel.swift:14` is not `public`; Windows/Linux expose only the plugin header) and cannot be
emitted on by a runner. A main-engine Dart seam (`SubWindowClosedChannel`, `_io`/`_stub`, fake in
tests) delivers it to `controller.onNativeWindowClosed(int windowId)`, which is listed as a
permitted BR-U8.1-01 deviation. It does **not** flow through `OverlayMethodRouter` or
`_handleWindowCall`. Tested in `zip_core` with the fake: an id matching the open window produces
`WindowClosed` and clears the shell flag; an id matching no window is dropped; an app-initiated close
followed by a late native event is dropped (the id was nulled by `_takeWindow()`). Raised for the
external display too, which is recorded as a Unit 8 improvement, not a change to its states. The
`'-1'` fallback keeps its Unit 8 tests unchanged.

Explicitly **not** asserted: that the native window ends up floating. That is §8.8 item 15, a Unit 9
manual check on real desktops, including the Linux "the WM enforces it" caveat and the accepted
macOS `NSFloatingWindowLevel` limitation.

### 1.3 Per-app evidence (Q5 A)

Every claimed §8.8 item that is app-level is tested **in both apps'** test trees:

| Item | Test location |
|---|---|
| 1 chrome toggle exists, both labels, reflects state | `zip_broadcast/test/shell/…`, `zip_captions/test/shell/…` |
| 2 in-surface toggle exists and is usable from the pop-out | both apps (widget test drives the bridge callback) |
| 3 visibility rule, all combinations | both apps, driven by the shared `popOutAvailability` table |
| 5 disabled with reason, no session | both apps |
| 6 disabled with reason, no engine | both apps |
| 7 hint + return, clears on close | both apps |
| 11 opening closes the drawer | both apps (the drawer belongs to each shell) |
| 14 only one pop-out; double toggle | both apps (plus the shared stateful PBT) |
| 18 no caption text in logs | both apps (`<app>_pop_out_redaction_test.dart`) |
| 4, 12, 13, 15, 16, 17 | Unit 9 platform checks, recorded as such |
| 8, 9, 10 | deferred to Phase 8 (translation), recorded as such |

`zip_core` carries the shared behaviour (codec, geometry, availability predicate, router, both window
bodies). It never carries an app-shell test.

### 1.4 Test doubles required

| Double | Package | Shape |
|---|---|---|
`FakeWindowConfigurator` | `zip_core/test/helpers/` | records calls into a shared ordering log, including the `OverlayWindowConfig` fields and window id; can be told to throw |
| `FakeOverlayMethodHandlerInstaller` | `zip_core/test/helpers/` | same shape as Unit 8's proposed helper; records install/uninstall and lets a test invoke the handler |
| `FakePopOutBridge` | `zip_core/test/helpers/` | records `send`/`sendPopOutToggle`, can push a `captionUpdate` |
| overlay generators | `zip_core/test/helpers/overlay_generators.dart` | the FD's noted duplication; adds `arbitraryPopOutGeometryInput`, `arbitraryPopOutModeLaunch` |
| `FakeSttEngineRegistry`-equivalent | each app's existing helper | an empty registry is achieved by not registering; no new double needed |

No `mocktail` mock is required for the new seams; hand-written fakes are the established pattern for
collaborators that carry behaviour (Unit 5/6/7's convention).

---

## 2. Performance

Inherited from Unit 8 and unchanged:

| Target | Value | Source |
|---|---|---|
| Caption delivery cadence | ≤1 `captionUpdate` per 16 ms (`captionUpdateInterval`) | Unit 8 P1 |
| Snapshot payload | ≤ `maxEncodedBytes` (16 KiB UTF-8) | Unit 8 BR-U8-24 |
| Open bound | ≤ `overlayReadyTimeout` (10 s) to `Open` or `Failed` | Unit 8 R3 |
| Display enumeration | ≤1 `getAllDisplays()` per platform event, 0 polls | Unit 8 NFR |
| Window calls | no polling; every call event-driven | Unit 8 R4 |

New to this unit (Q7 A), both stated as ordering targets rather than numbers:

| Target | Meaning | How checked |
|---|---|---|
| Toggle press → `Opening` in the same frame | the shell's toggle does no `await` before `controller.open()`; `open()` sets `Opening` synchronously before its first await | a test that presses the toggle and asserts `status is Opening` immediately after `tester.pump()` with no timer advance |
| Always-on-top applied before the window is shown | the sub-engine awaits the installer before sending `overlayReady`; the main engine only calls `show` after ready | the installer-ordering recorder in §1.2 |

No startup budget is asserted (Q7 A rejected B). A pop-out engine's cold start is bounded in practice
by the ready timeout, which already fails the open rather than hanging.

**Two-line geometry cost**: `popOutSize` is a pure computation over the resolved `TextStyle`; it runs
once per open, not per frame. `PopOutWindowBody` rebuilds only when the snapshot `ValueNotifier`
changes, the same as `OverlayWindowApp`.

---

## 3. Reliability

### 3.1 Failure policy (Q8 A)

| Failure | User-visible result | Retry |
|---|---|---|
| Platform cannot host a window (`Unsupported`) | control not rendered | n/a |
| No engine / no session | control disabled with reason | n/a |
| Handler missing on a capable platform | `create_failed` → `OpenFailed` → banner, flag cleared | next toggle |
| `createWindow` throws | `create_failed` → same | next toggle |
| Ready handshake times out | `ready_timeout` → same | next toggle |
| Window disappears (`'-1'`) | `WindowClosed` → flag cleared, hint gone | n/a |
| `setFrame`/`show` throws non-`'-1'` | logged fixed string, ignored | n/a |
| native `configure` fails | **window still opens and works**, possibly undecorated/not floating; fixed-string warning | none (by design) |
| native `subWindowClosed` for an unknown id | dropped (no state change, no log at info and above) | n/a |
| `captionUpdate` decode fails | dropped, last frame stays | next update |
| `popOutToggle` from a stale window | ignored | n/a |

Rule: the only failure that is *not* fatal to the open is the window-configuration call, because a
window that is not on top is still a usable pop-out, while an `OpenFailed` dialog for a working
window is worse. This is a deliberate asymmetry, not an oversight, and is the direct answer to the FD's
"no path leaves a window registered without a state that explains it": the window's state does
explain itself, it just lacks one property.

No retries anywhere. Unit 8's reasoning is inherited: the toggle is the retry, and an automatic
retry loop around a native window call is how orphaned windows happen.

### 3.2 Resource discipline

- Two controllers per main engine, one enumerator shared between both (and with the window service).
  The enumerator opens **one** platform observer; `dispose` is idempotent.
- The router holds at most two handlers and uninstalls the static slot when the last leaves. Each
  controller's `dispose()` removes only its own token-bound handler (R-M3).
- The pop-out sub-engine owns one window and no timers of its own (the controller's timers live in
  the main engine).
- `zip_captions`' shell becomes stateful and must unregister its target and cancel its event
  subscription in `dispose`, exactly as `ZbAppShell` does.

### 3.3 Continuity

BR-PIP-04 is asserted twice per app: the recording state is unchanged across toggle-on and
toggle-off, and the buffer keeps growing while popped out.

---

## 4. Security

### 4.1 Surface

- **Data egress**: none new. `window_manager` opens no socket and has no telemetry (SECURITY-10 §5).
- **Caption content**: crosses only the existing window boundary, inside `captionUpdate` and the
  launch payload, both already size-capped and already redacted from logs. The new `popOutToggle`
  message carries no payload. New log sites carry fixed strings and `runtimeType` only (BR-PIP-11).
- **Input validation on the window boundary**: decode remains total-on-error and size-capped
  (Unit 8 BR-U8-24); the mode token is validated (unknown → `null`, BR-U8.1-08); `popOutToggle` is
  accepted only from the current window id.
- **No new network endpoint, no credential, no token, no key**. No RLS, no server change.
- **Supply chain**: two plugin entries placed per Q2 A (`desktop_multi_window`, `screen_retriever`);
  the lockfile fence is in `tech-stack-decisions.md`. `window_manager` is not added at all
  (RQ-1 A, 2026-10-21), which removes SECURITY-10's supply-chain question entirely.
- **Permissions**: none. Neither plugin requests a platform permission; the macOS app already ships
  the entitlements it needs, and `window_manager` adds no entitlement requirement (no
  `NSWindow`-level capability is gated).
- **Fail-closed**: a platform that cannot host a window shows nothing rather than a dead control;
  a missing handler fails the open. The one non-fail-closed path (always-on-top) is cosmetic and
  cannot expose data.

### 4.2 Security Baseline compliance

| Rule | Status | Reason |
|---|---|---|
| SECURITY-01 Encryption at rest/in transit | N/A | No data store added or touched |
| SECURITY-02 Access logging on network intermediaries | N/A | No intermediary |
| SECURITY-03 Application logging | Compliant | Fixed strings + `runtimeType`, per app audit (§1.3 item 18); no new logger infrastructure |
| SECURITY-04 HTTP security headers | N/A | Web is out of scope (BR-U8.1-11) |
| SECURITY-05 Input validation | Compliant | Codec total-on-error + 16 KiB cap + validated mode token; `popOutToggle` payload-free and window-id-checked |
| SECURITY-06 Least-privilege policies | N/A | No IAM |
| SECURITY-07 Network configuration | N/A | No network config |
| SECURITY-08 Application access control | N/A | No endpoint, no resource access |
| SECURITY-09 Hardening | Compliant | Failure copy generic; no raw `Failed` code shown to the user; no debug/sample surface added |
| SECURITY-10 Supply chain | Compliant | No new third-party dependency: `window_manager` was withdrawn (RQ-1 A, 2026-10-21) and `desktop_multi_window`/`screen_retriever` are already vetted (`screen-retriever-security-10.md`). Placement avoids unused declarations (Q2 A); lockfile fence named; the new native channel is first-party code in our own runners |
| SECURITY-11 Secure design | Compliant | Separated concerns (machinery in `zip_core`, UI per app), one implementation, fail-closed default |
| SECURITY-12 Authentication | N/A | Untouched |
| SECURITY-13 Integrity | Compliant | Decode is allowlist-based (enum-by-name, known version, known mode token); no unsafe deserialisation |
| SECURITY-14 Alerting/monitoring | N/A | Project-wide deferral already recorded in Backlog |
| SECURITY-15 Exception handling | Compliant | Every platform call caught and mapped; release never throws; no unhandled future in any `unawaited` path (Unit 8 R1/R4 inherited) |

**No blocking security findings.**

### 4.3 Accepted limitations (recorded, not fixed)

| Limitation | Why accepted |
|---|---|
| macOS pop-out does not float above another app's full-screen window | `NSFloatingWindowLevel`; `NSPanel` work in Backlog (accepted 2026-10-20). Unchanged by RQ-1 A: the native channel sets the same level. |
| Native channel code lives in six runners and cannot be unit-tested | Two apps x three platforms; Windows/Linux are compile-checked by CI (after R-B4's fix), macOS by a debug build; behaviour is a Unit 9 manual check (accepted 2026-10-21 with RQ-1 A) |
| Linux always-on-top depends on the window manager honouring `gtk_window_set_keep_above` | Platform behaviour, not application-controlled; Unit 9 checks on a real desktop |
| ~~macOS sub-engine receives the app's whole plugin set (Q1 A)~~ **Withdrawn 2026-10-21 (R-B1)** | The premise was wrong. Never use `RegisterGeneratedPlugins` in the window-created callback: `FlutterMultiWindowPlugin.register(with:)` calls `attachMainWindow`, which overwrites `windows[0]` with the sub-engine's channel, routing every `invokeMethod(0, …)` — `overlayReady` included — back into the sub-engine. Every open, Unit 8's included, would end in `ready_timeout`. The runners register the app's own single `configure` channel instead, as the plugin's examples register one named plugin. |

---

## 5. Maintainability

### 5.1 The move must be provably mechanical (Q11 A)

Three checks, recorded in the code summary:

1. `git diff -M --find-renames --summary` on the move commit: every moved file is `R100` except the
   rows of the FD's additive-change table.
2. Every file with a non-rename diff maps to a row in that table; the summary lists the mapping.
3. The greps: `package:desktop_multi_window`, `package:window_manager`, `package:screen_retriever`
   over `packages/*/lib` return exactly the expected `_io` files; no app file matches.

### 5.2 Naming and placement

- The promoted code keeps its class names, file names and logger prefixes become `zip_core.…`.
- **R-M7 resolved (2026-10-21)**: the barrel is a **separate public library**,
  `package:zip_core/overlay.dart`, and `zip_core.dart` does **not** re-export it. Exporting the
  overlay barrel from `zip_core.dart` is a compile error, because that library already exports
  `Failed` (`ConnectionStatus`, `connection_status.dart:74`, through `models.dart:20`) and
  `ExternalDisplayStatus` has a variant of the same name; every importer would get an
  ambiguous-export error. The shipped code already works around the collision by aliasing
  (`overlay_window_controller.dart:13-14`).
- The barrel exports the public surface only (controller, modes, codec, snapshot, status, events,
  activity, enumerator, display info, config/position, entry, configurator, router, geometry,
  availability, bridges). It does **not** re-export `desktop_multi_window`.
- `zip_broadcast`'s two model files become one-line `export` shims with a comment naming the
  condition for their deletion.

### 5.3 Documentation hygiene

- No `// ignore` added (project rule).
- The `OverlayWindowUnavailableApp` copy parameter is named `message`, not `l10n`, so `zip_core`
  carries no illusion of a localisation system.
- Every new branch that exists for a mode difference carries a one-line comment naming the mode and
  the rule it serves.

---

## 6. Usability and accessibility (Q12 A)

| Requirement | Implementation |
|---|---|
| Visible label on both toggles | `TextButton.icon` with the ARB label, not an icon-only button |
| Accessible name + state + reason | `Semantics(button: true, enabled: …, label: …, hint: reason)` |
| Reason also visible | adjacent `Text`, so sighted users do not depend on a tooltip |
| Hit target | ≥44x44 logical px in both windows, including the two-line pop-out |
| No colour-only state | icon **and** label change on pop-out; the banner uses text |
| Keyboard | the toggles are `TextButton`s, so they are already tab-reachable and space/enter-activatable |
| Text scaling | the pop-out's height is computed from the scaled line height, so two lines still fit at large accessibility scales; the banner wraps |
| Screen-reader announcement on open/close | **not implemented** (nothing in §8 asks for it); recorded here so it is a decision, not an omission |

---

## 7. Scalability

N/A, restated from Unit 8: no queue, pool, cache or concurrency axis is introduced. At most two
windows per engine, at most two handlers in the router, one enumerator, one 16 ms timer per open
window.

---

## 8. PBT compliance

| Rule | Status | Notes |
|---|---|---|
| PBT-01 Property identification | Compliant | FD `domain-entities.md` §5, POP-1..POP-8 |
| PBT-02 Round-trip | Compliant | POP-1 (launch), POP-6 (mode token); codec's existing snapshot round-trip moves |
| PBT-03 Invariants | Compliant | POP-2 (totality), POP-3 (size bound), POP-4 (geometry), POP-8 (frame conversion) |
| PBT-04 Idempotency | Compliant | router `unregister` no-op, controller `close` idempotence already covered by the moved suite; geometry is a function of inputs only |
| PBT-05 Oracle/model | N/A | No reference implementation exists; `resolveOpenDisplay`'s FP-4 property remains the oracle-free invariant form |
| PBT-06 Stateful | Compliant | POP-5: Unit 8's `_World` harness moves and gains pop-out commands |
| PBT-07 Generator quality | Compliant | domain generators in `overlay_generators.dart` (snapshots with multibyte text, launches by mode, geometry inputs with scale factors 0/1/1.5/2, text scalers, display lists with at most one primary) |
| PBT-08 Shrinking/reproducibility | Compliant with the recorded limit | the in-tree shim uses 100 fixed seeds and **no shrinking** — the project's standing Dart decision (Unit 7 NFR Requirements, re-confirmed by Unit 8). Failure output prints the seed |
| PBT-09 Framework | Compliant | in-tree `test/helpers/pbt.dart`, no new package |
| PBT-10 Complementary | Compliant | POP-7 is an exhaustive example/table test, not generated; every claimed §8.8 item has an example-based test |

**No blocking PBT findings.** PBT-08's no-shrinking limit is pre-existing, project-wide and recorded,
not introduced here.

---

## 9. Deferred and not-claimed register

| Item | Status | Reason |
|---|---|---|
| §8.8 8, 9, 10 | Deferred | Translation is Phase 8 |
| `PopOutContentMode` picker | Deferred | Same |
| §8.8 4, 12, 13, 15, 16, 17 | Unit 9 platform checks | §8.8's own partition |
| Size/position memory | Not implemented | §8.9 "permitted, not required"; Q10 B |
| Web Document PiP | Phase 5 | §8.6 |
| Screen-reader announcement on open | Not implemented | Not required by §8 |
---

## 10. Review decisions (2026-10-21, owner + agent, during the NFR Requirements review)

The three questions the handoff carried to NFR Design were resolved here instead, because each one
decides a testable shape that NFR Requirements already has to state.

### 10.1 Router and enumerator ownership (Q1 -> A1)

A `@Riverpod(keepAlive: true)` provider in `zip_core` owns the `OverlayMethodRouter` and the single
`ScreenRetrieverDisplayEnumerator`, and exposes `createController(...)`. Each app's controller
provider becomes two calls with different mode arguments and does not construct an enumerator, a
window service or an installer itself.

Reasoning: the shipped provider creates the enumerator and hands it to *both* its window service and
its controller, with a comment explaining that a second instance would open a second platform
observer that nothing disposes. Repeating that construction in two apps repeats the invariant. A
provider in `zip_core` is not foreign to the package — `captionBus` and `captionOutputTargetRegistry`
are already keepAlive providers there.

Consequence for the constructor: `createController` takes the mode and the logger prefix, and
supplies both the window service and the open handshake's always-on-top mode from the router it
owns. Neither app passes `handlerInstaller`, `enumerator` or `windowService`.

### 10.2 Two consequences of `PopOutMode` on the controller (found while reviewing Q2)

- `_bootstrap()` today settles on `Unsupported` when `_windowService.isSupported` is false. For
  `PopOutMode` that judgement must not depend on the display list: a pop-out needs no display, so a
  headless or display-less machine must still be able to pop out. The bootstrap rule becomes
  `isSupported && (mode == popOut || displaysAvailable)`, and its test is the display-less case with
  a pop-out request.
- `_modeDisplayId` is a display-mode field. `PopOutMode` leaves it `null`.
  ~~so the close path's display-lost branch is a no-op for pop-out~~
  **WRONG — withdrawn 2026-10-21 (R-M2).** `_find(null)` returns the primary or first display
  (`overlay_window_controller.dart:275-281`), so a null id is *not* inert. Six paths consult it and
  each needs an explicit `_isPopOut` guard: the `Open` T15 re-frame (`:225-238`), the `Open`
  display-lost close, the `Opening` empty-list fail (`:239-243`), `_runReady`'s frame (`:402-411`),
  and `open()`/`_runOpen`'s `NoDisplays` (`:309-314`, `:345-353`). The test is the display-less and
  display-removed cases with a pop-out open, asserting the window stays open and keeps its frame.
  See FD `business-logic-model.md` §2 for the table.

Also: the mode is supplied at **construction**, not read from the config at `open()` (§10.1 wins;
`open()`'s config mode is validated against it and a mismatch fails as `create_failed`).

### 10.3 Main-window-centre parameter (Q2 -> C)

`computePopOutFrame`'s nullable main-window-centre parameter stays `null` in production this unit.
The pop-out opens on the primary display's work area, centred horizontally, bottom-anchored. The
parameter is exercised through a fake in the geometry tests and by no real caller. Multi-monitor
placement is recorded as a Unit 9 platform check, in the same list as the always-on-top floating
check, so it is judged on a real multi-monitor desktop rather than guessed.

Reasoning: a main-window-geometry call would make this cheap, but it adds a platform call on the
open path for behaviour that has not been seen on a real multi-monitor setup, and such a call can
throw before the main window is ready — a third failure mode on an already-bounded open sequence.
(Originally this cited `window_manager.getBounds()`; that dependency was withdrawn under RQ-1 A, and
the reasoning is unchanged without it: R-M5 settles that the **shell** computes the frame and passes
it to `open(config, frame:)`, while the centre parameter stays `null`.)

### 10.4 Two-controller router proof (Q3 -> C)

Both layers, in `zip_core`:

1. **Unit-level** — one real router, two recording handlers keyed by window id. Asserts each id
   reaches its own handler, that unregistering one leaves the other, that the first register installs
   the static slot and the last unregister clears it, and that a duplicate unregister is a no-op.
2. **Two real controllers** — controllers A (window `7`) and B (window `9`), each with a distinct
   recording `DesktopWindowService`, sharing one real router through the provider. Asserts:
   - `(method, fromWindowId: 7)` reaches A's service and **not** B's;
   - `(method, fromWindowId: 9)` reaches B's and not A's;
   - after A closes, `(method, fromWindowId: 7)` is **dropped** — asserted as "neither service saw
     it", not as "no exception";
   - after A closes, `(method, fromWindowId: 9)` still reaches B.

The negative assertions are the point: they are what catches a router that hands the last-registered
handler every message, and they are the assertions a call-count-only test would omit.

### 10.5 Owner answers to the pre-build review (2026-10-21)

The pre-build review (`plans/pop-out-pre-build-review.md`) found five blockers, ten major gaps and
seven minor items; all 22 reproduced on re-verification. The three owner decisions:

| ID | Answer | Effect on this document |
|---|---|---|
| RQ-1 | **A** — native per-runner window channel; drop `window_manager` | §1.2, §3.1, §4.1, §4.3 and the SECURITY-10 row rewritten; the accepted-limitation row for the macOS plugin set withdrawn (R-B1) and a runner-code row added. FD §3.2 is normative for the mechanism. |
| RQ-2 | **A** — each app's own engine gate, not the registry | §1.3's per-app evidence table unchanged in shape; FD `domain-entities.md` §3.1 and BR-PIP-13 rewritten (R-M1). |
| RQ-3 | **A as amended** — the close notification is raised **natively in the runner** and delivered to the **main** engine, tagged with the sub-window id from `configure`; the `'-1'` path stays as fallback | §1.2 gains the close-notification assertions; §3.1 gains the unknown-id row; FD §3.2 gains the per-platform hook table, the Linux handler-order finding, and the verify-in-Infrastructure-Design list. |

RQ-3's premise — that a Dart message sent from the sub-engine at close time is likely lost because
`desktop_multi_window` tears the engine down inside its own close handling — is taken as the owner's
design rationale and is logged as a **claim to verify in Infrastructure Design**, not as established
fact.

**Open items carried to NFR Design**: none from the handoff; 10.1-10.5 are constraints. NFR Design
must also carry R-M2's six guards, R-M3's router shape and R-M5's frame ownership into its own
sections rather than re-deriving them.
