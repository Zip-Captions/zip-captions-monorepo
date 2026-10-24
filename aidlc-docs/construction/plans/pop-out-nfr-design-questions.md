# NFR Design Questions — Unit 8.1: Pop-out Live Captions (S-21)

**Date**: 2026-10-21
**Stage**: NFR Design (Stage 3 of 6)
**Plan**: `aidlc-docs/construction/plans/pop-out-nfr-design-plan.md`

Please answer each question by putting the letter after the `[Answer]:` tag. If none of the options
fit, choose the last option (Other) and describe what you want after the tag. Let me know when you
are done.

**Conventions used below**: "FD" is `aidlc-docs/construction/pop-out/functional-design/`; "NFR-R"
is `aidlc-docs/construction/pop-out/nfr-requirements/`; "review" is
`aidlc-docs/construction/plans/pop-out-pre-build-review.md`. Recommendations are marked
**(recommended)**; they are not answered for you.

**What is already decided and is not asked again**: the six `_isPopOut` guards with mode fixed at
construction (R-M2); the router's `int? get windowId` + token-bound installer at `_bootstrap` with
null never matching (R-M3); the shell-computed frame with a per-platform chrome allowance (R-M5);
`configure` before ready for both modes with `ExternalDisplayMode` pinned to
`floating: false, decorated: false`; the first-party `subWindowClosed {windowId}` main-engine channel
with `'-1'` as fallback; `package:zip_core/overlay.dart` as a separate library (R-M7); the seven
permitted controller deviations. This file only asks what those decisions leave undecided.

---

## Part D — The carried open item

## Question D1
Where is the `SubWindowClosedChannel` listener registered, and who owns its lifetime?

The constraint that makes this a real question: `desktop_multi_window.createWindow` is reached from a
widget-triggered toggle (FD BLM §3, the shell's `_syncOverlay` path), so the first sub-window can be
created at any point after `runApp`. A channel registered inside a provider that is only touched when
the toggle is pressed would be listening *after* the window exists — and a window closed inside that
gap is never reported.

A) **Register at startup, in `main`, immediately after `WidgetsFlutterBinding.ensureInitialized()`
   and before the overlay-launch check, in both apps.** One `zip_core` function
   (`installSubWindowClosedChannel({required void Function(int windowId) onClosed})` returns a
   `void Function()` disposer) creates the `MethodChannel`, sets its handler, and returns the
   disposer. `main` holds the disposer and calls it once, after the container it feeds is disposed:
   in `zip_broadcast`, after `runApp` (nothing disposes the root `ProviderScope` in practice, so the
   disposer exists for the `runZipCaptions`/`runZipBroadcast` test seams and for a future explicit
   teardown); in `zip_captions`, inside the same place its new `runZipCaptions(args, …)` seam ties off
   the container. The handler holds the app's `ProviderContainer` (not a widget `ref`), reads the
   controller lazily on each event, and therefore survives any controller rebuild. Registered before
   any widget exists, hence before any toggle can be pressed.
   **(recommended — the only placement that satisfies "listening before any sub-window can be
   created" without a second registry of listener state; it is also testable, because the seam takes
   the callback as a parameter and the test can invoke it directly with a `ProviderContainer`)**

B) **Register lazily, inside the keepAlive provider that owns the router and enumerator (NFR-R
   §10.1), with `ref.onDispose` releasing it.** The provider is first read when the shell builds, so
   the channel exists before any toggle — but not before `main` finishes, and the provider could in
   principle be disposed and rebuilt (it is `keepAlive`, so it is not). Lifetime is Riverpod's
   problem rather than `main`'s. Requires an eager read of the provider at startup anyway to close
   the gap, which reintroduces A's placement with an extra indirection.

C) **Register on the controller's first `open()`.** Simplest, and wrong for the reason above: a close
   that lands between `createWindow` returning and the register call is lost, and the `'-1'` fallback
   only fires on the next window call — which never comes while the session is paused. Record the
   gap as an accepted limitation if chosen.

D) Other (please describe after [Answer]: tag below)

[Answer]: B (corrected — see note 1)

