# NFR Design Plan: External Display (Unit 8, S-20)

**Prior stage**: NFR Requirements, approved 2026-10-20 (unattended run).
**Run mode**: unattended (`.agent/overnight-pipeline.md` A2). Every question
below is answered here under the run-configuration pre-approval and will be
recorded in `audit.md` as `approved by: run configuration
(.agent/overnight-pipeline.md, 2026-10-19) — subject to morning review`.

## Context

NFR Requirements fixed *what* has to be true — one shared catch-and-continue
`_release` (Q3), `overlayReadyTimeout = 10 s` and `maxEncodedBytes = 16 KiB`
as named constants (Q4/Q5), the ≤1-`captionUpdate`-per-frame cadence and the
enumeration/open targets (Q5), fixed-string logging with a redaction audit
test (Q6), the fake-only test set (Q1/Q2), the in-tree PBT shim with
FP-1..FP-5 (Q8) — but not *how* the controller is shaped to make those true:
the release helper's exact step set and what "display subscription cancel"
means for D-4's waiting state, where the ready `Timer` is cancelled, how the
`'-1'` code is caught and mapped, how the ≤1-per-frame cadence is implemented,
where the controller and its seams sit in the provider graph, and the name and
signature of the pure BR-U8-07 resolution function FP-4 needs.

Scalability introduces no new pattern (restated below, not reopened).

**Verified against source** (2026-10-20, before writing questions):

- `desktop_multi_window` 0.2.1 (pub cache): `WindowController.fromWindowId(id)`
  exposes `show()`, `setFrame(Rect)`, `close()`
  (`lib/src/window_controller.dart:22-31`); `DesktopMultiWindow.setMethodHandler`
  is a static taking
  `Future<dynamic> Function(MethodCall call, int fromWindowId)?`
  (`lib/desktop_multi_window.dart:59-69`) — passing `null` unregisters. One
  handler per engine; sub-engine messages arrive at the main engine through it.
- `screen_retriever` 0.2.2 (pub cache): the `Display` model has
  `id`, `name?`, `size`, `visiblePosition?`, `visibleSize?`, `scaleFactor?`
  (`_platform_interface/lib/src/display.dart`) — **no `isPrimary` field**;
  the primary is only reachable via `getPrimaryDisplay()`, which every backend
  implements (macOS `:111,139`, Windows `:240`, Linux `:104`). Linux sends
  `id: ""` for every monitor (`screen_retriever_linux_plugin.cc:76`), so
  primary matching by id alone is insufficient there.
- `packages/zip_broadcast/lib/src/shell/zb_app_shell.dart`: the shell owns
  `CaptionOverlayTarget` as a field, registers/deregisters it in
  `_syncOverlay(bool)` and listens to `outputTargetSettingsNotifierProvider`
  via `ref.listen` — the shipped `_syncOverlay` path BR-U8-15's
  `WindowClosed` handling reuses.
- `packages/zip_broadcast/lib/src/output/browser_source/browser_source_target.dart`:
  the package's shipped lifecycle-serialization idiom —
  `Future<void> _lifecycleLock = Future.value();` chained per operation.
- `packages/zip_core/lib/src/output/on_screen_caption_target.dart`: the shipped
  debounce idiom (a reset `Timer`, 50 ms, `_scheduleEmit`) and
  `visibleCaptions` = `[..._buffer, ?_currentInterim]` (final portion plus the
  trailing interim) that BR-U8-12's snapshots read.
- `packages/zip_core/lib/src/models/caption_wire_codec.dart:25`:
  `static const int maxEncodedBytes = 16 * 1024;` — the placement precedent for
  the codec's named constant.
- `packages/zip_core/lib/src/services/auth/supabase_auth_service.dart:69-70,222-225`:
  plain `Timer?` fields, no clock seam, cancelled on every exit; the test file
  drives them with `fakeAsync` — the Unit 5 timer precedent NFR Requirements
  Q1 cited.
- `packages/zip_core/test/pbt/viewer_session_state_machine_properties_test.dart`:
  the FP-5 harness precedent — a `_World` per Glados trial, one `fakeAsync`
  per trial, a command runner, invariants checked after every command.
- `packages/zip_core/test/services/broadcast/viewer_session_notifier_test.dart:572-587`:
  the Unit 7 redaction pattern — a capturing `Logger.root.onRecord` listener
  plus a sentinel caption string.
- `packages/zip_core/lib/src/services/caption/caption_output_target_registry.dart`:
  `remove(target)` is a no-op when the target is not registered and disposes
  the target when it is; `activeTargets` is the observable membership view.
- `packages/zip_broadcast/lib/main.dart:32`:
  `GoogleFonts.config.allowRuntimeFetching = false` in the main engine —
  B-4 requires the same in the sub-engine entry (carried to Infrastructure
  Design / Code Generation, not settled here).

