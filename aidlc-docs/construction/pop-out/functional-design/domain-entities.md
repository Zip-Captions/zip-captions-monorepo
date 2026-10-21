# Domain Entities — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: Draft for approval.
**Sources**: `pip-ux-parity.md` §8 (binding), S-21, `phase2-unit-of-work.md` Unit 8.1, the
`window_manager` SECURITY-10 record, the shipped Unit 8 code, and the twelve answers to the
Functional Design questions (`plans/pop-out-functional-design-plan.md`) plus the one
clarification (`plans/pop-out-functional-design-clarification-questions.md`, Q9 amendment).

**Answers carried**: Q1 A (`PopOutMode`), Q2 A (`zip_core/src/output/overlay/` barrel, existing
fence shape), Q3 A (config types move to `zip_core`, `zip_broadcast` re-exports), Q4 A
(`AlwaysOnTopInstaller` in the sub-engine), Q5 A (`PopOutCaptionTarget` per app, controller guard
is the idempotence), Q6 A (optional controls parameter on `CaptionDisplayWidget`), Q7 A (shell
header action + in-surface + inline banner), Q8 A (three active states; empty registry disables),
Q9 **amended** (75% width, two rendered lines tall, bottom-anchored), Q10 B (no persistence),
Q11 A (§8.8 split), Q12 A (delete and rewrite imports).

---

## 1. Type inventory: promoted, moved-adjacent, new

Three groups. "Promoted" means the file moves from `zip_broadcast/lib/src/output/overlay/` to
`zip_core/lib/src/output/overlay/` and the `zip_broadcast` file is deleted (Q12 A).

### 1.1 Promoted unchanged (no behaviour change, path change only)

