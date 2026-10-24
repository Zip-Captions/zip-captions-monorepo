# Domain Entities — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (revised after the pre-build review: RQ-1 A / RQ-2 A / RQ-3 A-amended; revision 2 same day).
**Sources**: `pip-ux-parity.md` §8 (binding), S-21, `phase2-unit-of-work.md` Unit 8.1, the
`window_manager` SECURITY-10 record, the shipped Unit 8 code, and the twelve answers to the
Functional Design questions (`plans/pop-out-functional-design-plan.md`) plus the one
clarification (`plans/pop-out-functional-design-clarification-questions.md`, Q9 amendment).

**Answers carried**: Q1 A (`PopOutMode`), Q2 A (`zip_core/src/output/overlay/` barrel, existing
fence shape), Q3 A (config types move to `zip_core`, `zip_broadcast` re-exports), Q4 A
(`WindowConfigurator` in the sub-engine), Q5 A (`PopOutCaptionTarget` per app, controller guard
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
| `DesktopWindowService` | **no change** | R-m1 resolved 2026-10-21: `setBounds(…, {bool center})` and a throwing `setAlwaysOnTop` are dropped as dead surface. `setBounds` duplicated `setFrame`, `center` contradicted Q9's bottom-anchoring (the plugin maps it to `NSWindow.center()`), and the real always-on-top call is not this interface's job. `setFrame` serves both modes; `toPlatformFrame` and its tests are untouched. |
| `overlayWindowMain` | new optional `WindowConfigurator? windowConfigurator` defaulting to the platform configurator | RQ-1 A: the sub-engine applies its own window configuration before ready (BLM §3.2 step 6). |
| `OverlayWindowEntry` | new optional `PopOutWindowHost? popOutHost`; when the launch's mode is `PopOutMode` it builds `PopOutWindowBody` instead of `OverlayWindowBody` | Q6 A/Q9 amended. **R-M9 resolved**: it does **not** run the configuration step — that is `overlayWindowMain`'s (BLM §3.2), stated once. |

#### 1.2.1 `WindowConfigurator` (new, replaces the `window_manager` installer)

```
class WindowConfigurator {
  Future<void> configure(int windowId, OverlayWindowConfig config);
}

class OverlayWindowConfig {
  final bool floating;    // always-on-top
  final bool decorated;   // title bar, close button, resize handles
  final double minWidth;  // content size
  final double minHeight;
}
```

- Declared in `zip_core/lib/src/output/overlay/window_configurator.dart`; the production
  implementation in `..._io.dart` uses a `MethodChannel` and is exported through the same
  conditional-export shape as `desktop_multi_window_service.dart`; `..._stub.dart` is a no-op.
- The channel name and method are fixed (`BLM §3.2`): `configure({windowId, floating, decorated,
  minWidth, minHeight})`. Both apps' runners implement it; Infrastructure Design owns the exact
  channel name and the per-platform bodies.
- **No `window_manager` import anywhere.** RQ-1 A (owner, 2026-10-21) removed the dependency: its
  macOS `ensureInitialized` replaces `desktop_multi_window`'s window delegate, which is the only
  path by which an OS close shuts the sub-engine down (R-B2). An additive native hook has no such
  cost.
- Each step caught; a failure logs a fixed string and does not throw (the window still opens, just
  not floating; Unit 9's item 15 check is what proves the happy path on each platform).
- The stub's instance is a no-op `Future<void>`-returning implementation.

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
| `desktop_multi_window` | `zip_core`, `zip_captions` (already in `zip_broadcast`) | `^0.2.1` (the shipped pin; corrected at Infrastructure Design from `^0.2.0`) | The machinery in `zip_core` needs it behind the fence; `zip_captions` gains its first windowing. |
| `screen_retriever` | `zip_core` (already in `zip_broadcast`) | `^0.2.2` | The promoted display enumerator needs it. `zip_broadcast` **removes** its own declaration (RQ-2 A, NFR-R Q2 A), because nothing in the app imports it after the move. |

**`window_manager` is no longer a dependency of anything** (RQ-1 A, owner 2026-10-21). The row above
was withdrawn with the dependency; `window-manager-security-10.md` is retired (kept in place as a
closed record of the 2026-10-20 decision and its reversal), nothing imports it, and **no line is
added to any `pubspec.yaml` and no row is added to `docs/04-technical-specification.md` §6**.

**R-M10 resolved.** The NFR-R lockfile fence listed `window_manager_macos` entries that do not
exist: 0.5.1 is a single package, not federated (`pubspec.yaml:31-32` → `path: ^1.8.2`,
`screen_retriever: ^0.2.0`; one `macos/window_manager.podspec`). With the dependency removed the
fence is now only `screen_retriever`'s position:

| File | Expected movement |
|---|---|
| `pubspec.lock` (workspace) | none |
| `packages/zip_broadcast/macos/Podfile.lock` | `screen_retriever_macos` **stays** — the plugin still reaches the app through `zip_core`; the earlier "−" row was wrong |
| `packages/zip_captions/macos/Podfile.lock` | gains `desktop_multi_window` and `screen_retriever_macos` |

Any other movement is reported, not committed silently.

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
| `main(List<String> args)` | modified | `zip_captions`'s `main()` becomes `main(List<String> args)` and delegates to `runZipCaptions(args, {runApp, isWeb})` in `lib/src/bootstrap.dart` (Infrastructure Design ID-1, the authoritative seam: `nfr-requirements.md:28`), which routes `isOverlayWindowLaunch(args)` before `GoogleFonts`/logging/Supabase/`ProviderContainer`. `zip_broadcast` keeps its inline branch. |
| `ZcStrings` + `l10n/arb/app_en.arb` | modified | Pop-out keys (3.2). `ZcStrings` is the app's only ARB reader (Unit 7's decision), so the shell reads through it. |
| `pubspec.yaml` | modified | `desktop_multi_window: ^0.2.1` added. |
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

**R-M1 resolved (RQ-2 A, owner 2026-10-21): the engine check is each app's own existing gate, not
the registry.** `sttEngineRegistryProvider` was wrong for Zip Broadcast: nothing in
`packages/zip_broadcast/lib` ever registers into it, because the app builds engines per audio source
through `sttEngineFactoryProvider` (`stt_engine_factory_provider.dart:20-27`). The registry is
therefore permanently empty there, and the gate would have disabled the pop-out with
"No speech recognition engine" on every machine. `SttEngineRegistry` is also a plain class
(`stt_engine_registry.dart:8-42`) with no stream or listenable, so watching it could not rebuild
when `sherpa_model_catalog_provider.dart:106` unregisters at runtime.

`popOutAvailability` therefore takes one boolean, `engineAvailable`, supplied by a per-app watchable
provider — "whatever already gates that app's Start Captioning control":

| App | Provider | Rule |
|---|---|---|
| `zip_broadcast` | new `broadcastEngineAvailableProvider` | true when the app's audio-source/factory path reports at least one usable source; it must rebuild when the source list changes, so it derives from the existing sources provider rather than the registry |
| `zip_captions` | new `captionsEngineAvailableProvider` | `ref.watch(sttEngineProvider) != null` |

`zip_core` keeps `engineAvailable` as a plain parameter and imports neither app. The `zip_captions`
gate stays genuinely reachable in release (its debug-only `FakeSttEngine` registration in
`main.dart:57` is irrelevant now, because that registration feeds `sttEngineProvider`, which the new
provider reads).

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
| Always-on-top, decorated, resizable, minimum size of the pop-out window | `WindowConfigurator` (native `configure` channel) in the pop-out **sub-engine**; close notification raised natively to the **main** engine |
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
`WindowConfigurator` — they are presentation or single-call platform seams, covered by widget
tests and a fake configurator.