---

## Part R — Resilience

## Question R1
Where does the `subWindowClosed` event enter the controller, given that the channel is registered
before any controller exists?

The shipped controller is a constructed object whose public surface today is `open`/`close`/`dispose`
/streams (FD BLM §4.1). `onNativeWindowClosed(int)` is already a permitted deviation. What is not
settled is how a process-lifetime channel reaches one (or, after this unit, two) controllers.

A) **One process-level dispatcher in `zip_core`, fanning out to registered controllers.** The
   `SubWindowClosedChannel` instance holds a `Set<void Function(int)>`; each controller subscribes
   its own `onNativeWindowClosed` during `_bootstrap` and unsubscribes in `dispose`. An id that
   matches no controller is dropped **by construction** (no subscriber matches), which is exactly
   NFR-R §3.1's "unknown id: dropped, no state change, no log at info and above". Registration is
   per-controller and cleaned up per-controller, so two controllers (external display + pop-out)
   both see every close and each keeps the id that matters.
   **(recommended — matches the router's own shape (NFR-R §10.1, BR-U8.1-04: one owner per engine,
   per-controller registration), keeps the drop rule structural rather than a check, and needs no
   `ProviderContainer` inside the handler)**

B) **The channel calls the router: add a `subWindowClosed` case to `OverlayMethodRouter`.**
   Rejected by the approved design: FD BLM §3.2 says the event "does **not** flow through
   `OverlayMethodRouter` or `_handleWindowCall`". Listed only because it is the cheapest option, and
   choosing it would require reopening that decision.

C) **The channel calls a single app-level notifier that owns both controllers**, and the notifier
   forwards by id. Puts a third owner next to the provider that already owns both controllers
   (NFR-R §10.1), for no behaviour A does not already give.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

---

## Part P — Performance

## Question P1
How is the shell-computed frame passed to `open()`, and what does the controller do when it is
missing?

R-M5 fixes *who* computes the frame (the shell) and *what* it means (content size + chrome
allowance). It does not fix the seam's signature or the missing-frame case — and "missing" is reachable,
because `open()` is also called by tests and by the moved Unit 8 suite.

A) **`open(OverlayConfig config, {Rect? frame})` exactly as FD BLM §2 pins it; `frame == null` keeps
   today's external-display path** (`resolveOpenDisplay` → display work area). For `PopOutMode` with a
   `null` frame, `_runReady` falls back to the window's current frame without calling `setFrame` (the
   plugin already placed the window; refusing the open would fail a working window for a cosmetic
   reason). No assertion, no throw, one fixed-string warning at `fine` level.
   **(recommended — the signature is already approved; the fallback keeps the pop-out openable from
   any caller without inventing a second failure mode, and the *production* caller always passes a
   frame, so the fallback is unreachable in the app)**

B) **Same signature; `PopOutMode` + `null` frame is a programming error that fails the open as
   `create_failed`.** Fail-closed and loud. Costs: the moved Unit 8 tests that open a pop-out
   controller directly must all pass a frame, and a future caller that forgets gets a user-visible
   error for a bug in our own code.

C) **`PopOutMode` carries the frame as a field** (`PopOutMode(frame: …)`), so `open()` keeps its
   exact shipped signature. Reopens Q1's "field-less sibling" decision (FD domain-entities §1.3) and
   BR-U8.1-08's codec shape; listed for completeness.

D) Other (please describe after [Answer]: tag below)

[Answer]: A (corrected — see note 2)

## Question P2
The toggle must reach `Opening` "in the same frame" (NFR-R §2). What does the shell do while the pop
-out's engine gate and settings are still loading?

`OutputTargetSettingsNotifier.build()` returns defaults synchronously and loads asynchronously
(`broadcast_providers.dart:107-111`), and FD §3.1/RQ-2 A makes the engine gate a per-app provider.
The frame that matters is the one where the user presses the toggle, not the app's first frame.