## Planned Steps

- [x] Resilience: the release helper's step set, the display-watch lifetime, and the `isVisible` representation (Design Q1)
- [x] Resilience: ready-timer ownership and structural cancellation (Design Q2)
- [x] Resilience: the catch-and-map seam for window calls and the pre-/post-ready `'-1'` split (Design Q3)
- [x] Scalability: restated from NFR Requirements — N/A, no new pattern (applicability justified)
- [x] Performance: the ≤1-per-frame coalescing mechanism and the named-constant placement (Design Q4)
- [x] Security: the redaction audit test's shape and the fixed-string call-site list (Design Q5)
- [x] Logical components: provider graph, controller seams, shell wiring, target constructor (Design Q6)
- [x] Logical components: the method-handler installer seam (Design Q7)
- [x] Logical components: the pure BR-U8-07 resolution function (Design Q8)
- [x] Logical components: the test-helper set, the domain generators, the FP-5 harness (Design Q9)
- [x] Generate `nfr-design-patterns.md`, `logical-components.md`, `handoff-summary.md`

## Resilience Patterns

### Design Q1: How is NFR Requirements Q3's shared release helper shaped — the exact step set, what "display subscription cancel" means for D-4, and how the `isVisible` half of BR-U8-02 is represented?

NFR Requirements Q3 fixed one shared private catch-and-continue
`_release(Logger)`-shaped helper with the step list "closeWindow (idempotent),
target deregistration, display subscription cancel, window id nulling,
`isVisible` false", per-step logging of a fixed string plus `runtimeType`,
never throwing, terminal transition last. FD BR-U8-02's four-part invariant is
window id null, `isVisible` false, target not on the registry, no open
subscription for that window. What Q3 does not settle: the controller's
`DisplayEnumerator.changes` subscription is controller-lifetime (it must
survive `WaitingForDisplay` for T11's auto-reopen, and `Off`/`Failed` for T4's
list refresh and T16's retry), so it cannot be a per-close release step; and
the shipped `CaptionOverlayTarget` keeps its own `_isVisible` field, which the
B-9 thin-delegator rewrite should not keep as a second source of truth.

A) **Window-scoped release, controller-lifetime watch.**
   `_release(Logger log)` performs, each in its own `try`/`on Object` logging a
   fixed string + `${e.runtimeType}` only, never throwing: (1) cancel the
   ready `Timer` if active; (2) `closeWindow(capturedId)` when a window id was
   captured; (3) `registry.remove(target)` (a no-op if the shell already
   removed it — verified: `CaptionOutputTargetRegistry.remove` on an
   unregistered target does nothing). The public `close()` captures and nulls
   `_windowId` **synchronously before its first await** (Unit 6's
   "synchronously before the first await" discipline), so BR-U8-02's
   window-id-null and `isVisible`-false halves hold immediately, re-entrant
   calls see a consistent state, and a second close or a concurrent open
   cannot grab a stale id. The target's `isVisible` becomes a **derived
   delegation** to the controller (`_controller.isWindowOpen`, i.e.
   `_windowId != null`) — the shipped field is deleted, the controller becomes
   the single writer, and Q3's "isVisible false" step is satisfied
   structurally. The `changes` subscription is **not** a release step: it is
   cancelled only in `dispose()`, together with `enumerator.dispose()` and the
   method-handler uninstall — the reading of Q3's "display subscription
   cancel" is "no open subscription for *that window*" (BR-U8-02's own
   wording), and the only per-window async handle is the ready timer. Every
   close path (T13 toggle off, T14 `WindowClosed`, T6/T8 failed open, T10
   display lost) shares this one helper; the terminal transition
   (`Off`/`Failed(reason)`/`WaitingForDisplay`) is set last and unconditionally
   by the state machine, never by the helper. **(recommended — one release
   implementation; the derived `isVisible` removes a second writer BR-U8-02
   would otherwise have to police; and keeping the `changes` watch alive is
   what makes D-4's T11 auto-reopen and T4's `NoDisplays` → `Off` possible at
   all)**
B) Keep the `changes` subscription as a per-window resource created on open
   and cancelled on every release (rejected: T11 cannot fire from
   `WaitingForDisplay` without the watch, and T4 needs it in `NoDisplays`
   before any open ever happens — the FD's event contract and D-4 contradict
   per-window ownership)
C) Keep the target's own `_isVisible` field, written by the target on each
   `show`/`hide` (rejected: two writers for one BR-U8-02 invariant half; the
   thin-delegator rewrite exists precisely to remove the target's own
   window-state bookkeeping)

[Answer]: A

