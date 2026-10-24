# NFR Design Patterns — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (answers recorded in
`plans/pop-out-nfr-design-questions.md`; `dispose()` re-specified unchanged in review round 2).
**Branch**: `feature/popout-live-captions`
**Companion artifact**: `logical-components.md` (the object graph, seams and resource table).
**Plan**: `plans/pop-out-nfr-design-plan.md`

This document is organised by NFR domain. It carries the approved decisions; it does not re-derive
them. Where a decision came from an approved artifact, the source is cited rather than restated in
full.

---

## 0. Carried decisions (binding, not reopened)

| # | Decision | Source | Carried in |
|---|---|---|---|
| 1 | Six `_isPopOut` guards on every display-consulting path; mode fixed at construction; `open()`'s config mode validated against it (mismatch → `create_failed`) | FD BLM §2; R-M2; NFR-R §10.2 | §1.2 below |
| 2 | `int? get windowId`; token-bound installer installed at `_bootstrap`; dispatch only when `windowIdOf() != null && windowIdOf() == fromWindowId` — null never matches | FD BLM §4.1; R-M3 (Revision 2 item 2) | §4.1 below |
| 3 | The shell computes the frame and passes it to `open(config, frame:)`; `_runReady` uses it verbatim via `setFrame`; per-platform chrome allowance as named constants with a table test, documented as content-size semantics | FD BLM §3.4; R-M5; NFR-R §10.3 | §2.1, §2.3 |
| 4 | `WindowConfigurator.configure` runs in the sub-engine before ready for both modes; `ExternalDisplayMode` passes `floating: false, decorated: false`; a throwing configurator still sends ready | FD BLM §3.2 step 6; NFR-R §1.2 items 1-3 | §1.4 |
| 5 | First-party `subWindowClosed {windowId}` on the **main** engine through `SubWindowClosedChannel` to `controller.onNativeWindowClosed(int)`; id match → `CloseReason.windowClosed`, else dropped; `'-1'` is the fallback; never through `OverlayMethodRouter` | FD BLM §3.2; RQ-3 A-amended; NFR-R §1.2 | §1.3 |
| 6 | `package:zip_core/overlay.dart` is a separate library, not re-exported from `zip_core.dart` | R-M7; NFR-R §5.2 | §4.4 |
| 7 | The seven permitted controller deviations, and nothing else | FD BLM §4.1; BR-U8.1-01 | §1.2, §4.1 |

Also carried: `controls` outside the scrolling list (R-M4); failure copy next to the chrome toggle
while `Failed` (R-M8); `popOutAvailability` tests the three concrete states, not the
`ActiveSessionState` mixin (R-m3); `_bootstrap` must not require a display for `PopOutMode`; no
`window_manager` anywhere (RQ-1 A).

---

## 1. Resilience patterns

### 1.1 The two new failure surfaces, and the one asymmetry that is deliberate

This unit adds exactly two native boundaries, and each has one failure policy. Both follow the
project's standing rule (Unit 8 R3/R4, restated in NFR-R §3.1): **no retries anywhere** — the toggle
is the retry.