A) **The toggle is only enabled when its gate has resolved**, and enabling happens without an
   `await`: the gate is read synchronously (`ref.watch`) so `popOutAvailability` is a pure function of
   already-loaded state, and the shell's press handler does `open()` with no `await` before it. The
   "same frame" target is then measured from a press on an enabled control only, and an
   un-loaded gate renders the disabled control with its reason (UX-PIP-03/04 already require a
   visible reason). No spinner, no "loading" state, no new state machine.
   **(recommended — the target is asserted where it can be, the disabled-plus-reason state is already
   in the contract, and nothing has to be kept pending across an async gap)**

B) **The toggle is enabled immediately and the press is queued until the gate resolves.** One frame
   later at best; violates the ordering target in the case it was written for.

C) **Endorse a startup budget instead**: hold the shell's first paint until the gates are loaded. NFR-R
   §2 rejected a startup budget (Q7 B), so this would reopen it.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question P3
The per-platform chrome allowance: what shape, and where does the value come from?

FD BLM §3.4 requires named constants with a table test, documented as content-size semantics, with
Infrastructure Design verifying the values and Unit 9 measuring them.

A) **One `const Map<TargetPlatform, EdgeInsets>`-free holder: three `double` constants on
   `PopOutGeometry` (`chromeTopInsetMacos`, `chromeTopInsetWindows`, `chromeTopInsetLinux`, plus a
   single `chromeBorderInset` for Windows/Linux side and bottom borders), selected by one pure
   function `EdgeInsets chromeAllowance(TargetPlatform platform)` that falls back to
   `EdgeInsets.zero` for unknown platforms.** Initial values are documented estimates
   (macOS 28, Windows 31 title bar + 8 borders, Linux 37 + 1 border) marked `// verified in ID`,
   and the table test asserts the selection and that the pop-out's content height is unchanged by
   the allowance. The controller never sees them.
   **(recommended — one place, pure, table-testable, and the value's provenance is visible in the
   code rather than hidden in a geometry expression)**

B) **A single platform-agnostic allowance** (one constant, for all three). Simpler, but wrong on at
   least one platform and invites a "fix" in `computePopOutFrame` later.

C) **Derive it from the window's own `window.getFrame()` minus `getClientArea()` at runtime.** The
   most accurate, but it needs a window call on the open path (a third failure mode NFR-R §10.3
   deliberately avoided for the centre parameter) and is not computable before `createWindow`.

D) Other (please describe after [Answer]: tag below)

[Answer]: A (corrected — see note 3)

---

## Part L — Logical components, and the security decisions they carry

## Question L1
What does `configure` do with a `windowId` that is not the window it was invoked for?

The channel is registered on the sub-engine's own messenger, so the runner can only act on the window
whose view created it. The `windowId` parameter exists to tag the close event (FD BLM §3.2), and
`tech-stack-decisions.md` §5 says a handler "can only act on the window whose view it was created
with". A mismatch is therefore either an impossible state or a signal that the id plumbing is broken.

A) **Ignore the parameter for styling; use it only for the close event's tag. Mismatches are not
   checked.** The handler styles `controller.view.window`/`GetAncestor(view, GA_ROOT)`/
   `gtk_widget_get_toplevel(view)` unconditionally, and remembers the argument's `windowId` for the
   close notification. Matches what the native layer can actually address.
   **(recommended — it states the truth of the platform instead of inventing a check that can only
   ever pass; and the style call is a no-op-safe operation on the window it owns)**

B) **Check it**: the runner compares the argument against the id `desktop_multi_window` embedded in
   the sub-engine's `argv`, and refuses to style on mismatch. Adds a native read of `argv` in the
   runner, which the plugin does not expose portably, for a check whose failure mode is "the window
   is undecorated".

C) **Drop the parameter from `configure` entirely**; the close event carries no id and the Dart side
   attributes it by arrival order. Reopens the FD's pinned channel contract and makes the id-match
   rule in `onNativeWindowClosed` unenforceable.

D) Other (please describe after [Answer]: tag below)

[Answer]: A

## Question L2
What is the concrete provider shape for the router + enumerator owner (NFR-R §10.1), and how do the
apps' controller providers use it?