### Design Q2: Where does the ready `Timer` live, and what guarantees it is cancelled on every exit from `Opening`?

NFR Requirements Q4 fixed: one `Timer` for `overlayReadyTimeout`, driven by
`fakeAsync` in tests, no clock seam; expiry → `OpenFailed(ready_timeout)`,
idempotent close, `overlayEnabled` back to false; a ready arriving after
expiry is a no-op. FD BR-U8-23 fixes "installed by the controller before the
first `createWindow`" and the named constant. NFR Requirements' performance
target adds "no path may hold `Opening` longer than the bound" — so the bound
must cover `createWindow`/`setFrame`/`show`, not just the handshake wait.
Unsettled: timer field location, start point, and how "cancelled on every
exit from `Opening`" is enforced structurally rather than remembered at four
call sites (Unit 7's NFR Design Q2 chose structural cancellation for exactly
this reason — Unit 6's own history contains a remembered-step omission).

A) A `Timer? _readyTimer` field on the controller, started when the open
   guard enters the open sequence (state → `Opening`, **before**
   `createWindow`, so the 10 s bound covers the whole open per the
   performance target). Every state assignment in the controller goes through
   one private `_setState(next)` which, before assigning, cancels
   `_readyTimer` whenever `next is! Opening` — ready receipt (T7), both
   failure exits (T6 `create_failed`, T8 `ready_timeout`), the display-lost
   release (T10) and any future exit path all cancel it structurally, without
   a list of call sites a future edit can miss. `_release` cancels it once
   more defensively. A ready that arrives after expiry is a no-op by
   construction: the handler only acts when `state is Opening` and
   `fromWindowId` equals the current window id. The `Timer` is the
   controller's only time source — no injectable clock (Unit 5's
   `supabase_auth_service.dart` precedent; NFR Requirements Q1).
   **(recommended — Unit 7's `_setState` idiom applied to this controller;
   "no path may hold Opening longer than the bound" becomes structural)**
B) A `Timer` started only after `show()` returns (rejected: a hung
   `createWindow`/`setFrame`/`show` would hold `Opening` forever, violating
   the settled performance bound)