| Type | Today | After | Notes |
|---|---|---|---|
| `OverlayWindowController` | `zip_broadcast` | `zip_core` | The state machine below, verbatim. `log` is already an injected `Logger`. |
| `OverlayWindowMode` (sealed), `ExternalDisplayMode` | `zip_broadcast` | `zip_core` | Gains a sibling (1.3). |
| `CaptionOverlaySnapshot` | `zip_broadcast` | `zip_core` | Hand-written equality kept. Gains a field (1.3). |
| `OverlayActivity` enum | `zip_broadcast` | `zip_core` | unchanged |
| `OverlayEvent` (sealed): `DisplayLost`, `WindowClosed`, `OpenFailed` | `zip_broadcast` | `zip_core` | unchanged |
| `ExternalDisplayStatus` (sealed): `Unsupported`, `NoDisplays`, `Off`, `Opening`, `Open`, `WaitingForDisplay`, `Failed` | `zip_broadcast` | `zip_core` | The name **stays** `ExternalDisplayStatus`. Renaming it would force every Unit 8 status switch in the controls, the shell and six test files to change for no behavioural gain; one controller serves both modes, so one status family is correct (the modes differ by `OverlayWindowMode`, not by status). |
| `CaptionOverlayCodec`, `OverlayWindowLaunch`, the four top-level codec functions | `zip_broadcast` | `zip_core` | Gains the second mode (1.3). The forward-looking "the key is the Phase 8 translation key" note stays accurate. |
| `CloseReason` enum | `zip_broadcast` | `zip_core` | unchanged; the pop-out adds no member (see 1.3's close mapping) |
| `resolveOpenDisplay`, `OpenDisplayResolution` | `zip_broadcast` | `zip_core` | unchanged; the pop-out does not use it (Deviation D-1 in `business-logic-model.md`). |
| `overlayReadyTimeout`, `captionUpdateInterval` | `zip_broadcast` | `zip_core` | unchanged values |
| `DesktopWindowService` interface | `zip_broadcast` | `zip_core` | One additive method (1.2). |
| `DesktopMultiWindowService` (io + stub) | `zip_broadcast` | `zip_core` | io file gains one new installer (1.2) |
| `OverlayMethodHandler`, `OverlayMethodHandlerInstaller`, `overlayMethodHandlerInstaller` | `zip_broadcast` | `zip_core` | unchanged |
| `OverlayWindowBridge`, `DesktopMultiWindowBridge`, `NoopOverlayWindowBridge` | `zip_broadcast` | `zip_core` | unchanged |
| `isOverlayWindowLaunch`, `overlayWindowMain`, `OverlayWindowEntry` | `zip_broadcast` | `zip_core` | `overlayWindowMain` gains one optional parameter (1.2) |
| `DisplayEnumerator` interface, `DisplayInfo`, `ScreenRetrieverDisplayEnumerator` (io + stub + export) | `zip_broadcast` | `zip_core` | unchanged — `zip_core` gains `screen_retriever` (1.4) |
| `CaptionOverlayTarget` | `zip_broadcast` | `zip_broadcast` (stays) | App-level bus adapter; its imports change. Per Q5 A it is not promoted; `zip_captions` gets its own sibling (2.2). |
| `CaptionPosition` enum | `zip_broadcast` | `zip_broadcast` (stays) | An external-display-only concept (`top`/`bottom` of a display surface). The pop-out is bottom-anchored by position, not by this setting, and §8.9 puts pop-out arrangement out of scope. |

### 1.2 Promoted with an additive change

| Type | Additive change | Why (source) |
|---|---|---|
| `DesktopWindowService` | `Future<void> setBounds(int windowId, Rect frame, {bool center = false})` and `Future<void> setAlwaysOnTop(int windowId, bool value)` | Q9 amended: the pop-out opens at a computed size and placement, and needs the always-on-top call. `setFrame` stays the external display's work-area path, unchanged (`toPlatformFrame` and its tests untouched). |
| `DesktopMultiWindowService` (io) | implements the two new methods: `setBounds` → `setFrame(toPlatformFrame(...))` (same conversion; no new coordinate logic) or, when `center`, `WindowController.fromWindowId(id).setBounds`-plus-centre; `setAlwaysOnTop` → **throws** `UnsupportedError` (the plugin has no such call — the real call goes through 1.2.1) | SECURITY-10 §1: `desktop_multi_window` cannot do always-on-top. Keeping the throw makes any accidental use loud in tests. |
| `DesktopMultiWindowService` (stub) | both throw `UnsupportedError`, as its other methods do | Consistent with the shipped stub. |
| `overlayWindowMain` | new optional `AlwaysOnTopInstaller? alwaysOnTop` defaulting to the platform installer | Q4 A: the sub-engine must run the call itself. |
| `OverlayWindowEntry` | new optional `AlwaysOnTopInstaller? alwaysOnTop` and `PopOutWindowHost? popOutHost`; when the launch's mode is `PopOutMode` it awaits `alwaysOnTop?.install()` before sending `overlayReady`, and builds `PopOutWindowBody` instead of `OverlayWindowBody` | Q4 A + Q6 A/Q9 amended: the pop-out window's own surface (with the in-surface toggle) and its raise-to-top happen inside the engine that owns it. |

#### 1.2.1 `AlwaysOnTopInstaller` (new, the `window_manager` fence)

```
typedef AlwaysOnTopInstaller = Future<void> Function();
```

- Declared in `zip_core/lib/src/output/overlay/always_on_top_installer.dart`.
- Production const `alwaysOnTopInstaller` lives in
  `zip_core/lib/src/output/overlay/always_on_top_installer_io.dart`, exported through a new
  conditional export `always_on_top_installer.dart` → `..._stub.dart` /
  `if (dart.library.io) ..._io.dart` (the same shape as `desktop_multi_window_service.dart`).
- The io file is the **only** file in either app or `zip_core` that imports `window_manager`
  (SECURITY-10 §5's import fence, restated).
- Its body: `await windowManager.ensureInitialized(); await windowManager.setAlwaysOnTop(true);`
  followed by `setResizable(true)` and `setMinimumSize(...)` using the pop-out constants. Each
  step caught; a failure logs a fixed string and does not throw (the window still opens, just not
  on top; Unit 9's item 15 check is what proves the happy path on each platform).
- The stub's const is a no-op `Future<void> Function()`.

### 1.3 New types

| Type | Kind | Shape and constraints |
|---|---|---|
| `PopOutMode` | `final class`, sibling of `ExternalDisplayMode`, in `overlay_window_mode.dart` | No fields. `const PopOutMode();` Carries only "this window floats above other apps and mirrors the caption surface". No `displayId`: §8.7 keeps `OverlayConfig.targetDisplayId` meaningful for both modes, but the pop-out's placement is derived (Q9 amended), not a persisted selection (Q10 B). |
| `CaptionOverlaySnapshot.contentMode` | new field on the promoted snapshot | `PopOutContentMode` (`originalOnly` / `translatedOnly` / `originalAndTranslated`), defaulting to `originalOnly`. Encoded as `contentMode` in the codec's `settings`-adjacent block (not inside `settings`, which is `DisplaySettings`). Travels only; §8.8 items 8-10 are **deferred to Phase 8**, so neither app offers the setting yet and the window renders `originalOnly` regardless. Existing the field means Phase 8 adds the picker, not the wire field. |
| `PopOutContentMode` | `enum` | The three §8.3 UX-PIP-06 labels. |
| `PopOutGeometry` | `const` holder of the numbers in `zip_core/lib/src/output/overlay/pop_out_geometry.dart` | `widthFraction = 0.75`, `visibleLines = 2`, `minWidth = 320`, `minHeight = 96`, `bottomMargin = 0`, `captionVerticalPadding = 8`, `captionLineSpacing = 4`, plus `Size popOutSize(DisplaySettings, TextTheme, {double textScaler})` computing height = 2 line-height + padding + toggle row height. Pure function, no plugin, PBT-able (see "Testable properties"). |
| `PopOutWindowBody` | `StatelessWidget` in `zip_core/lib/src/widgets/pop_out_window_body.dart` | The pop-out window's content: opaque themed surface, `CaptionDisplayWidget` with `controls: <in-surface toggle>`, bottom-anchored. Shares `_themeModeOf` by moving it to a small internal helper so both window bodies use one function. |
| `PopOutCaptionTarget` | `CaptionOutputTarget` implementation, one per app | Sibling of `CaptionOverlayTarget` (2.2). |
| `PopOutControls`, `PopOutBanner` | widgets, one per app | The chrome toggle and the hint (2.1). |
| `popOutEnabled` (app state) | in-memory boolean | Q10 B: no persisted key. In `zip_broadcast` it lives beside `OutputTargetSettings` in the shell's own state (not in the persisted settings model, because that model is persisted field-by-field in `broadcast_providers.dart` and a persisted-looking field would invite a future accidental write). In `zip_captions` it lives in a new app-level notifier. |

### 1.4 New dependencies (per app and `zip_core`)

| Package | Where | Version | Justification |
|---|---|---|---|
| `desktop_multi_window` | `zip_core`, `zip_captions` (already in `zip_broadcast`) | `^0.2.0` (the shipped pin) | The machinery in `zip_core` needs it behind the fence; `zip_captions` gains its first windowing. |
| `window_manager` | `zip_core` only | `^0.5.1` | Approved 2026-10-20, record `pop-out/functional-design/window-manager-security-10.md`, tech-spec §6 row already present. `^0.5.1` resolves to the current 0.5.2; its own `screen_retriever: ^0.2.2` dependency is the pin `zip_broadcast` already uses, so no other lockfile movement is expected. |
| `screen_retriever` | `zip_core` (already in `zip_broadcast`) | `^0.2.2` | The promoted display enumerator needs it. `zip_broadcast` keeps its own declaration or drops it — a decision for Infrastructure Design, since nothing in `zip_broadcast` will import it after the move. |

**The apps do not declare `window_manager`.** Its only Dart call site is in `zip_core`, behind the
io fence; a per-app declaration would be an unused dependency (SECURITY-10 "no unused
dependencies"). The native plugin still reaches each app's desktop build because `zip_core` is a
path dependency the app resolves through. Infrastructure Design verifies this per platform
(`generated_plugin_registrant`, `generated_plugins.cmake`, `Podfile.lock`).

---

## 2. Per-app entities

### 2.1 Zip Broadcast

| Component | Kind | Constraint |
|---|---|---|
| `ZbAppShell` | modified | Gains `_popOutTarget`, `_popOutRegistered`, the in-memory `_popOutEnabled`, `_onPopOutEvent`, `_syncPopOut` (mirrors `_syncOverlay`) and `_togglePopOut`. The existing `_syncOverlay`/`_onOverlayEvent` path is untouched. |
| `PopOutControls` (chrome toggle) | new widget | UX-PIP-01. Reads the status provider and the availability rule (3.1); writes the shell's toggle. Labels from ARB: `popOutEnter` / `popOutExit`. |
| `PopOutBanner` (hint + return) | new widget | UX-PIP-05. Shown in the main window while popped out; `Return to Window` calls the same toggle. |
| In-surface toggle | new widget | UX-PIP-02, passed into `CaptionDisplayWidget(controls: ...)` on both the main window's caption surface and the pop-out's (`PopOutWindowBody`). |
| `PopOutCaptionTarget` | new class | Same shape as `CaptionOverlayTarget`, mode `PopOutMode`, `CloseReason.toggleOff` on hide. |
| `overlay_window_controller_provider.dart` | modified | One controller, one enumerator (unchanged shape); `Logger('zip_broadcast...')` becomes `Logger('zip_core...')` because the class moved. |
| `main.dart` | modified | `overlayWindowMain(args)` now also carries the pop-out path (no new branch: `isOverlayWindowLaunch` already covers it); the `alwaysOnTop` default comes from `zip_core`. |
| `desktop_multi_window_service_io.dart`, `display_info.freezed.dart`, 22 other files | **deleted** | Q12 A. |

### 2.2 Zip Captions

| Component | Kind | Constraint |
|---|---|---|
| `ZcAppShell` | modified | Same toggle wiring as `ZbAppShell`'s new parts, but on a **stateless** shell today — becomes a `ConsumerStatefulWidget` to own the one target and the in-memory flag, matching `ZbAppShell`'s precedent. |
| `PopOutCaptionTarget` (`zip_captions` copy) | new class | Q5 A allows one thin adapter per app, because the bus/registry imports differ and `zip_broadcast`'s adapter is not importable. Its body is ~60 lines and has no logic beyond `_pushSnapshot`/`_activityFor`; the duplication is the app-local adapter, not the machinery. |
| `RecordingScreen` | modified | Passes `controls:` into its `CaptionDisplayWidget`. |
| `main(List<String> args)` | modified | `zip_captions`'s `main()` becomes `main(List<String> args)` and routes `isOverlayWindowLaunch(args)` before `GoogleFonts`/logging/Supabase/`ProviderContainer`, exactly as `zip_broadcast` does. |
| `ZcStrings` + `l10n/arb/app_en.arb` | modified | Pop-out keys (3.2). `ZcStrings` is the app's only ARB reader (Unit 7's decision), so the shell reads through it. |
| `pubspec.yaml` | modified | `desktop_multi_window: ^0.2.0` added. |
| Three runners | modified | Window-created callback + plugin registration (Infrastructure Design). |

---

## 3. Presentation contracts

### 3.1 Availability (UX-PIP-03/04, BR-PIP-12/13, Q8 A)

| `ExternalDisplayStatus` | Session state | Engine | Control |
|---|---|---|---|
| `Unsupported` | any | any | **Not shown** (UX-PIP-04, BR-PIP-11/12) |
| `NoDisplays`, `Off`, `Opening`, `Open`, `WaitingForDisplay`, `Failed` | `IdleState` or `StoppedState` | available | shown, **disabled**, reason "Start captioning to pop captions out" |
| any of the above | `IdleState`/`StoppedState` | **none registered** | shown, **disabled**, reason "No speech recognition engine is available on this device" |
| any of the above | `RecordingActiveState`/`PausedState`/`ReconnectingState` | available | shown, **enabled** |
| any of the above | `RecordingActiveState`/`PausedState`/`ReconnectingState` | none registered | shown, **disabled**, engine reason |

The engine check reads `sttEngineRegistryProvider.listAvailable().isEmpty`. In `zip_captions`
`main.dart` registers `FakeSttEngine` in debug builds only, so this gate is genuinely reachable in
release; in `zip_broadcast` the engine is registered by the STT factory provider.

**Precedence**: `Unsupported` wins over everything (nothing renders). Engine-unavailable wins over
session-inactive when both apply, because the engine is the cause the user can act on and
BR-PIP-13 asks for the reason. Both reasons are always rendered as visible text next to the
disabled control, never as a tooltip alone (screen readers, §8.9's out-of-scope list does not
cover this).

The toggle's **enabled/disabled** and the toggle's **label** are independent: a disabled toggle
still reads "Picture in Picture" and its icon still reflects `Off`, so a user can see the feature
exists (BR-PIP-12's table).

### 3.2 Copy (ARB keys, per app)

| Key | Value | Source |
|---|---|---|
| `popOutEnter` | `Picture in Picture` | UX-PIP-01 (V1 `LABELS.documentPip`) |
| `popOutExit` | `Exit Picture in Picture` | UX-PIP-01 |
| `popOutHint` | `Captions are displaying in Picture-in-Picture` | UX-PIP-05 |
| `popOutReturn` | `Return to Window` | UX-PIP-05 |
| `popOutUnavailableNoSession` | `Start captioning to pop captions out` | BR-PIP-12, Q8 A |
| `popOutUnavailableNoEngine` | `No speech recognition engine is available on this device` | BR-PIP-13, Q8 A |
| `popOutOpenFailed` | `The pop-out window could not be opened` | Unit 8's `Failed` analogue; the raw code is never shown |

`zip_broadcast` adds these to `l10n/arb/app_en.arb`; `zip_captions` adds them to its own ARB and
`ZcStrings` getters. No key is shared across packages (different localisation mechanisms, Unit 7's
Backlog note).

### 3.3 Pop-out geometry (Q9, amended)

`popOutSize(...)`:

```
width  = clamp(0.75 * display.workArea.width, minWidth, display.workArea.width)
height = toggleRowHeight
       + visibleLines * (resolvedLineHeight(textScaler)) + (visibleLines - 1) * lineSpacing
       + 2 * captionVerticalPadding
       + topAndBottomSafeInset
```

- Line height comes from `DisplaySettings.captionTextSize.resolve(textTheme)`'s `fontSize` and
  `height` (default 1.2 when `height` is null), multiplied by the window's `MediaQuery`
  text scaler, so an accessibility text scale still fits two lines.
- Placement: bottom-anchored inside the display containing the main window's centre, horizontally
  centred. Horizontal position is the display work area's centre minus half the width.
- Minimum size `minWidth x minHeight`. Resizable (never `setResizable(false)`), decorated
  normally.
- The window is **framed once at open**. It is not reframed on display change (a pop-out follows
  the user's monitor only if reopened) and not on settings change.

`Resolution of "the display containing the main window's centre"` reuses the promoted enumerator
(`displayListProvider` / the controller's `displays`), and falls back to the primary, then the
first display, then a null display meaning "let the platform place it".

### 3.4 Content setting (deferred)

`PopOutContentMode` is on the wire and defaults to `originalOnly`. Neither app renders a picker in
this unit; §8.8 items 8-10 are recorded deferred to Phase 8 with that reason. With translation
off (always, in Phase 2), BR-PIP-06's "shows original captions regardless of the stored content
setting" is satisfied by construction.

---

## 4. State and lifecycle (summary; full model in `business-logic-model.md`)

| Concern | Owner |
|---|---|
| Pop-out window existence, ready handshake, close paths, update coalescing | `OverlayWindowController` (promoted, unchanged) |
| Always-on-top, resizable, minimum size of the pop-out window | `AlwaysOnTopInstaller` in the pop-out **sub-engine** |
| Toggle idempotence and "open in progress" | the controller's `Opening`/`Open` guard; no UI flag (Q5 A) |
| Popped-out flag, target registration, hint visibility | each app's shell (in-memory, Q10 B) |
| Caption text / interim / activity | `PopOutCaptionTarget` reading the on-screen buffer, exactly as `CaptionOverlayTarget` does |
| Recognition continuity | nothing changes: the pop-out is a second `CaptionOutputTarget`; the recognition session is untouched (BR-PIP-04) |

---

## 5. Testable properties (PBT-01)

| # | Component | Category | Property |
|---|---|---|---|
| POP-1 | `CaptionOverlayCodec.encodeLaunch`/`decodeLaunch` | Round-trip | For every generated `OverlayWindowLaunch` (both modes), `decode(encode(x))` equals `x` under the snapshot's structural equality. |
| POP-2 | `CaptionOverlayCodec.decodeLaunch`/`decodeSnapshot` | Invariant (total on error) | For generated malformed/oversized/unknown-version/unknown-mode payloads, decode returns `null` and never throws. |
| POP-3 | `CaptionOverlayCodec.encodeSnapshot` | Invariant (size bound) | For any generated snapshot, the encoded UTF-8 length is `<= maxEncodedBytes`, and decoding it yields a snapshot that is a suffix-preserving subsequence of the input's entries. |
| POP-4 | `PopOutGeometry.popOutSize` | Invariant | Width is always within `[minWidth, workArea.width]` (given `workArea.width >= minWidth`); height is always `>= minHeight`; width is monotone non-decreasing in work area width; height is monotone non-decreasing in text scale. |
| POP-5 | `OverlayWindowController` (both modes) | Stateful (PBT-06) | The Unit 8 FP-5 `_World` harness, unchanged, re-run after the move in `zip_core`; plus pop-out commands (`openPopOut`, `toggleAgain`, `toggleOff`, `windowGone`) proving at most one window, one state, and no second `createWindow` during `Opening`/`Open`. |
| POP-6 | `OverlayWindowMode` codec mapping | Round-trip | For each mode variant, the mode's wire token decodes back to the same variant type, and a payload with the other variant's token decodes to the other type (no cross-talk). |
| POP-7 | Availability rule (§3.1) | Invariant (exhaustive, example-based matrix is the primary) | For every `(status, sessionState, enginePresent)` triple, the control's visibility is `status is! Unsupported`, and enabled iff session active and engine present. Not property-genned (finite 7x5x2 domain) — an explicit table test is the stronger artefact; PBT-03's spirit is met by exhaustiveness. |
| POP-8 | `toPlatformFrame` | Invariant | Unchanged from Unit 8 and moved as-is: y-flip/scale/identity per platform remain inverses where they must, and identity on Linux. |

`resolveOpenDisplay`'s FP-4 property and the codec's UP-1..UP-3 properties move unchanged; they
are not re-derived.

No PBT properties are identified for `PopOutControls`, `PopOutBanner`, `PopOutWindowBody` or
`AlwaysOnTopInstaller` — they are presentation or single-call platform seams, covered by widget
tests and a fake installer.