| Surface | Failure | Policy | Why |
|---|---|---|---|
| `configure` (sub-engine, before ready) | channel missing, native throws, arguments rejected | caught; **one fixed-string log at `FINE`**; the window opens anyway | a window that is not on top is a usable pop-out; an `OpenFailed` for a working window is worse (NFR-R §3.1's asymmetry) |
| `subWindowClosed` (main engine) | malformed call, unknown id, late duplicate | dropped silently (nothing at `INFO` or above) | the `'-1'` fallback still covers the window; a malformed native call is not caption data and must not become a log line carrying a payload |

**P1 correction recorded**: the missing-frame path logs **one fixed-string record at
`Level.FINE`**, not a "warning at fine level". `FINE` is below the apps' release threshold
(`Logger.root.level = Level.WARNING` outside debug), so in production it is invisible unless a
developer turns it on.

**P1 correction recorded (second half)**: the earlier draft justified the fallback partly by "the
moved Unit 8 tests that open a pop-out controller directly must all pass a frame". **No such test
exists** — the moved suite contains no pop-out controller test. The fallback stands on its own
reason (§2.1), and no test shape changes because of it.

### 1.2 The mode guard: one predicate, six sites, decided once

`_isPopOut` is fixed at construction (`_mode is PopOutMode`), and `open()`'s `OverlayConfig.mode`
is validated against it — a mismatch fails the open as `create_failed` rather than switching
behaviour. This is the single-writer rule applied to mode: **no code path may change what the
controller is**, only what it does.

The six guarded sites are the six places that consult a display (FD BLM §2's table). The pattern is
not "remember to check the flag in six places" but "these six sites are the complete set", verified by
the guard census in §5.2. A seventh display-consulting site added later without a guard is a defect
the census test names.

For `PopOutMode` the consequences are fixed: no `resolveOpenDisplay`, no `NoDisplays` on an empty
list, no T15 re-frame, no display-lost close, no `WaitingForDisplay`. `_bootstrap`'s capability rule
becomes `isSupported && (mode is PopOutMode || displaysAvailable)`, so a display-less machine can
still pop out — while an `ExternalDisplayMode` controller on such a machine still reports
`NoDisplays`, exactly as Unit 8 shipped.

### 1.3 The close event: registration, dispatch, and the three drop rules

**Registration (D1 = B, owner-corrected).** There is no startup gap to close, and this is the
correction that makes the pattern small: **only a controller creates a window**, and under R1 A each
controller subscribes in `_bootstrap`, which runs in the constructor — before the controller can be
asked to `open()`. So by the time a `createWindow` call is possible, a listener exists.

Ownership therefore sits where the other two engine-wide resources already sit (NFR-R §10.1): the
`overlayWindowHost` provider in `zip_core` owns the `OverlayMethodRouter`, the single
`ScreenRetrieverDisplayEnumerator`, **and the `SubWindowClosedChannel`**. The host installs the
channel handler when it is built and releases it with `ref.onDispose`. Consequences, stated so they
are not re-litigated:

- **nothing in `main`** — no eager read, no disposer threaded through startup;
- **nothing on the sub-engine path** — the overlay-launch branch returns before any host exists, so a
  pop-out window engine never opens a main-engine channel (D1 A would have installed it before the
  overlay-launch check, in both engines);
- **no `ProviderContainer`** inside the handler — the controller subscribes itself, so the handler
  never has to look one up (`zip_broadcast`'s `main` has no container handle to give);
- the handler survives controller rebuilds, because the host outlives them (`keepAlive`) and the
  subscriptions belong to the controllers.

**Dispatch (R1 = A).** The channel is a process-level fan-out, not a router:

```
SubWindowClosedChannel            (one instance, owned by the host)
  void install()                  // sets the MethodChannel handler once
  Stream<int> get closed          // broadcast; ids in arrival order
  void dispose()

OverlayWindowController._bootstrap()
  _channelSubscription = channel.closed.listen(onNativeWindowClosed)
OverlayWindowController.dispose()
  _channelSubscription?.cancel()
```

Each controller filters by its own id. That makes the first drop rule structural rather than
checked: **an id that matches no controller reaches no controller**, which is exactly NFR-R §3.1's
"unknown id: dropped, no state change, no log at info and above". A second broadcast stream would be
a second owner; a direct call from the channel into a controller would need the controller to exist
when the channel is installed, which is D1 A's ordering problem again.

**The three drop rules, and why each is safe:**

| Event | Result | Why it is safe |
|---|---|---|
| id == open window's id | `CloseReason.windowClosed` → `-1`-equivalent path: `_release`, `Off`, `WindowClosed` | the same terminal transition the fallback produces, so the shell has one reaction to write |
| id != open window's id (unknown, or the other controller's) | dropped by the id comparison | each controller keeps exactly one id, so the comparison is total |
| late event for an app-initiated close | dropped | `_takeWindow()` nulls the id first (`overlay_window_controller.dart:528-533`), so no id matches afterwards |

**The known platform risk, and why it does not reshape this design.** FD BLM §3.2 records that
Linux's `desktop_multi_window` handler returns `TRUE` after `gtk_widget_destroy`
(`linux/flutter_window.cc:34-40`), so a notification connected after it may never run. That is a
*native emission* risk, not a Dart dispatch risk: if Linux cannot emit, Linux falls back to `'-1'`
exactly as Unit 8 shipped, and nothing here changes. Infrastructure Design settles which Linux signal
is used (item 4 of the FD's verify list); this stage's contract is only "if an id arrives, one
controller owns it".

**Why this is not the router's job.** FD BLM §3.2 states it and it is worth keeping visible: the
event is a first-party main-engine channel, while the router exists to multiplex
`desktop_multi_window`'s *window* channel. Routing the event through the router would give the
router two unrelated inputs and would re-introduce the possibility of delivering a close event to a
controller that does not own that window.

### 1.4 Configuration: applied once, before the window is shown, never fatal

The sub-engine's startup order is FD BLM §3.2 steps 1-9, unchanged. This stage adds only:

- the `configure` call is awaited **once**, before the bridge handler is installed and before
  `OverlayWindowEntry` sends `overlayReady`. `OverlayWindowEntry` does not run it and does not await
  it (R-M9: one statement, one owner);
- `ExternalDisplayMode` sends `floating: false, decorated: false` — **pinned** (NFR-R §1.2 item 2).
  Unit 8's borderless surface now depends on this call succeeding; if it fails, the external display
  window is decorated, which is cosmetic, logged as a fixed string at `FINE`, and changes no state.
  That new dependency is recorded here so it is not discovered as a regression during Unit 9;
- a throwing configurator is caught inside `WindowConfigurator`, so the ready handshake is
  unaffected by construction: the call cannot throw into `overlayWindowMain`.

The failure edge has one deliberate shape worth naming: **`configure` is a precondition of
cosmetics, not of the open.** Everything else in the open sequence (handler present,
`createWindow`, ready) is fail-closed; this one is fail-open, and NFR-R §3.1 explains the asymmetry
in the terms the user experiences.

### 1.5 Resource discipline (restated from NFR-R §3.2 with this stage's additions)

| Resource | Owner | Released by |
|---|---|---|
| One `ScreenRetrieverDisplayEnumerator` (one platform observer) | `overlayWindowHost` | last `DisplayEnumeratorLease` release, or `host.dispose`, whichever is first (idempotent) |
| Each controller's `DisplayEnumeratorLease` (one share) | the controller | its own `dispose()` (`:702`, unchanged) |
| One `OverlayMethodRouter` and its static handler slot | `overlayWindowHost` | last token unregistered uninstalls; host dispose unregisters the rest |
| One `SubWindowClosedChannel` and its `MethodChannel` handler | `overlayWindowHost` | `ref.onDispose(host.dispose)` |
| Per-controller channel subscription | the controller | `dispose()` |
| Per-controller ready timer, update timer | the controller | `_setState` structural cancel + `_release` (Unit 8) |
| Per-app `PopOutCaptionTarget` registration | the app shell | shell `dispose()` (unregister + `close(dispose)`) |
| Per-app `events` subscription | the app shell | shell `dispose()` (already the shipped pattern: `zb_app_shell.dart:75`) |

**`dispose()` is unchanged, and the moved `dispose` tests pass verbatim** (correction, review
round 2). The controller still calls `_enumerator.dispose()` (`:702`) and
`_handlerInstaller?.call(null)` (`:708`). Neither call changes, because both are met by
reference-counting rather than by editing the controller:

- `:702` disposes a **`DisplayEnumeratorLease`**, not the shared instance. The lease delegates every
  member (`displays`, `changes`, `primarySize`) to the host's one enumerator, releases only this
  controller's share on `dispose()`, and lets the last release — or `host.dispose()`, whichever comes
  first — dispose the real object. It is idempotent, so a double `dispose()` is a no-op. The
  moved assertion `harness.enumerator.isDisposed` (`overlay_window_controller_test.dart:736,749`)
  therefore still means "this controller released", which is what it was written to check. An
  earlier draft of this section said `dispose()` must stop disposing the enumerator; that was wrong,
  and the test is the reason.
- `:708` already goes through `router.installerFor(token)`, which maps `null` to
  `unregister(token)` (deviation 5). No call-site change.

No eighth deviation, and no row outside the FD's additive-change table. The lease is the enumerator's
counterpart to the installer token: one shared object, one per-controller handle, released by the
handle.

---

## 2. Performance patterns

### 2.1 Frame ownership: computed once by the shell, applied once by the controller

```
shell (build context, DisplaySettings, TextTheme, textScaler, controller.displays)
  computePopOutFrame(...)                     pure, pop_out_geometry.dart
  controller.open(config, frame: frame)        one optional parameter
controller._runReady
  setFrame(frame)                              verbatim; no geometry in the controller
```

**Missing frame (P1 = A).** `frame == null` keeps today's external-display path byte-for-byte. For
`PopOutMode` with a null frame, `_runReady` **does not call `setFrame`** and accepts the frame the
plugin already gave the window, logging one fixed string at `FINE`. No new failure mode, no
assertion, no throw. The production caller always supplies a frame, so this path is unreachable from
the app; it exists so that a controller can be opened without a build context (tests, a future
headless use) instead of failing a window that is already on screen.

Rejected and why: failing the open as `create_failed` would turn our own programming error into a
user-visible dialog, and would make every non-shell caller carry geometry it may not have.

### 2.2 The toggle-to-`Opening` target (P2 = A)

NFR-R §2 sets the target: a press reaches `Opening` in the same frame. The pattern that keeps that
true is a **gate that is resolved before the control is enabled**, never a queued press:

- `popOutAvailability` is a pure function of already-loaded state (§3.1 of `domain-entities.md`):
  `status`, the three concrete session states, and `engineAvailable` — each read synchronously with
  `ref.watch`;
- an unresolved gate renders the **disabled** control with its visible reason (UX-PIP-03/04 already
  require that reason), so there is no "loading" state to invent and no spinner;
- the press handler calls `controller.open(...)` with **no `await` before it**, so `open()`'s own
  synchronous `Opening` assignment (`overlay_window_controller.dart:297-304`) is what the next
  `pump()` observes.

The measurement is therefore honest: the target is asserted for a press on an enabled control. A
press on a disabled control does nothing at all, which is the contract, not a missed target.

Why not queue the press: it would make the target untestable in the only case it was written for,
and it would hide a slow gate behind a state the user cannot see.

### 2.3 Chrome allowance: content-size semantics, three named constants (P3 = A)

`setFrame` sets the **outer** frame. On Windows and Linux the title bar sits inside it; on macOS the
window is created `.titled, .fullSizeContentView` with the title hidden and the bar transparent
(`FlutterWindow.swift:68-71,86-88`), so content draws under it. Either way, "two rendered lines plus
the toggle row" of *content* is clipped unless the geometry adds chrome.

The pattern: **`popOutSize` means content size, and one pure function adds chrome.**

```
const double chromeTopInsetMacos   = 28;
const double chromeTopInsetWindows = 39;   // 31 title bar + 8 borders
const double chromeTopInsetLinux   = 38;   // 37 title bar + 1 border
const double chromeBorderInsetWindows = 8;
const double chromeBorderInsetLinux   = 1;

EdgeInsets chromeAllowance(TargetPlatform platform)   // EdgeInsets.zero for anything else
```

- selected by target platform, computed where the frame is computed (the shell), so the controller
  still knows nothing about chrome;
- a table test asserts the selection per platform, the unknown-platform fallback, and that the
  content height is unchanged by the allowance;
- the minimum size (320x96) is likewise **content** size.

**P3 correction recorded.** These values are **documented estimates, unverified until the Unit 9
measurement** — not "verified in Infrastructure Design". Infrastructure Design cannot launch a
window, so it can only reason about ordering and ownership; the number is settled by the Unit 9
platform check (item 13 of `pip-ux-parity.md` §8.8). The code comment says exactly that, so nobody
later mistakes a guess for a measurement. The spec also records that the Linux value varies by
desktop environment and theme (a GNOME header bar is not a MATE title bar), so the Linux constant is
explicitly a default estimate rather than a per-WM table; the Unit 9 check records what was measured
and on which desktop.

### 2.4 Everything else is inherited

`≤1 captionUpdate` per 16 ms with the dirty flag and re-arming timer; 16 KiB `maxEncodedBytes`; 10 s
`overlayReadyTimeout`; ≤1 `getAllDisplays()` per platform event and zero polls; every window call
event-driven. Unit 8's patterns P1/R3/R4 move unchanged (FD BLM §4.2). `popOutSize` runs once per
open, not per frame (NFR-R §2's last paragraph).

---

## 3. Security patterns

The Security Baseline table lives in §6. The patterns this stage adds:

### 3.1 Two native boundaries, both allowlist-by-type

Both channels carry **no caption text**, and both are validated structurally:

| Channel | Direction | Validation | On rejection |
|---|---|---|---|
| `zip_core/overlay_window_configure` | Dart (sub-engine) → native | `windowId` non-negative `int`; `floating`/`decorated` `bool`; `minWidth`/`minHeight` finite, non-negative `double`, clamped natively to the work area | native answers a fixed `FlutterError('configure_invalid')`; nothing is styled; Dart catches and logs `FINE` |
| `zip_core/overlay_sub_window_events` | native → Dart (main engine) | method must be exactly `subWindowClosed`; argument must be a map with a single non-negative `int` `windowId` | dropped, **nothing logged** |

A native call is untrusted input in the SECURITY-05 sense even though we wrote it: the runner is a
boundary, and a boundary that "trusts its own caller" only holds until the next refactor. The
validation is also what makes the `'-1'` fallback the sole remaining path for malformed cases, so
there is no third behaviour to reason about.

### 3.2 No argument is ever echoed

SECURITY-03 and BR-PIP-11's fixed-string discipline applies to the new boundaries too: a rejection
logs a fixed string and, where a type is useful, `runtimeType` only. `windowId` is a small integer and
is not treated as sensitive, but it is not interpolated into a message either — the fixed-string rule
is applied without a per-field exception list to maintain.

### 3.3 Fail-closed where it can be, fail-open where the alternative is worse

The fail-open edge is `configure` (§1.4). Everything else fails closed: an unsupported platform
renders nothing; a missing method handler fails the open as `create_failed` (Unit 8 R6); an
undecodable launch payload renders the unavailable frame and never signals ready; an unknown mode
token decodes to `null`. The asymmetry is recorded in NFR-R §3.1 in the user's terms, and this
stage only adds the second instance (`subWindowClosed` malformed → drop, because the fallback exists).

### 3.4 The Linux try-before-signal fallback

`SubWindowClosedChannel.install()` attempts the `MethodChannel` setup and, if it throws on a
platform that cannot support it, records "unavailable" and lets the suite (and the app) continue: the
`'-1'` path is the documented fallback for every mode. Fail-closed here would mean refusing to open
the pop-out at all because a close *notification* is unavailable, which is strictly worse than
Unit 8's shipped behaviour.

---

## 4. Logical-component patterns

Component names, constructors, the dependency diagram and the resource table are in
`logical-components.md`. The patterns that shape them:

### 4.1 Router dispatch (carried, §0 item 2)

One static slot, one owner, tokens per controller. The two behaviours that must not drift:

- **null never matches.** The dispatch predicate is `windowIdOf() != null && windowIdOf() == fromWindowId`.
  A controller without a window receives nothing. This closes the shipped `:390` hole where
  `_windowId == null` accepted every message.
- **the installer is installed at `_bootstrap`, before any window exists.** `windowIdOf()` is
  consulted only at dispatch, by which time `createWindow` has returned.

The router is inert until its first registration (nothing to install), which is why constructing it
in the host and wiring it in `createController` is safe even if no window is ever opened.

### 4.2 Host ownership (L2 = A, plus D1's channel)

`overlayWindowHost` returns an `OverlayWindowHost` that owns router, enumerator **and** the close
channel, and exposes:

```
OverlayWindowController createController({
  required OverlayWindowMode mode,
  required String logPrefix,
})
Stream<List<DisplayInfo>> get displays          // replaces controller.enumerator.changes
```

`displays` on the host gives app-level watchers a path to the display list that does not go through
a controller: today `displayList` reads `controller.enumerator.changes`
(`overlay_window_controller_provider.dart:49`). Apps keep their provider names and their dependents;
only the body changes.

The controller still holds an enumerator-shaped collaborator — its `DisplayEnumeratorLease` — so
`controller.enumerator` keeps working for any caller that already used it. What changes is what
disposing it means: releasing this controller's share, not tearing down the platform observer
(§1.5).

### 4.3 Per-app flag ownership (L3 = A)

`zip_captions` gets a `keepAlive` `Notifier<bool>` (`popOutNotifierProvider`) with `toggle()`/`set`.
`zip_broadcast` keeps its shell field, because its shell already owns the target and the registry
(FD BLM §5). The pattern that matters for both: **the flag is owned by the app, and it is written by
exactly two things** — the user's toggle, and the controller's `events` stream
(`WindowClosed`/`OpenFailed` → `false`). No third writer, and no persistence call on any path
(Q10 B).

**FD correction required (owner, L3 note 4).** `domain-entities.md` §2.2's `ZcAppShell` row says the
shell "becomes a `ConsumerStatefulWidget` to own the one target and the in-memory flag". Those are
two separate facts and the row conflates them: the shell becomes stateful because it **owns the
target and the events subscription**; the flag lives in the notifier. The row must be corrected
before Code Generation, and the correction is listed in `handoff-summary.md` as an open
documentation item rather than applied to an approved artifact in this session.

### 4.4 The barrel and the deviations (carried, §0 items 6-7)

`package:zip_core/overlay.dart` exports the public surface and does not re-export
`desktop_multi_window`; `zip_core.dart` does not export the barrel (the `Failed` collision, R-M7).
The seven permitted controller deviations are enumerated in `logical-components.md` §4 with their
call sites, so Code Generation can check the list mechanically.

**What this stage adds to that list is nothing.** Every mechanism chosen above (a
`Stream<int> get closed` subscription, the seven deviations, the `Stream<List<DisplayInfo>> get
displays` accessor on the host) either rides an existing deviation or lives in a new object. If Code
Generation finds it needs an eighth deviation, the rule is BR-U8.1-01's: stop and report.

---

## 5. Scalability

**N/A, restated not re-derived** (NFR-R §7). No queue, pool, cache or concurrency axis is
introduced. The router's bound is two handlers; the host's bound is one enumerator and one channel;
each open window owns one 16 ms timer. The only growth the design acknowledges is viewport-sized,
not load-sized.

### 5.2 The guard census (static verification, not a load test)

Because "six sites" is a claim about completeness, it gets a check that does not require scaling:
`overlay_window_controller.dart` is read for every expression that consults `_displays`,
`_find(...)`, `resolveOpenDisplay`, `_modeDisplayId` or `_openBounds`, and each occurrence must map
to one of the six guarded sites or be the guard itself. The census is recorded in the code summary
(*this file names the check; the count is asserted at Code Generation, when the code exists*). A
seventh site is a defect, not a scaling question.

---

## 6. Compliance sections

### 6.1 Security Baseline

Carried from NFR-R §4.2 (8 Compliant, 6 N/A, 0 non-compliant), with this stage's additions:

| Rule | Status | This stage's basis |
|---|---|---|
| SECURITY-03 Application logging | Compliant | Both new boundaries log fixed strings + `runtimeType` only; no argument echoed (§3.2); `FINE` for the two non-fatal paths so release output is unchanged |
| SECURITY-05 Input validation | Compliant | Both channels allowlist-by-type with range checks (§3.1); codec stays total-on-error and 16 KiB-capped |
| SECURITY-08 Access control | N/A | No endpoint, no resource access |
| SECURITY-09 Hardening | Compliant | Failure copy generic; the raw `Failed` reason never reaches the user; no debug surface added |
| SECURITY-10 Supply chain | Compliant | **No new third-party dependency**; two first-party channels in our own runners; `desktop_multi_window`/`screen_retriever` already vetted; the lockfile fence is unchanged (positions only) |
| SECURITY-11 Secure design | Compliant | Separation: machinery in `zip_core`, chrome/registration per runner; one owner per engine-wide resource; two channels by direction, not by app |
| SECURITY-13 Integrity | Compliant | Decode allowlist (enum-by-name, known version, known mode token); `subWindowClosed` allowlist-by-shape; no unsafe deserialisation |
| SECURITY-15 Exception handling | Compliant | `configure` caught and never fatal; channel install degrades to the documented fallback; release never throws; no unhandled future in an `unawaited` path |
| SECURITY-01, -02, -04, -06, -07, -12, -14 | N/A | As NFR-R §4.2 (no store, no intermediary, no web, no IAM, no network config, no auth, project-wide alerting deferral) |

**No blocking security findings.** No security-critical area from `AGENTS.md`'s pre-approval list
(encryption, keys, RLS, OAuth, device posture, server logging, raw transcript handling) is touched by
this unit or this stage.

### 6.2 PBT

| Rule | Status | This stage's basis |
|---|---|---|
| PBT-01 | Compliant | FD `domain-entities.md` §5, POP-1..POP-8, unchanged |
| PBT-02 | Compliant | POP-1 launch round-trip, POP-6 mode token |
| PBT-03 | Compliant | POP-2/3/4/8; **plus the chrome allowance is table-tested, not property-genned** (a finite platform domain — PBT-03's spirit is met by exhaustiveness, as POP-7 already argues) |
| PBT-04 | Compliant | Router `unregister` no-op; channel subscription is idempotent-safe (a duplicate cancel is a no-op); controller close idempotence moved |
| PBT-05 | N/A | No reference implementation |
| PBT-06 | Compliant | POP-5's `_World` harness moves and gains `openPopOut`/`toggleAgain`/`toggleOff`/`windowGone`; **`windowGone` now means "the channel delivered this controller's id"**, which is the same command the fake channel drives |
| PBT-07 | Compliant | `overlay_generators.dart` gains `arbitraryPopOutGeometryInput` and `arbitraryPopOutModeLaunch`; platform generators for the allowance are a fixed enum, so the table test covers them |
| PBT-08 | Compliant with the recorded limit | in-tree shim, 100 fixed seeds, no shrinking — the project's standing decision; seed printed on failure; runs in CI via `melos run test:coverage --no-select` |
| PBT-09 | Compliant | in-tree `test/helpers/pbt.dart`, no new package |
| PBT-10 | Compliant | POP-7 and the chrome-allowance table are example-based by design; every claimed §8.8 item keeps an example test in both apps |

No blocking PBT findings.

---

## 7. Open items handed to Infrastructure Design

Restated from the plan so they are not lost (none of them is resolved by this stage):

1. That a Dart message from the sub-engine at close time is lost (RQ-3's premise).
2. macOS: the notification's delivery point relative to `deinit`.
3. Windows: the window-proc delegate's ordering against `HandleTopLevelWindowProc`.
4. Linux: `delete-event` vs `"destroy"` given the plugin's `TRUE`-returning handler — and whether a
   notification is connectable at all. If not, Linux uses the `'-1'` fallback and this design is
   unaffected (§1.3).
5. Runner callback signatures and `argv` delivery — **partly settled now**: the two signatures were
   verified for R-B4 and fixed on `fix/zip-broadcast-runner-callbacks` (PR #40); `argv` is
   `["multi_window", "<id>", args]` on all three backends (`FlutterWindow.swift:73`,
   `windows/flutter_window.cc:100`, `linux/flutter_window.cc:45-46`). ID still verifies the
   `zip_captions` runners, which have no callback today.
6. The Flutter SDK the ID's claims are checked against (CI pins 3.38.7; this machine has 3.41.7).
7. The three chrome-allowance values — **explicitly not ID's to verify**; see §2.3's correction.

Item 4 is the only one that could change a decision made in this stage, and §1.3 shows the
degradation is to Unit 8's shipped behaviour rather than a redesign.