C) Cancel the timer inline at each of the four exit call sites (rejected:
   the remembered-step pattern Unit 7's NFR Design explicitly avoided)

[Answer]: A

### Design Q3: How is the `'-1'` close signal and the ignored-error rule (BR-U8-04, B-5) implemented at the seam, and what happens to a pre-ready `'-1'`?

BR-U8-04 fixes: after the ready handshake, a `PlatformException` with code
`'-1'` from any `invokeMethod`/`setFrame`/`closeWindow` on the window is the
*only* close signal; the controller converts it to `WindowClosed` and must
not propagate it into the shell's `unawaited` calls; no ping probe. B-5 fixes:
any other `PlatformException` is logged as a fixed string and ignored.
Unsettled: where the catch-and-map lives (one seam vs per-call-site), and
what a `'-1'` received **before** ready means — BR-U8-04 scopes its rule to
"after the ready handshake", and B-5 says a sub-engine that dies before its
handler is "caught by the same timeout, not by a separate mechanism".

A) **One catch-and-map wrapper at the seam.** Every post-ready window-service
   call the controller makes (`invokeMethod` for `captionUpdate`, `setFrame`
   for open/reframe, `closeWindow`) goes through one private
   `_windowCall(String operation, Future<void> Function() call)`: on
   `PlatformException` with code `'-1'` the wrapper performs the
   `WindowClosed` transition (only when the state is `Open` — i.e. post-ready
   — per BR-U8-04's own scoping) and never rethrows; on any other
   `PlatformException` it logs a fixed string plus `${e.runtimeType}` and
   ignores (B-5). `createWindow`'s throw is caught in the open sequence
   itself (T6 → `Failed(create_failed)`), not by the wrapper. A `'-1'`
   received while still `Opening` (the window died before ready) is logged
   with a fixed string and **otherwise ignored** — the ready timeout resolves
   the open at the bound, exactly as B-5 prescribes ("caught by the same
   timeout, not by a separate mechanism"); no second failure mode is
   invented. Nothing the controller awaits from a window call can throw into
   the shell's `unawaited` chain. **(recommended — one seam, so the
   BR-U8-04/B-5 rules live in one place FP-5 can exercise through every
   command; the pre-ready `'-1'` reading follows directly from the two
   settled rules rather than guessing a new one)**
B) Per-call-site try/catch blocks (rejected: four call sites, one rule —
   drift risk the same as Unit 6's Rule 2 table correction)
C) Treat a pre-ready `'-1'` as an immediate `Failed` (rejected: invents a
   failure mode and a reason code outside BR-U8-03's fixed pair, and
   contradicts B-5's "caught by the same timeout")

[Answer]: A

## Scalability Patterns (restated from NFR Requirements — no new pattern)

Evaluated, not skipped. NFR Requirements NFR-2 fixed scalability as N/A with
evidence: at most one secondary window (BR-U8-01's open guard), one
display-list subscription (the controller-lifetime `changes` watch, Design
Q1), one method handler on the main engine (BR-U8-23), one ready `Timer`
(Design Q2), one coalescing `Timer` (Design Q4). No queue, pool, cache,
concurrency axis, or unit-owned limit is introduced; the source buffer is
capped by the shipped `maxBufferSegments` (2000) and a multi-monitor setup is
a configuration of one window, not a scaling axis. Nothing in the designs
above changes that. No cache, queue, batching pool, or circuit breaker is
added at this stage.

## Performance Patterns

### Design Q4: How is "at most one `captionUpdate` per animation frame" implemented, and where do the three named constants live?

NFR Requirements Q5 fixed the targets: ≤1 `getAllDisplays()` per platform
event and 0 polls (adapter contract — settled in the FD's event contract,
restated, not redesigned here); open bounded by the 10 s constant (Design
Q2); **≤1 `captionUpdate` per animation frame (60 Hz → at most 60 pushes/s)
regardless of upstream recognition rate**; every payload under
`maxEncodedBytes` = 16 KiB; the state machine synchronous per event. The
FD's §3 says the target "asks the controller to push it (`captionUpdate`),
debounced per animation frame". Unsettled: the mechanism (a plain reset
timer would *never fire* under a continuous stream of events arriving faster
than the interval — the Phase 1 `OnScreenCaptionTarget` 50 ms reset-timer
debounce has no such hazard because recognition output is bursty, but the
settled target says "regardless of the upstream recognition event rate"),
and the file placement of the three named constants.

A) **Dirty-flag plus one re-arming timer in the controller.** The controller
   keeps one field, the latest snapshot the target pushed
   (`push(CaptionOverlaySnapshot)` stores it unconditionally — while closed
   it *is* the held snapshot T7 sends on ready). While `Open`, `push` also
   arms a single `Timer` of `captionUpdateInterval`
   (`const Duration(milliseconds: 16)` — one 60 Hz frame) if none is active;
   pushes arriving while it is armed only update the stored snapshot. On
   fire, the controller sends exactly one `captionUpdate` carrying the
   latest stored snapshot (through the Design Q3 seam) and disarms. At most
   one send per 16 ms window holds under *any* upstream rate, including a
   continuous one, and a stream that stops flushes its last state within one
   interval. The timer is cancelled in `_release` (Design Q1) and in
   `dispose()`. Driven by `fakeAsync` in FP-5 (the controller has no other
   time source; a `SchedulerBinding` frame callback would not be drivable in
   the controller's unit tests, which is why the Phase 1 `Timer` idiom is
   ported rather than the frame-scheduler idiom).
   **Constant placement:** `overlayReadyTimeout` (`const Duration(seconds:
   10)`) and `captionUpdateInterval` as named top-level constants in
   `overlay_window_controller.dart` (the controller owns both behaviours;
   BR-U8-23's "named constant"); `maxEncodedBytes` (`16 * 1024`) as a
   `static const` on the codec in `caption_overlay_codec.dart` (mirrors
   `CaptionWireCodec.maxEncodedBytes` placement — the codec is the
   enforcement point on encode and decode). **(recommended — the
   re-arming shape is the minimal one that satisfies "regardless of the
   upstream rate" while staying a single `fakeAsync`-driven `Timer` per
   NFR Requirements Q1/Q5)**
B) A plain reset `Timer` per push (the Phase 1 debounce shape; rejected:
   under a continuous event stream shorter than the interval it never fires
   and the window starves — violates the settled "regardless of the upstream
   rate" target)
C) `SchedulerBinding.addPostFrameCallback` (rejected: not drivable by
   `fakeAsync` in the controller's unit tests, and adds a Flutter-binding
   dependency to a plain class the FP-5 harness constructs directly)

[Answer]: A

## Security Patterns

Evaluated, applicable (BR-U8-18, SECURITY-03/05/15, the
`signed-out-only` BR-U8-14). No new logging infrastructure — the settled
NFR Requirements Q6 directive is restated here as an implementation rule for
every new call site, with the audit test's shape fixed.

### Design Q5: What exactly does the BR-U8-18 redaction audit test drive and assert?

NFR Requirements Q6 fixed: fixed string + error type at every new call site;
never logged — caption text, the snapshot, the raw launch argument, a
`DisplayInfo.label` inside an error message, or a platform-channel exception's
full `toString()`; `OpenFailed.reason` a short fixed code; a redaction test
drives the decode-failure path, the open-failure path and the release path
and asserts nothing carries an in-flight caption string — "against the actual
`logging` records (a capturing `Logger.onRecord`)". Unsettled: the sentinel
mechanics and the exact assertion set.