A) **One `@Riverpod(keepAlive: true)` `overlayWindowHost(Ref)` provider in `zip_core`, returning a
   `OverlayWindowHost` object that owns the router and the single enumerator and exposes
   `OverlayWindowController createController({required OverlayWindowMode mode, required String logPrefix})`
   plus `void dispose()` via `ref.onDispose`. Each app keeps a thin keepAlive provider per controller
   that calls `host.createController(mode: …)` and registers `ref.onDispose(controller.dispose)`;
   `zip_broadcast`'s existing `overlayWindowControllerProvider` keeps its name and its `displayList`/
   `externalDisplayStatus` dependents. The host also exposes `Stream<List<DisplayInfo>> get displays`
   so the enumerator is not reachable as a mutable field (`displayList` today reads
   `controller.enumerator.changes`).
   **(recommended — one owner for the one platform observer and the one static handler slot, the
   existing provider names and dependents survive, and the enumerator's ownership is visible in the
   type rather than in a comment)**

B) **Two separate keepAlive providers** (`overlayMethodRouterProvider`, `overlayDisplayEnumeratorProvider`)
   that both app-level controller providers `ref.watch`. More granular, but puts the
   "one enumerator, one observer" invariant back on every caller to respect — the exact repetition
   §10.1 exists to remove.

C) **No provider in `zip_core`**: keep the construction in each app (today's shape) and have both
   apps repeat the router/enumerator wiring. Rejected by §10.1 (it repeats the invariant in two
   apps).

D) Other (please describe after [Answer]: tag below)

[Answer]: A (with SubWindowClosedChannel, per D1)

## Question L3
How does `zip_captions` remember "popped out" for the process lifetime?

FD BLM §5 says a `popOutNotifierProvider` (in-memory `Notifier<bool>`); FD §1.3 says it lives in the
new app-level notifier; Q10 B forbids persistence.

A) **A `@Riverpod(keepAlive: true)` `Notifier<bool>` in `zip_captions` with a single `toggle()`/
   `set(bool)` method and no persistence call.** The shell listens to it, the `RecordingScreen`
   passes `controls:` from it, and the controller's `events` subscription writes `false` on
   `WindowClosed`/`OpenFailed`. Kept alive so a route change cannot reset it and desynchronise the
   shell from the controller.
   **(recommended — the state's owner is the app, its lifetime outlives the screens that display it,
   and keepAlive is what makes "no persistence" and "correct after navigation" hold together)**

B) **A plain `Notifier<bool>` (auto-dispose)**: the pop-out flag disappears when the last listener
   goes, which is a state inconsistency the moment a screen is popped off the stack.

C) **A field on `ZcAppShell`'s state** (mirroring `zip_broadcast`). `zip_captions`' shell is stateless
   today and its screens are the toggles' siblings (FD BLM §5), so this would require making the
   shell stateful and threading the value to the screens through constructors.

D) Other (please describe after [Answer]: tag below)

[Answer]: A (with the FD §2.2 correction — see note 4)

## Question L4
How does each app's `PopOutCaptionTarget` read the main caption buffer?

FD §5 makes it a sibling of `CaptionOverlayTarget`, which reads
`registry.activeTargets.whereType<OnScreenCaptionTarget>()` and `firstOrNull` (shipped code). That is
an O(n) scan per caption event, and it silently reads nothing when on-screen captions are off (the
target is unregistered in that state — FD BR-PIP-04 requires continuity anyway).

A) **The same read as the shipped `CaptionOverlayTarget`, extracted into one tiny shared helper
   (`OnScreenCaptionSource` in `zip_core` with `List<CaptionDisplayEntry> get visible`, backed by a
   cached lookup invalidated on registry membership change).** Both targets use it; the scan happens
   on membership change, not per event. NFR-R §3.3/BR-PIP-04's continuity test then exercises the
   same code path as the external display. (Shipped form for reference: a `for` loop over
   `_registry.activeTargets` with an `is OnScreenCaptionTarget` check, returning
   `target.visibleCaptions` — `caption_overlay_target.dart:94-102`.)
   **(recommended — one implementation for the one question "what is on screen", which is also what
   makes BR-U8.1-03's "the only per-app duplicates are the adapters" honest rather than optimistic)**

B) **Duplicate the `whereType(...).firstOrNull` line in each target** exactly as shipped. No new
   `zip_core` surface, and the duplication is two lines in each of three classes. Leaves the O(n)
   per event and the three copies of the same rule.