A) **One audit test with a sentinel caption string**
   (`external_display_redaction_test.dart` in `test/output/overlay/`):
   registers a capturing `Logger.root.onRecord` listener into a
   `List<LogRecord>` (the Unit 7 pattern,
   `viewer_session_notifier_test.dart:572-587`), then drives, with the
   sentinel embedded in the in-flight snapshot/launch argument: (a) a
   `captionUpdate` decode failure and a launch-argument decode failure
   (sub-engine side — the fixed `invalid_window_arguments` log), (b) the
   open-failure paths (`createWindow` throws → `create_failed`; ready
   timeout → `ready_timeout`), and (c) a release path with a throwing
   `closeWindow`. Asserts: no `LogRecord.message` and no `LogRecord.error`
   string contains the sentinel; every `OpenFailed` emitted carries `reason`
   in the fixed set `{create_failed, ready_timeout}`; `DisplayLost.displayId`
   is the opaque id, never a label or caption. The widget-key/semantics half
   of BR-U8-18 is covered structurally: no widget in this unit takes caption
   text into a key or semantics label (the controls render status copy only,
   and the overlay window's own content is the window, not a key source) —
   stated in the test's doc, not re-grepped. **(recommended — the Unit 7
   pattern applied to this unit's three named paths; the assertion set is
   BR-U8-18's own scope list, nothing invented)**
B) Source-grep assertions over the new files (rejected: NFR Requirements
   Q6 explicitly chose record-level assertions — greps pass while a future
   edit regresses, and fail on harmless string literals)
C) Per-path redaction tests, one per call site (rejected: duplicates the
   capture harness; the three driven paths already exercise every new log
   site the FD names)

[Answer]: A

The fixed-string call-site list for Code Generation (BR-U8-18 / Q6):
controller open-failure and release steps (fixed string + `runtimeType`),
the ignored non-`'-1'` `PlatformException`s (Design Q3), the pre-ready `'-1'`
(Design Q3), the `ScreenRetrieverDisplayEnumerator`'s platform failure
(fixed `warning`, stream stays open — FD event contract), the sub-engine's
launch-decode failure (`invalid_window_arguments`, fixed), and the
`displaySettings`/main-target reads (no log). `OpenFailed.reason` ∈
{`create_failed`, `ready_timeout`} only.

## Logical Components

### Design Q6: Where does the controller live in the provider graph, and what are the constructor seams and the shell wiring?

The FD fixes `OverlayWindowController` as "a plain class on the shell's
`ProviderContainer` (the app-lifetime service pattern), not a target" and
`CaptionOverlayTarget` as a thin delegator + caption-bus adapter whose
`show`/`hide` the "shell drives from `_syncOverlay`, as today". NFR
Requirements Q1 fixes the test seams: the controller runs real against
`MockDesktopWindowService` (+`setFrame`/`show`), a hand-written
`FakeDisplayEnumerator`, and "the settings notifier via the standard provider
override". Unsettled: the provider kind, the constructor parameter list, how
the shell reaches the controller and reacts to its events, and how the target
reads the main window's captions and the display settings (BR-U8-12) without
a `BuildContext`.

A) **One hand-written `Provider`, app-lifetime, with constructor seams.**
   `overlayWindowControllerProvider` (a hand-written
   `Provider<OverlayWindowController>` in
   `lib/src/providers/overlay_window_controller_provider.dart` — the
   controller is a plain class, not a `Notifier`, and the project already
   uses hand-written `Provider`s for service objects:
   `onScreenCaptionTargetProvider`, `transcriptWriterTargetProvider`,
   `displaySettingsProvider`):
   constructs the controller with `windowService: DesktopMultiWindowService()`
   (the shipped conditional export — io or stub, never a `kIsWeb` check,
   BR-U8-11), `enumerator: ScreenRetrieverDisplayEnumerator()` (the new
   conditional export pair, io/stub), `handlerInstaller:` from the same
   conditional export pair (Design Q7), `log: Logger('zip_broadcast.OverlayWindowController')`;
   registers `ref.onDispose(controller.dispose)` (the
   `transcriptWriterTargetProvider`/`onScreenCaptionTargetProvider`
   register-then-`onDispose` idiom). Lazily created on first read (the
   controls reading it at panel mount), alive for the app container. The
   controller's constructor: `(DesktopWindowService windowService,
   DisplayEnumerator enumerator, {required OverlayMethodHandlerInstaller?
   handlerInstaller, required Logger log})` — every collaborator injectable,
   so FP-5 needs no plugin.
   **Shell wiring** (additive edits to `ZbAppShell`): `_overlayTarget` is
   constructed with the controller, the registry and a
   `DisplaySettings Function()` reader (`() => ref.read(displaySettingsProvider)`);
   `_syncOverlay(true)` additionally calls `target.show(config)` after
   `registry.add` (config built from the settings state:
   `ExternalDisplayMode(displayId: settings.externalDisplayId)` + the
   persisted caption position as `OverlayPositionTop/Bottom`), and
   `_syncOverlay(false)` keeps its shipped `hide()`. The shell subscribes to
   `controller.events`: `WindowClosed`/`OpenFailed` → write
   `overlayEnabled = false` through the settings notifier (the existing
   `ref.listen` then runs `_syncOverlay(false)` — BR-U8-15's "shell's
   existing `_syncOverlay` path clears `overlayEnabled` and deregisters the
   target"); `DisplayLost` → update the shell's `_overlayRegistered`
   bookkeeping flag (the controller already released; `overlayEnabled` stays
   true, D-4 — no settings write). **Target constructor:**
   `CaptionOverlayTarget({required OverlayWindowController controller,
   required CaptionOutputTargetRegistry registry, required DisplaySettings
   Function() displaySettings})`; `show`/`hide`/`events` are thin
   delegators to the controller; `onCaptionEvent` builds the snapshot from
   `registry.activeTargets.whereType<OnScreenCaptionTarget>().firstOrNull`'s
   `visibleCaptions` (split into final entries + trailing interim), the
   current `activity` (a pure `RecordingState` → `OverlayActivity` mapping
   held on the target, updated by `SessionStateEvent` — which therefore never
   pushes a snapshot on its own, per the FD) and `displaySettings()`, then
   `controller.push(snapshot)`; `dispose()` delegates to the idempotent
   `controller.close()` without blocking the registry's synchronous
   `dispose()` call. **(recommended — one provider, every collaborator a
   constructor seam, the shell's shipped `_syncOverlay`/`ref.listen`
   machinery reused verbatim, and BR-U8-12's reads resolved through objects
   the shell already holds — no `BuildContext`, no new zip_core surface)**
B) A `@Riverpod(keepAlive: true)` generated notifier (rejected: the
   controller is a plain class by the FD's fixed shape; `@Riverpod` generates
   a `Notifier` subclass with a `build()` contract the design does not need)
C) The shell constructs the controller as a field, as it does the target
   (rejected: `ExternalDisplayControls` — a widget in `OutputTargetsPanel` —
   must watch the controller's status and NFR Requirements Q2 requires
   provider overrides in the widget tests; a shell field is unreachable from
   the provider graph)

[Answer]: A

### Design Q7: How does the controller satisfy BR-U8-23's "exactly one `DesktopMultiWindow.setMethodHandler`, installed by the controller before the first `createWindow`" without touching the plugin in tests?

B-5/BR-U8-23 fix: one handler on the main engine, installed by the
controller before the first `createWindow`; the sub-engine's `overlayReady`
arrives through it; a sub-engine that dies before installing its handler is
caught by the same timeout. NFR Requirements Q1 forbids `desktop_multi_window`
in the controller's unit tests. `DesktopMultiWindow.setMethodHandler` is a
static taking
`Future<dynamic> Function(MethodCall call, int fromWindowId)?` (verified,
0.2.1) — a `null` argument unregisters. Unsettled: the seam type, the
production adapter's location, and the failure mode if the seam is absent on
a supported platform.

A) **An installer seam in the controller's constructor.**
   `typedef OverlayMethodHandler = Future<void> Function(String method, int
   fromWindowId);` and `typedef OverlayMethodHandlerInstaller = void
   Function(OverlayMethodHandler? handler);` in
   `overlay_window_controller.dart`. The controller calls the installer once,
   on the first open, **before `createWindow`** (BR-U8-23), passing its
   handler; the handler acts only on `method == 'overlayReady'` with
   `fromWindowId` equal to the current window id and state `Opening` (Design
   Q2), and is inert for anything else. The production adapter lives in
   `desktop_multi_window_service_io.dart` (which already imports
   `desktop_multi_window` — no new import surface): a top-level
   `OverlayMethodHandlerInstaller` that wraps
   `DesktopMultiWindow.setMethodHandler`, adapting `MethodCall` →
   `(call.method, fromWindowId)`; the stub file's version is a no-op, and
   both are surfaced through the existing conditional-export file
   (`desktop_multi_window_service.dart`). `controller.dispose()` passes
   `null` (uninstall). If the installer is `null` on a platform whose
   `isSupported` is true (unreachable in the shipped pair, but the shape must
   be fail-closed), the open is refused as `Failed(create_failed)` before
   any `createWindow` call — the handler is a precondition of the open, and
   no window is left half-open. The FP-5 world uses a
   `FakeOverlayMethodHandlerInstaller` that records the installed handler so
   the trial can invoke `handler('overlayReady', id)` directly — the
   handshake then runs real inside the controller. **(recommended — one
   static, one owner, one seam; the plugin's static is touched exactly once
   in the production codebase, in the file that already owns the plugin
   import for this feature)**
B) Let the controller call `DesktopMultiWindow.setMethodHandler` directly
   (rejected: FP-5 would instantiate the plugin's method channel in a unit
   test — exactly what NFR Requirements Q1 rules out)
C) Put the handler installation in the provider (rejected: BR-U8-23 assigns
   the installation to the controller "before the first createWindow" — the
   provider constructing it earlier would separate owner from obligation)

[Answer]: A

### Design Q8: What is the pure BR-U8-07 resolution function — name, signature, placement?

NFR Requirements FP-4 needs the open-time resolution as a pure function
("list + persisted id → resolved target + keep decision") the property can
call directly; the stage-handoff note says "NFR Design names it". BR-U8-07
fixes the rule: the id in `externalDisplayId` if present in the current
list; otherwise the primary if one exists; otherwise the first display in
platform order; an absent value is **kept** (never cleared or replaced except
by an explicit user selection).

A) **`resolveOpenDisplay(List<DisplayInfo> displays, String? persistedId)`
   returning a record `({DisplayInfo? target, bool persistedIdPresent})`**,
   a top-level pure function in `overlay_window_controller.dart` (its only
   caller; the FP-4 test imports it directly). Rules: empty list →
   `target: null` (the caller renders `NoDisplays` or waits);
   `persistedId` non-null/non-empty and present → that display,
   `persistedIdPresent: true`; else the first `isPrimary` display; else the
   first display in platform order. The function never returns a cleared or
   replaced id — "kept" is expressed as the absence of any write path:
   nothing in the open sequence writes `externalDisplayId`, and FP-4
   asserts, over generated lists and persisted ids (present, absent, empty),
   that the chosen `target.id` follows BR-U8-07 exactly and that
   `persistedIdPresent` is true iff the id is in the list. No state, no I/O,
   no clock. **(recommended — one name, one signature, the rule verbatim;
   the record shape gives FP-4 both the target and the "is this the id
   `WaitingForDisplay` waits for" fact without a second lookup)**
B) A method on `OverlayWindowController` (rejected: FP-4 must call it without
   constructing the controller and its fakes)
C) A free function in a standalone file (rejected: one caller — co-located in
   the controller file keeps the rule and its enforcement adjacent, matching
   how `toPlatformFrame` sits in the io file that uses it)

[Answer]: A

### Design Q9: What is the exact test-helper set, the domain generators, and the FP-5 harness shape?

NFR Requirements Q1/Q2/Q8 fixed: `MockDesktopWindowService` extended for
`setFrame`/`show` (B-6), a hand-written `FakeDisplayEnumerator` (scriptable
`displays()` + pushable broadcast `changes`), the settings notifier by
provider override, `fakeAsync` for the ready-timeout and FP-5 suites,
`mocktail` available, generators centralized in the existing
`test/helpers/generators.dart`, and FP-5 "in the
`viewer_session_state_machine_properties_test.dart` shape". Unsettled: the
fakes' exact contracts, the handler-installer fake, the generator list, and
the FP-5 command set.

A) **Fakes** (all in `test/helpers/`, the existing file naming):
   - `mock_desktop_window_service.dart`: **no class change** — mocktail's
     `Mock` covers the additive `setFrame`/`show` interface methods via
     `noSuchMethod`; "extended in place" means the interface edit (B-6)
     makes the mock cover them, and the test files add `when(...)` stubs and
     `verify` counts for the two new methods (one step with the B-6 edit, per
     NFR Requirements).
   - `fake_display_enumerator.dart` (new): implements `DisplayEnumerator` —
     a scripted `displays()` result plus an optional scripted error, a
     broadcast `StreamController` with a `pushDisplays(List<DisplayInfo>)`
     helper that **replays the latest list to late subscribers** (mirroring
     the FD event contract's "first emission" clause, which the controller's
     bootstrap relies on — Design Q6), and `dispose()` recorded and
     idempotent.
   - `fake_overlay_method_handler_installer.dart` (new, small): records the
     installed `OverlayMethodHandler` (and the uninstall), exposing it for
     the trial to invoke.
   **Generators** (appended to `test/helpers/generators.dart`):
   `arbitraryDisplayInfo` / `arbitraryDisplayList` (0..n; at most one
   `isPrimary`, at any position; empty labels; ids including
   Linux-normalised `display-<n>` and `""`; work-area bounds; scale factors
   0/1/1.5/2), `arbitraryCaptionOverlaySnapshot` (any activity, 0..max
   entries, multibyte text, any `DisplaySettings` combination),
   `arbitraryOverlayWindowLaunch` (mode, position),
   `arbitraryMalformedWindowJson` (truncated, wrong field type, unknown `v`,
   unknown enum for `activity`/`settings`/`position`/`mode`, over-size
   beyond `maxEncodedBytes`), `arbitraryLogicalFrame` (arbitrary top-left
   `Rect` plus platform inputs — primary full height, target scale —
   including macOS negative-result and Windows mixed-DPI cases), and
   `arbitraryExternalDisplayCommandSequence` (the FP-5 command set, varying
   length including empty).
   **FP-5 harness**: a `_World`-shaped class per Glados trial, **wrapped in
   one `fakeAsync` per trial** (the `viewer_session_state_machine_properties_test.dart`
   shape, which this unit adopts because the command set contains timer
   expiry): the world constructs the real controller directly on the fakes
   (no `ProviderContainer` — the controller is a plain class), a real
   `CaptionBus` + real `CaptionOutputTargetRegistry` (in-memory, no I/O —
   Unit 7 kept the caption pipeline real for the same reason), and a harness
   `overlayEnabled` flag that models the shell's documented reaction to
   emitted events (`WindowClosed`/`OpenFailed` → the flag goes false, as the
   shell's `_syncOverlay` path does — without it BR-U8-15's invariant
   "at every point where `overlayEnabled` is false" could not be checked at
   the controller level). Commands: `toggleOn`/`toggleOff` (drive the
   target's `show`/`hide` delegations, exactly what `_syncOverlay` does),
   `displaysChanged(list)` (push into `FakeDisplayEnumerator.changes`),
   `overlayReady` (invoke the recorded handler), `advanceReadyTimeout`
   (elapse `overlayReadyTimeout` + 1 ms), `windowGone` (script the next
   window call to throw `PlatformException(code: '-1')`),
   `otherPlatformError` (script any other code), `createWindowFails`
   (script a throw), `captionEvent` (push a snapshot through the target),
   `elapse(ms)`. Invariants after **every** command: only declared
   `ExternalDisplayStatus` variants are reached (sealed switch — an unknown
   runtime type fails the trial); exactly one state at a time (the controller
   holds one field); the closed invariant (BR-U8-15: `!controller.isWindowOpen`
   ∧ target not in `registry.activeTargets` ∧ `target.isVisible` false) at
   every step where the harness flag is false; a second concurrent open is
   refused (BR-U8-01: a `toggleOn` while `Opening` leaves
   `createWindow`'s call count unchanged); the saved id is never written by
   the open path (the fake settings recorder sees no
   `externalDisplayId` write from any command except an explicit
   `selectDisplay` command the world issues for the user-action case).
   PBT-04's idempotence (close from closed, toggle-off from `Off`, a second
   `closeWindow` on a released id) is asserted inside these sequences and
   once directly. **(recommended — the Unit 7 world/command/invariant
   pattern applied to this controller's command set, with the shell
   reaction modelled so BR-U8-15 is checkable end-to-end without a widget
   tree)**
B) A `ProviderContainer`-based world (rejected: the controller is a plain
   class with constructor seams; a container would test the provider, not
   the machine)
C) Example-based close-path tests only, no stateful suite (rejected: FP-5 is
   a settled PBT-01 property — PBT-10 requires it alongside, not instead of,
   the example tests)

[Answer]: A

## Approval

All nine Design questions answered with the recommended option under the
run-configuration pre-approval (Design Q1–Q9). No answer was ambiguous
enough to need follow-up, and none changes the shape of the revised FD or
the settled NFR Requirements answers — each fills a detail those documents
explicitly deferred (the release step set and `isVisible` representation,
timer cancellation, the catch-and-map seam, the coalescing mechanism and
constant placement, the audit test's shape, the provider graph and seams,
the handler installer, the resolution function's name/signature, and the
test-helper set). One minimal-interpretation call is recorded for the
morning review: BR-U8-12's "caption position … must reach the window without
a reopen" is read as "the window applies the persisted position carried in
the launch config at open" — the authoritative B-7 wire shape carries no
position in the snapshot's `settings`, so a position changed while open
takes effect at the next open (no mechanism beyond the settled shape is
invented; see `nfr-design-patterns.md` "Open questions carried to
Infrastructure Design" and the run report's ASSUMPTIONS).

Carried into `nfr-design/nfr-design-patterns.md`, `nfr-design/
logical-components.md`, and `nfr-design/handoff-summary.md`.