C) **Inject a `List<CaptionEntry> Function()` reader into both targets' constructors** (the option
   NFR-R's FD handoff raised and the owner did not pick for a shared target class). Most flexible,
   most wiring.

D) Other (please describe after [Answer]: tag below)

[Answer]: B (see note 5)

## Question L5
Which channel names, and what is the Dart-side validation rule for `subWindowClosed` arguments? (Two
first-party method channels are new native boundaries; this is the SECURITY-05/SECURITY-13 decision.)

FD BLM §3.2 writes the names as `zip_/overlay_window_configure` and `zip_/overlay_main_window`
("one name per app"), and the payload rules are already implied but not stated as validation.

A) **Names: `io.zipcaptions.broadcast/overlay_window_configure` and
   `io.zipcaptions.broadcast/overlay_main_window` for Zip Broadcast, and
   `com.zipcaptions.zip_captions/overlay_window_configure` and
   `com.zipcaptions.zip_captions/overlay_main_window` for Zip Captions** — each app's existing
   application identifier (verified: Zip Broadcast's URL scheme and `Info.plist` use
   `io.zipcaptions.broadcast`; Zip Captions' Linux `APPLICATION_ID` is
   `com.zipcaptions.zip_captions`, and the two apps' identifiers deliberately differ). **Validation**:
   `configure` arguments arrive as a map
   and are read field-by-field with type and range checks (`windowId` is a non-negative `int`;
   `floating`/`decorated` are `bool`; `minWidth`/`minHeight` are finite, non-negative `double` and
   are clamped to the display's work area by the native side); a malformed call is answered with a
   fixed `FlutterError('configure_invalid')` and nothing is styled. `subWindowClosed` is
   `{'windowId': int}`; the Dart side drops any call whose method is not exactly `subWindowClosed`
   or whose argument is not a map with a single non-negative `int` `windowId`, logging nothing (a
   malformed native call is not caption data and must not become a log line with a payload). No
   argument is ever echoed into an error string.
   **(recommended — a namespaced channel name cannot collide with a third-party plugin, the
   validation is allowlist-by-type, and the "never echo the argument" rule is SECURITY-03's own
   fixed-string discipline applied to a new boundary)**

B) **Keep the short names from FD BLM (`zip_overlay_window_configure`, `zip_overlay_main_window`),
   same validation.** Shorter, no ambiguity today; a bare name is more likely to collide if a future
   package registers the same channel on the same messenger.

C) **Same names as A, but no validation beyond the type cast that throws.** Rejected as a proposal;
   included because it is what the naive implementation would do (SECURITY-05/SECURITY-15).

D) Other (please describe after [Answer]: tag below)

[Answer]: Other — see note 6

---

## Anything else

If a decision you expected to be asked about is missing, say so after the last `[Answer]:` tag. The
carried decisions listed at the top of this file are binding and were deliberately not reopened.

---

## Answers recorded (2026-10-21, James Petersen)

| Q | Answer | Correction applied |
|---|---|---|
| D1 | B, corrected | See note 1 |
| R1 | A | — |
| P1 | A | See note 2 |
| P2 | A | — |
| P3 | A | See note 3 |
| L1 | A | — |
| L2 | A, host also owns `SubWindowClosedChannel` (per D1) | See note 2's constraint |
| L3 | A | See note 4 |
| L4 | B | See note 5 |
| L5 | Other (one name per contract, `<package>/<channel>`) | See note 6 |

**Note 1 (D1 B, corrected).** Option B's own text said the provider "requires an eager read of the
provider at startup anyway to close the gap". The owner removed that premise: there is no gap to
close, because only a controller can create a window, and under R1 A each controller subscribes to
the channel in `_bootstrap`, before it can call `open()`. The `overlayWindowHost` provider (L2 A)
owns the `SubWindowClosedChannel`: the host installs the handler when it is built and releases it
with `ref.onDispose`. No eager startup read, nothing in `main`, nothing on the sub-engine path.
D1 A was rejected because it conflicted with R1 A, because it ran before the overlay-launch check
and so installed the listener in the sub-engine too, and because it needed a `ProviderContainer`
that `zip_broadcast`'s `main` does not have.

**Note 2 (P1 A, corrected).** Two corrections: "one fixed-string warning at `fine` level" becomes one
fixed-string log at `LogRecord` level `FINE`; and the claim that "moved Unit 8 tests open a pop-out
controller" is withdrawn — no such test exists. The open-failure count for the missing-frame case is
unchanged: no failure mode is added.

**Note 3 (P3 A, corrected).** The chrome-allowance constants are **documented estimates**.
Infrastructure Design cannot launch windows, so it can only reason about them; they are marked
**unverified until the Unit 9 measurement**, not "verified in ID". The spec also records that the
Linux value varies by desktop environment and theme.

**Note 4 (L3 A, FD correction).** FD `domain-entities.md` §2.2 must match: the popped-out flag is in
the notifier (`popOutNotifierProvider`), not in the shell. The shell still becomes a
`ConsumerStatefulWidget` because it owns the target and the events subscription — those two facts are
separate, and §2.2 currently reads as though the shell owns both.

**Note 5 (L4 B).** Rejected A on two counts: `CaptionOutputTargetRegistry` exposes no membership-change
signal (only `add`, `remove`, `activeTargets`), so A needs a change to the shared caption registry,
which BR-U8.1-01 keeps unchanged; and A rewrites the shipped `CaptionOverlayTarget`, which
BR-U8.1-01 limits to import changes. Each `PopOutCaptionTarget` copies the shipped read from
`caption_overlay_target.dart:94-102`.

**Note 6 (L5 Other).** One name per contract, defined in `zip_core` and implemented identically by
every runner: `zip_core/overlay_window_configure` (sub-engine) and
`zip_core/overlay_sub_window_events` (main engine, method `subWindowClosed`). The Dart end lives in
`zip_core` and is shared by both apps; the apps never share a messenger, so per-app names add
plumbing and prevent no collision. This follows the `<package>/<channel>` convention. Option A's
validation rules are adopted unchanged.

---

## Review round 2 (2026-10-21) — one item changed

**`dispose()` re-specified: it is unchanged.** The first draft of the NFR Design artifacts said the
controller's `dispose()` must stop disposing the enumerator (`:702`) and stop nulling the
method-handler slot (`:708`). That is wrong against the moved suite:
`overlay_window_controller_test.dart:721-749` asserts `harness.enumerator.isDisposed` is `true` after
controller dispose (`:736` and `:749`). A `dispose()` that stopped disposing would fail for a reason
outside BR-U8.1-01's five, so the build would stop.

Re-specified as:

- `OverlayWindowHost` hands each controller a **`DisplayEnumeratorLease`** — a reference-counted
  wrapper over the one `ScreenRetrieverDisplayEnumerator`. Its `displays`/`changes`/`primarySize`
  delegate to the shared instance; its `dispose()` releases that controller's share; the real
  enumerator is disposed by the **last release** or by `host.dispose()`, whichever comes first;
  idempotent.
- `:708`'s `call(null)` already routes through `router.installerFor(token)`, which maps `null` to
  `unregister`. No code change at the call site.
- The "consequence that is not a deviation" paragraph is deleted. `dispose()` is stated to be
  byte-for-byte unchanged, with the moved `dispose` tests passing verbatim.
- Lease unit tests added: the last release disposes; an earlier release does not; a double release is
  a no-op; `host.dispose()` disposes regardless.

Applied to `nfr-design/logical-components.md` (§2, §3, §7), `nfr-design/nfr-design-patterns.md`
(§1.5, §4.2) and `nfr-design/handoff-summary.md`. No answer above changed; this is a correction to
how one answer is realised, found by the owner against the moved test.

