# Code Generation Plan — Unit 8: External Display (S-20)

**Prior stages (all COMPLETE 2026-10-20, unattended run, pre-approved per
`.agent/overnight-pipeline.md` A2, subject to morning review)**:

| Stage | Artifact | Loaded at this stage |
|---|---|---|
| Functional Design revision | `../external-display/functional-design/` | handoff summary first; then `business-rules.md`, `business-logic-model.md`, `domain-entities.md`, `frontend-components.md`, `screen-retriever-security-10.md` in full (reason logged in `audit.md` — the handoff does not carry the BR-U8-01..26 text, the T1-T17 table, the FP-1..FP-5 table, the codec wire shape, or the render-by-status matrix, all of which the plan transcribes) |
| NFR Requirements | `../external-display/nfr-requirements/` | handoff summary first; then `nfr-requirements.md` and `tech-stack-decisions.md` in full (Q1-Q9 decisions, Security/PBT compliance, constants and values the plan fixes) |
| NFR Design | `../external-display/nfr-design/` | handoff summary first; then `nfr-design-patterns.md` and `logical-components.md` in full (R1-R6/P1-P5/S1-S3/T1-T3, component seams, FP-5 harness spec) |
| Infrastructure Design revision | `../external-display/infrastructure-design/` | handoff summary first; then `infrastructure-design.md` in full (ID-1..ID-7, runner table, lockfile fence) |

**Binding design input**: the PR #37 review comment (2026-10-19, James Petersen,
<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6281471308>,
decisions D-1..D-13, required changes B-1..B-9) and the A7 follow-up
(<https://github.com/Zip-Captions/zip-captions-monorepo/pull/37#issuecomment-6282213636>).
Every step below cites the artifact (BR-U8-nn, Tn, ID-n, Rn/Pn/Sn, B-n, D-n,
FP-n) it transcribes.

**Story**: S-20 (AC4 as amended by D-5). **Branch**: `feature/external-display`
(PR #37 open against `develop`). **Package**: `zip_broadcast`.

**Run mode**: unattended. This plan is self-approved on write:
`approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-19) —
subject to morning review`. Part 2 executes this plan step by step.

**Supersession.** This file replaces the PROPOSED plan committed 2026-10-19 in
its entirety. Removed by this regeneration: every `window_manager` entry and
its three-file `desktop_window_decorator` trio (D-13), T15
(`desktop_window_decorator_test.dart`), every in-unit pop-out file
(`PopOutMode`, `pop_out_toggle.dart`, `pip_content.dart`, the `popOutToggle`
inbound handler, `overlay_window_launch.dart` with pop-out size fields), the
ping probe / D10 close detection (D-9/B-5), the macOS `didBecomeKey` observer
(A7 item 3), the "divide by `scaleFactor`" Windows claim (B-2), the
"move to primary on disconnect" rule (D-4), and the three answered open
questions section (the review comment closes every question; the FD plan now
holds the `[Answer]:` table). **No step in this plan depends on any of them.**

**Gate status.** This plan is a strict transcription of the revised design with
zero open questions (see "Self-check"). Part 2 proceeds.

---

## 1. Unit context

### 1.1 Story and scope

S-20 (`aidlc-docs/inception/user-stories/phase2-stories.md`), AC4 amended by
D-5 to: *"When the broadcaster disables the output, then the window closes and
its resources are released."* The remaining ACs are unchanged: all connected
displays listed and one selectable; borderless live caption window on the
selected display using the broadcaster's display settings; works signed out;
disconnect falls back gracefully with a notification and no orphaned window;
not offered on web; contrast meets WCAG AAA (7:1).

Package `zip_broadcast` only. `zip_core`, `zip_captions` and `zip_supabase`
are consumed as shipped and must not change (D-8, run configuration unit
exception 1). No `docs/` change. No Supabase, no Docker, no backend.

### 1.2 The one new dependency

`screen_retriever: ^0.2.2` in `packages/zip_broadcast/pubspec.yaml`, with its
SECURITY-10 comment inline above the entry:

```yaml
  # screen_retriever: display enumeration and connect/disconnect events for the
  # external display target (Unit 8, S-20). Its supply-chain justification is
  # the SECURITY-10 record at
  # aidlc-docs/construction/external-display/functional-design/
  # screen-retriever-security-10.md: 16 releases, MIT, federated by leanflutter,
  # read-only display metadata (no network, no telemetry, no permissions), and
  # imported in exactly one file (screen_retriever_display_enumerator_io.dart).
  # Pinned ^0.2.2 because 0.3.0 requires Dart ^3.13.0 / Flutter >=3.47.0
  # (monorepo floor: >=3.10.0 / >=3.38.0).
  screen_retriever: ^0.2.2
```

`desktop_multi_window: ^0.2.0` already ships (Phase 1). `window_manager` is
**not** added (D-13). Any further dependency need is BLOCKED, not a fix (Q7,
A5).

### 1.3 Exact lockfile delta

| Lockfile | Allowed change |
|---|---|
| root `pubspec.lock` | exactly five new resolution entries: `screen_retriever`, `screen_retriever_platform_interface`, `screen_retriever_macos`, `screen_retriever_windows`, `screen_retriever_linux`. No other package may move. |
| `packages/zip_broadcast/macos/Podfile.lock` | only the `screen_retriever` pod entries that `flutter build macos` adds. |

**Anything else that moves in either lockfile is reported in the PR body and
not committed silently** (run configuration A5; ID "Build footprint"). Both
lockfiles are inspected with `git diff --stat` and `git diff` before the
commit in Step 26; a diff outside the five/pod entries is a deviation to
record, not a file to stage.

### 1.4 Assumptions carried from the binding stages (not new questions)

| # | Assumption | Source |
|---|---|---|
| A-1 | `overlayReadyTimeout = const Duration(seconds: 10)` is the FD's "~10 s" read as its own number. | NFR Requirements Q4; NFR Design P3 |
| A-2 | `captionUpdateInterval = const Duration(milliseconds: 16)`; `maxEncodedBytes = 16 * 1024`. | NFR Design P1/P3 |
| A-3 | A caption-position change while the window is open takes effect at the next open — the B-7 wire shape carries no position in the snapshot `settings`; the launch config is the carrier. | NFR Design "Open questions" minimal interpretation |
| A-4 | `isPrimary` is derived per enumeration event: one `getPrimaryDisplay()`, match by id then geometry, else first display in platform order. | NFR Design "Open questions" (`screen_retriever` 0.2.2 `Display` has no `isPrimary`) |
| A-5 | `google_fonts` renders offline through the shipped `assets/google_fonts/` bundle with runtime fetching disabled, so no `path_provider` plugin is required in the sub-engine; the runner callback registers an empty plugin list. Font rendering is a Unit 9 manual check. | ID-1/ID-5 (verified: `google_fonts` 6.3.3 pure Dart; locked `path_provider` federations are Dart-only PDM) |

---

## 2. File list

All paths relative to the repository root. `N` = created, `M` = modified.

### 2.1 `packages/zip_broadcast/lib/src/output/overlay/`

| # | Path | N/M | Content | Source |
|---|---|---|---|---|
| F01 | `display_info.dart` | N | `@freezed abstract class DisplayInfo` — `id` (String, non-empty), `label` (String, may be empty), `bounds` (Rect, logical top-left work area), `scaleFactor` (double), `isPrimary` (bool); `part 'display_info.freezed.dart'` | FD domain-entities "DisplayInfo" |
| F02 | `display_enumerator.dart` | N | `abstract interface class DisplayEnumerator { Future<List<DisplayInfo>> displays(); Stream<List<DisplayInfo>> get changes; Future<Size?> primarySize(); Future<void> dispose(); }` + the event-contract doc comment (broadcast, first emission to late subscribers, coalescing, errors logged not forwarded, close only on `dispose`); `primarySize()` is the additive platform input the io `setFrame` needs (Step 12's note); re-exports `DisplayInfo` | FD domain-entities "DisplayEnumerator"; ID-3 |
| F03 | `screen_retriever_display_enumerator.dart` | N | conditional export: `export 'screen_retriever_display_enumerator_stub.dart' if (dart.library.io) 'screen_retriever_display_enumerator_io.dart';` — **no plugin symbol** | ID-3; SECURITY-10 §5 item 4 |
| F04 | `screen_retriever_display_enumerator_io.dart` | N | `class ScreenRetrieverDisplayEnumerator implements DisplayEnumerator` — **the only file in the package importing `package:screen_retriever/screen_retriever.dart`**; id normalisation (plugin `id` → `name` → `display-<index>`, repeated name suffixed `#2`); `isPrimary` derivation (A-4); `bounds` from `visiblePosition` + `visibleSize`, `scaleFactor` passed through; `changes` = broadcast controller fed by an internal `ScreenListener` that re-reads `getAllDisplays()` and diffs the last emitted list; latest list replayed to late subscribers; platform error → `display enumeration failed` at `warning`, stream stays open; `primarySize()` = `getPrimaryDisplay().size`; idempotent `dispose()` | ID-3; FD event contract; BR-U8-05; SECURITY-10 §5 item 1 |
| F05 | `screen_retriever_display_enumerator_stub.dart` | N | `class ScreenRetrieverDisplayEnumerator implements DisplayEnumerator` returning `const []`, a never-emitting `const Stream.empty()`, and `primarySize() => null`; idempotent `dispose()`; **no plugin import** | ID-3; BR-U8-11 |
| F06 | `desktop_window_service.dart` | M (additive) | adds `Future<void> setFrame(int windowId, Rect frame)` (frame in logical top-left; the io implementation converts) and `Future<void> show(int windowId)`; the four shipped methods untouched; doc comment cites B-6 and the fixed order `createWindow` → `setFrame` → `show` | FD domain-entities "DesktopWindowService"; B-6 |
| F07 | `desktop_multi_window_service_io.dart` | M | implements `setFrame`/`show`; hosts the pure `toPlatformFrame(Rect frame, TargetPlatform target, {double? primaryFullHeight, double? displayScaleFactor}) → Rect` (P5: Linux identity; Windows multiply every edge by the target display's own scale, 0/missing → 1; macOS `y = primaryFullHeight - top - height`, `x = left`); `setFrame(int id, Rect frame)` converts `frame` with `toPlatformFrame(frame, currentPlatform, primaryFullHeight: <from enumerator.primarySize()>, displayScaleFactor: <from the target DisplayInfo>)`, both read from the injected `DisplayEnumerator` (the `@visibleForTesting` constructor defaults it to `ScreenRetrieverDisplayEnumerator()`; the service never imports the plugin, F03's conditional export supplies it), so the pure function stays argument-driven (Step 12's note); hosts the top-level `const OverlayMethodHandlerInstaller overlayMethodHandlerInstaller` wrapping `DesktopMultiWindow.setMethodHandler` with the `MethodCall` → `(call.method, fromWindowId)` adapter (`null` uninstalls) | ID-5 B-1/B-2; NFR Design P5/Q7; B-6 |
| F08 | `desktop_multi_window_service_stub.dart` | M | `setFrame`/`show` throw `UnsupportedError` like the shipped four (unreachable: callers gate on `isSupported`); top-level `const OverlayMethodHandlerInstaller overlayMethodHandlerInstaller = _noopInstaller` (no-op) | B-6; BR-U8-11; NFR Design Q7 |
| F09 | `overlay_window_mode.dart` | N | `sealed class OverlayWindowMode` + `final class ExternalDisplayMode extends OverlayWindowMode { const ExternalDisplayMode({this.displayId}); final String? displayId; }` (single variant ships; hierarchy kept for the pop-out unit, D-1) | FD domain-entities "OverlayWindowMode" |
| F10 | `overlay_activity.dart` | N | `enum OverlayActivity { standby, live, paused }` | FD domain-entities "OverlayActivity" |
| F11 | `caption_position.dart` | N | `enum CaptionPosition { top, bottom }` | FD domain-entities "CaptionPosition"; B-8 |
| F12 | `overlay_event.dart` | N | `sealed class OverlayEvent` + `DisplayLost({required String displayId})`, `WindowClosed()`, `OpenFailed(String reason)` with `reason` documented as a fixed code | FD domain-entities "OverlayEvent" |
| F13 | `external_display_status.dart` | N | `sealed class ExternalDisplayStatus` + `Unsupported`, `NoDisplays`, `Off`, `Opening`, `Open({required OverlayActivity activity, required String? displayId})`, `WaitingForDisplay({required String displayId})`, `Failed({required String reason})` | FD domain-entities "ExternalDisplayStatus"; T1-T17 |
| F14 | `caption_overlay_snapshot.dart` | N | plain `class CaptionOverlaySnapshot { const CaptionOverlaySnapshot({required this.activity, required this.entries, this.interim, required this.settings}); ... }` with hand-written `==`/`hashCode` over `activity`, `entries`, `interim` and the `settings` fields (needed by FP-1's round-trip equality) | FD domain-entities "CaptionOverlaySnapshot"; D-8 |
| F15 | `caption_overlay_codec.dart` | N | hand-written versioned codecs: `String encodeSnapshot(CaptionOverlaySnapshot)`, `CaptionOverlaySnapshot? decodeSnapshot(String)`, `String encodeLaunch(OverlayWindowLaunch)`, `OverlayWindowLaunch? decodeLaunch(String)`; `static const int maxEncodedBytes = 16 * 1024`; wire shape exactly `{v:1, activity, entries:[{key,text,isFinal}], interim, settings:{scrollDirection,captionTextSize,captionFont,themeModeSetting,maxVisibleLines}}` and `{v:1, config:{mode:'externalDisplay', position:'top'|'bottom'}, snapshot}`; enums by name; `null` on malformed / unknown `v` / unknown enum / over-size (UTF-8 byte length of the full payload); `key` decodes to `entryId` and rebuilds `CaptionDisplayEntry` with fixed placeholder `sessionId`/`sourceId`/`timestamp`; `OverlayWindowLaunch` lives in this file (`{OverlayConfig config, CaptionOverlaySnapshot snapshot}`) with exactly one `mode` source (`config.mode`) | FD "Snapshot and launch codecs"; B-7; BR-U8-24 |
| F16 | `overlay_window_controller.dart` | N | `typedef OverlayMethodHandler = Future<void> Function(String method, int fromWindowId);` `typedef OverlayMethodHandlerInstaller = void Function(OverlayMethodHandler? handler);` `const Duration overlayReadyTimeout = Duration(seconds: 10);` `const Duration captionUpdateInterval = Duration(milliseconds: 16);` `enum CloseReason { toggleOff, cancel, windowClosed, openFailed, displayLost, dispose }`; the pure `({DisplayInfo? target, bool persistedIdPresent}) resolveOpenDisplay(List<DisplayInfo> displays, String? persistedId)`; `class OverlayWindowController` — constructor `({required DesktopWindowService windowService, required DisplayEnumerator enumerator, required OverlayMethodHandlerInstaller? handlerInstaller, required Logger log})`; getters `status`, `statusChanges`, `events`, `isWindowOpen`; methods `open(OverlayConfig)`, `close({required CloseReason reason})`, `reframe()`, `push(CaptionOverlaySnapshot)`, `selectDisplay(String? id)`, `dispose()`; internals `_lifecycleLock` (R2), `_readyTimer` (R3), `_updateTimer` (P1), `_release(Logger)` (R1), `_windowCall(String, Future<void> Function())` (R4), `_setState(next)` (R3), `_handleWindowCall` (the installed handler), the controller-lifetime `changes` subscription (R1) | NFR Design patterns R1-R6/P1-P5; logical-components; B-9; BR-U8-01..05, 07, 09, 15, 17, 21..23 |
| F17 | `caption_overlay_target.dart` | M (rewrite) | thin delegator + caption-bus adapter: constructor `({required OverlayWindowController controller, required CaptionOutputTargetRegistry registry, required DisplaySettings Function() displaySettings})`; `targetId` stays `'caption_overlay'`; `show`/`hide`/`events` delegate; `isVisible => controller.isWindowOpen` (the shipped `_isVisible` field is deleted); `onCaptionEvent` builds the snapshot from `registry.activeTargets.whereType<OnScreenCaptionTarget>().firstOrNull`'s `visibleCaptions` (final portion + trailing interim), the `activity` from the last `SessionStateEvent` (mapping of FD §4), and `displaySettings()`, then `controller.push(...)`; `dispose()` calls `controller.close(reason: CloseReason.dispose)` fire-and-forget; the Phase 1 `{'text','isFinal'}` payload is gone | FD domain-entities "CaptionOverlayTarget"; B-9; BR-U8-12/13/17/25; R1 |
| F18 | `overlay_window_entry.dart` | N | `bool isOverlayWindowLaunch(List<String> args) => args.length >= 3 && args.first == 'multi_window';` `Future<void> overlayWindowMain(List<String> args)` — decode `args[2]` with `decodeLaunch`; on failure `runApp` of the fixed "Window unavailable" frame + log `invalid_window_arguments` + **no `overlayReady`**; on success mirror `GoogleFonts.config.allowRuntimeFetching = false`, `runApp(ProviderScope(overrides: [...], child: OverlayWindowEntry(launch: launch)))`; `OverlayWindowEntry` installs the sub-engine method handler through the `OverlayWindowBridge` seam, **then** sends `overlayReady` to window `0`; `captionUpdate` decodes, `null` → log `overlay caption update dropped`, keep last frame; never throws out of the handler | ID-1/ID-2; BR-U8-19; R5; B-4 |
| F19 | `overlay_window_bridge.dart` / `_io.dart` / `_stub.dart` | N | `abstract interface class OverlayWindowBridge { void listen(void Function(String method, Object? args) onCall); void send(Object? args); }`; conditional export; io impl `DesktopMultiWindowBridge` (the only `DesktopMultiWindow.setMethodHandler` / `invokeMethod(0, 'overlayReady', null)` use on the sub-engine side); stub no-op | ID-2 |

### 2.2 `packages/zip_broadcast/lib/src/`

| # | Path | N/M | Content | Source |
|---|---|---|---|---|
| F20 | `src/widgets/external_display_controls.dart` | N | `ExternalDisplayControls` — the Proto-13 section for all seven statuses, the empty-label "Display N" fallback, the meta line, the per-row toggle, the Caption Position Top/Bottom selector, the waiting banner + Cancel, the fixed-copy failure banner; capability gate first (`Unsupported` renders nothing); all strings ARB-backed | FD `frontend-components.md` §1; BR-U8-07/08/22/26; B-8; ID-7 |
| F21 | `src/widgets/overlay_window_app.dart` | N | `OverlayWindowApp({required OverlayWindowLaunch launch, required ValueListenable<CaptionOverlaySnapshot> snapshot})` — opaque `Scaffold`/`Material` from `AppTheme` `surface`/`onSurface` (BR-U8-20, no literal); standby = background only; live = shipped `CaptionDisplayWidget(entries:, settings:)`; paused = same over the frozen buffer with the `__pause__` row travelling as an entry; caption block at the launch position; follows `settings.themeModeSetting` | FD `frontend-components.md` §2; BR-U8-20/25/26; D-7 |
| F22 | `src/providers/overlay_window_controller_provider.dart` | N | `final overlayWindowControllerProvider = Provider<OverlayWindowController>((ref) { ... ref.onDispose(controller.dispose); return controller; });` wired from `DesktopMultiWindowService()`, `ScreenRetrieverDisplayEnumerator()`, `overlayMethodHandlerInstaller`, `Logger('zip_broadcast.OverlayWindowController')`; `final externalDisplayStatusProvider = StreamProvider<ExternalDisplayStatus>((ref) => ref.watch(overlayWindowControllerProvider).statusChanges);`; `final displayListProvider = StreamProvider<List<DisplayInfo>>((ref) => ref.watch(overlayWindowControllerProvider).enumerator.changes);` (hand-written `Provider`s, not `@Riverpod` — the controller is a plain class, NFR Design Q6) | logical-components "overlay_window_controller_provider" |
| F23 | `src/providers/broadcast_providers.dart` | M | `_externalDisplayIdKey = 'output.externalDisplayId'`, `_externalDisplayCaptionPositionKey = 'output.externalDisplayCaptionPosition'`; `update` persists both; `_loadAsync` reads both and **forces `overlayEnabled: false`** regardless of the stored `output.overlayEnabled` value (BR-U8-21/D-6); `externalDisplayId` is only written from an explicit `selectDisplay`/row-toggle action (BR-U8-07) | FD domain-entities `OutputTargetSettings`; BR-U8-21; ID-7 |
| F24 | `src/models/output_target_settings.dart` | M | + `String? externalDisplayId`, + `@Default(CaptionPosition.bottom) CaptionPosition externalDisplayCaptionPosition`; regenerate freezed | FD domain-entities; B-8 |
| F25 | `src/models/overlay_config.dart` | M | `targetDisplayId` → `@Default(ExternalDisplayMode()) OverlayWindowMode mode`; `position` and `opacity` kept (opacity never applied); regenerate freezed. Recorded Application Design deviation (review §3) | FD domain-entities; D-1; B-8 |
| F26 | `src/shell/zb_app_shell.dart` | M | `_overlayTarget` constructed with `(controller: ref.read(overlayWindowControllerProvider), registry: _registry, displaySettings: () => ref.read(displaySettingsProvider))`; `_syncOverlay(true)` gains `unawaited(_overlayTarget.show(const OverlayConfig()))` **after** `registry.add`; `_syncOverlay(false)` unchanged (remove then `hide()`); a new `events` subscription in `initState`, cancelled in `dispose`: `WindowClosed`/`OpenFailed` → write `overlayEnabled=false` through the notifier (`DisplayLost` → `_overlayRegistered` bookkeeping only, `overlayEnabled` stays true). **No recognition-state listener is added** (D-5 removed it) | logical-components dependency diagram; D-4/D-5; BR-U8-15 |
| F27 | `src/widgets/output_targets_panel.dart` | M | the Phase 1 `settingsCaptionOverlay` `_TargetCard` is replaced by `const ExternalDisplayControls()` (the card structure and the other three cards are untouched) | ID-7; FD §1 |
| F28 | `lib/main.dart` | M | `void main(List<String> args)` + the three-line branch `if (isOverlayWindowLaunch(args)) { await overlayWindowMain(args); return; }` before `GoogleFonts.config...`/`_initLogging`/`Supabase.initialize` | ID-1 |
| F29 | `l10n/arb/app_en.arb` | M | the new keys in §6 (English source) | FD §1 "Copy"; Q9 |

### 2.3 Test files (`packages/zip_broadcast/test/`)

| # | Path | N/M | Content | Source |
|---|---|---|---|---|
| F30 | `helpers/fake_display_enumerator.dart` | N | `class FakeDisplayEnumerator implements DisplayEnumerator` — scriptable `displays()` (value or throw), a broadcast `changes` with `pushDisplays(List<DisplayInfo>)` that **replays the latest list to late subscribers**, idempotent recorded `dispose()` | NFR Design Q9/T1 |
| F31 | `helpers/fake_overlay_method_handler_installer.dart` | N | `class FakeOverlayMethodHandlerInstaller` — records the installed `OverlayMethodHandler` (and the uninstall), exposes `handler` for a trial to invoke with `'overlayReady'` | NFR Design Q9/T1 |
| F32 | `helpers/mock_desktop_window_service.dart` | M | doc comment only: record that `setFrame`/`show` are covered by mocktail's `noSuchMethod` and are stubbed per-test; no class-shape change | NFR Design Q9 (B-6/A7) |
| F33 | `helpers/generators.dart` | M | add `arbitraryDisplayInfo`, `arbitraryDisplayList` (0..n, at most one `isPrimary` at any position, empty labels, ids incl. `display-<n>` and `""`, scale 0/1/1.5/2), `arbitraryCaptionOverlaySnapshot` (any activity, 0..max entries, multibyte text, any settings combination), `arbitraryOverlayWindowLaunch`, `arbitraryMalformedWindowJson` (truncated, wrong type, unknown `v`, unknown enum for activity/settings/position/mode, over-size), `arbitraryLogicalFrame` (+ platform inputs incl. macOS negative-result and Windows mixed-DPI), `arbitraryExternalDisplayCommandSequence` | NFR Design Q9/PBT-07 |
| F34 | `output/overlay/display_enumerator_contract_test.dart` | N | the FD event contract against `FakeDisplayEnumerator`: first emission to a late subscriber; connect; disconnect; same-id changed-bounds emits; identical list does not; platform error logs and keeps the stream open; `dispose()` closes and is idempotent; the id-normalisation order and repeated-name suffix (via a `FakeScreenEventSource` seam exposed by the io adapter's `@visibleForTesting` constructor) | BR-U8-05; FD event contract |
| F35 | `output/overlay/to_platform_frame_test.dart` | N | named examples: macOS primary + secondary below (negative Cocoa `y`); Windows at 1.5x (each edge × 1.5); mixed-DPI (two displays, each with its own factor); macOS non-primary target against the primary's full height; Linux identity; `sf` 0/missing → 1 | B-1/B-2; FP-3; PBT-10 |
| F36 | `output/overlay/to_platform_frame_properties_test.dart` | N | **FP-3** — Glados property over `arbitraryLogicalFrame` | FP-3; PBT-05 |
| F37 | `output/overlay/resolve_open_display_test.dart` | N | BR-U8-07 examples: present id → itself; absent id + primary → primary (`persistedIdPresent: false`); absent id, no primary → first; empty list → `target: null`; empty persisted id → treated as absent; "kept" = no write path (the function has none) | BR-U8-07; FP-4 |
| F38 | `output/overlay/resolve_open_display_properties_test.dart` | N | **FP-4** — property over `arbitraryDisplayList` × persisted-id variants | FP-4 |
| F39 | `output/overlay/caption_overlay_codec_test.dart` | N | named examples: round-trip of a snapshot with interim absent/present and multibyte text; launch round-trip both positions; `null` on truncated / wrong-type / unknown `v` / unknown enum / over-size / second `mode` source; `key` maps to `entryId`; placeholders fixed; `sessionId`/`sourceId` never encoded | B-7; BR-U8-24; PBT-10 |
| F40 | `output/overlay/caption_overlay_codec_properties_test.dart` | N | **FP-1** (round-trip for snapshots and launches) and **FP-2** (total-on-error, never throws) | FP-1; FP-2 |
| F41 | `output/overlay/overlay_window_controller_test.dart` | N | the T1-T17 transition table row by row; the three close paths (toggle off, `'-1'`, failed open); the ready timeout via `fakeAsync`; a pre-ready `'-1'` is ignored; a non-`'-1'` `PlatformException` is logged and ignored; the held snapshot is sent immediately on ready and nothing is sent before; the coalescer sends ≤1 `captionUpdate` per 16 ms; reframe on same-id changed bounds with no re-handshake; `createWindow` throw → `Failed(create_failed)` and `overlayEnabled` false; display-lost → release then `WaitingForDisplay` with `overlayEnabled` true; saved display returns → reopen; Cancel → `Off` with the saved id kept; second open while `Opening` is a no-op; open order `createWindow` → `setFrame` → `show` (verify the mock's call sequence); `isWindowOpen` false whenever the state is not `Open`/`Opening` | BR-U8-01..05/07/09/22/23; T1-T17 |
| F42 | `output/overlay/display_state_machine_properties_test.dart` | N | **FP-5** — the `_World` harness per NFR Design Q9: real controller on the fakes, real `CaptionBus` + real `CaptionOutputTargetRegistry`, one `fakeAsync` per trial, command set `toggleOn`/`toggleOff`/`displaysChanged`/`overlayReady`/`advanceReadyTimeout`/`windowGone`/`otherPlatformError`/`createWindowFails`/`captionEvent`/`elapse`, per-command invariants (declared variants only, one state at a time, closed invariant when the harness flag is false, second concurrent open refused, no `externalDisplayId` write from any open path); **PBT-04** idempotence is also asserted once directly (close twice, toggle-off from `Off`) | FP-5; PBT-04/06 |
| F43 | `output/overlay/external_display_redaction_test.dart` | N | **S2** — capturing `Logger.root.onRecord` into a `List<LogRecord>` + a sentinel caption string in flight; drives launch decode failure, `captionUpdate` decode failure, `createWindow` throw, ready timeout, and a release path with a throwing `closeWindow`; asserts no `message`/`error` contains the sentinel, every `OpenFailed.reason` is in `{create_failed, ready_timeout}`, `DisplayLost.displayId` is the opaque id | BR-U8-18; S1/S2; SECURITY-03 |
| F44 | `output/caption_overlay_target_test.dart` | M | re-point the ten shipped cases at the controller (fake controller or the real one on fakes); new: the snapshot's `entries` equal the buffer's finals, `interim` is the trailing non-final; `activity` follows `SessionStateEvent`; settings change reaches the next snapshot without a reopen; `isVisible` delegates; `events` re-exposes the controller stream; `dispose()` closes fire-and-forget | F17; FD T8; BR-U8-12/17 |
| F45 | `widgets/external_display_controls_test.dart` | N | one test per status (7): `Unsupported` renders nothing, `NoDisplays` copy without a toggle, `Off` rows + "Display N" fallback + meta + the position selector, `Opening` affordance, `Open` active row + pill + live selector, `WaitingForDisplay` banner + "waiting for display" + Cancel, `Failed` fixed copy with no raw reason; row tap writes `externalDisplayId` only (no write from rendering); Caption Position writes `externalDisplayCaptionPosition` and it reaches the next launch config (B-8/T9); Cancel writes `overlayEnabled=false` and keeps the id; no widget key or semantics label contains caption text | FD §1; BR-U8-07/08/15/18; Q2; B-8 |
| F46 | `widgets/overlay_window_app_test.dart` | N | standby (background only, no text), live (shipped `CaptionDisplayWidget` fed by the decoded entries), paused (frozen buffer + `__pause__` row), "Window unavailable" frame, caption position top vs bottom, **BR-U8-20 theme-wiring** (dark → light `themeModeSetting` in a new snapshot changes the rendered surface colour), **opaque surface** (`OverlayConfig.opacity` 0.9 present → alpha 255) | B-8; BR-U8-19/20/25/26; Q9; NFR-5.1 |
| F47 | `output/overlay/overlay_window_entry_test.dart` | N | `isOverlayWindowLaunch` true only for `['multi_window', '1', '...']`-shaped args (false for `[]`, one arg, a different first arg); `overlayWindowMain` with a bad payload builds the "Window unavailable" frame, logs `invalid_window_arguments`, and never sends `overlayReady`; with a good payload it installs the handler before sending `overlayReady`; a bad `captionUpdate` is dropped without throwing | ID-1/ID-2; BR-U8-19; R5 |
| F48 | `shell/zb_app_shell_test.dart` | M | external display on/off registers/deregisters the target and drives `show`/`hide`; `WindowClosed` and `OpenFailed` write `overlayEnabled=false` once; `DisplayLost` leaves `overlayEnabled` true and only updates bookkeeping; **no** recognition-state listener closes the window on stop/pause (D-5 regression guard) | F26; D-4/D-5; BR-U8-15 |
| F49 | `providers/output_target_settings_test.dart` | N | `externalDisplayId` and `externalDisplayCaptionPosition` persist and reload; a stored `overlayEnabled=true` reloads as **false** (BR-U8-21); an absent id stays `null` | F23; BR-U8-21 |
| F50 | `dart` lint / duplicate-import guard | — | no file; the SECURITY-10 fence is asserted by the plan's Step 24 grep (`rg -l "package:screen_retriever" packages/zip_broadcast/lib` → exactly one path) | SECURITY-10 §5 item 1 |

**File totals**: the file list has 50 rows, of which 48 name files (F19 names
three, F50 names none) — **34 paths created, 14 paths modified**:

| Group | Rows | Created | Modified |
|---|---|---|---|
| Models and types (`overlay/`) | F01, F02, F09-F14 | 8 | 0 |
| Codec | F15 | 1 | 0 |
| Window services (`overlay/`) | F03-F08 | 3 | 3 |
| Controller and target | F16, F17 | 1 | 1 |
| Sub-engine | F18, F19 (3 files) | 4 | 0 |
| Widgets and providers | F20, F21, F22 | 3 | 0 |
| Settings, shell, entry, strings | F23-F29 | 0 | 7 |
| Test helpers | F30-F33 | 2 | 2 |
| Tests | F34-F49 | 12 | 1 |
| **Total** | | **34** | **14** |

- **Created (34)**: `display_info.dart`, `display_enumerator.dart`,
  `screen_retriever_display_enumerator{,_io,_stub}.dart`,
  `overlay_window_mode.dart`, `overlay_activity.dart`, `caption_position.dart`,
  `overlay_event.dart`, `external_display_status.dart`,
  `caption_overlay_snapshot.dart`, `caption_overlay_codec.dart`,
  `overlay_window_controller.dart`, `overlay_window_entry.dart`,
  `overlay_window_bridge{,_io,_stub}.dart`,
  `widgets/external_display_controls.dart`, `widgets/overlay_window_app.dart`,
  `providers/overlay_window_controller_provider.dart`,
  `test/helpers/fake_display_enumerator.dart`,
  `test/helpers/fake_overlay_method_handler_installer.dart`,
  `test/output/overlay/{display_enumerator_contract,to_platform_frame,to_platform_frame_properties,resolve_open_display,resolve_open_display_properties,caption_overlay_codec,caption_overlay_codec_properties,overlay_window_controller,display_state_machine_properties,external_display_redaction,overlay_window_entry,desktop_window_service_io}_test.dart`,
  `test/widgets/{external_display_controls,overlay_window_app}_test.dart`,
  `. `test/providers/output_target_settings_test.dart` is F49 itself.
- **Modified (14)**: `desktop_window_service.dart`,
  `desktop_multi_window_service_io.dart`, `desktop_multi_window_service_stub.dart`,
  `caption_overlay_target.dart`, `providers/broadcast_providers.dart`,
  `models/output_target_settings.dart`, `models/overlay_config.dart`,
  `lib/main.dart`, `l10n/arb/app_en.arb`,
  `test/helpers/mock_desktop_window_service.dart`,
  `test/helpers/generators.dart`, `test/output/caption_overlay_target_test.dart`,
  `test/shell/zb_app_shell_test.dart`.

One test file named by the steps has no F-row of its own
(`test/output/overlay/desktop_window_service_io_test.dart`, Step 9); it is
counted in the "Tests" row above (12 created there = F34-F43 + F45-F47 + F49
+ that one).
Generated artifacts (`*.freezed.dart`, `build_runner` output,
`lib/src/l10n/*.dart`, `macos/Podfile.lock`) are build output produced by the
steps that regenerate them; they are never hand-written and are not counted.

Step 24 re-derives the actual created/modified counts from
`git status --short` for the Part 2 summary; this section fixes the list.

---

## 3. Test list

T1-T17 below are the **state-machine transitions** (FD `business-logic-model.md`
state machine), each with its named test. FP-1..FP-5 are the FD properties.

| # | Behaviour | Test file / name | Source |
|---|---|---|---|
| T1 | capability check false → `Unsupported`; section hidden | `external_display_controls_test.dart` "Unsupported renders nothing"; `overlay_window_controller_test.dart` "capability false → Unsupported" | T1, BR-U8-11 |
| T2 | `Unsupported` stays | controller test "no toggle/no window in Unsupported" | T2 |
| T3 | first `displays()` empty → `NoDisplays`; toggle disabled | controller test + controls test "NoDisplays" | T3 |
| T4 | `changes` adds a display → `Off`, primary pre-selected | controller test "NoDisplays + change → Off" | T4 |
| T5 | toggle on → `Opening`; `overlayEnabled` true; `createWindow` called | controller test "toggle on opens" | T5, BR-U8-01 |
| T6 | `createWindow` throws → `Failed(create_failed)`, idempotent close, `overlayEnabled` false | controller test "create throws" | T6, BR-U8-03 |
| T7 | `overlayReady` within timeout → `Open`; `setFrame`, `show`, held snapshot sent | controller test "ready opens" | T7, B-6, P1 |
| T8 | timeout → `Failed(ready_timeout)`, half-open window closed, `overlayEnabled` false | controller test "ready timeout" (`fakeAsync`) | T8, BR-U8-03/23 |
| T9 | recognition event changes only `activity` | target test "activity follows SessionStateEvent"; shell test "no window change on stop/pause" | T9, BR-U8-17, D-5 |
| T10 | selected display gone → close, `DisplayLost`, `WaitingForDisplay`, `overlayEnabled` true | controller test "display lost" | T10, BR-U8-22, D-4 |
| T11 | saved display back → reopen | controller test "saved display returns" | T11 |
| T12 | Cancel → `Off`, saved id kept | controller test "cancel" + controls test "Cancel keeps id" | T12, BR-U8-07 |
| T13 | toggle off → `Off`, close once | controller test "toggle off" | T13, BR-U8-02 |
| T14 | `'-1'` post-ready → `WindowClosed` → `Off` | controller test "window closed" + shell test "WindowClosed clears overlayEnabled" | T14, BR-U8-04, D-9 |
| T15 | same id, new bounds → `setFrame`, no re-handshake | controller test "reframe" | T15, BR-U8-09 |
| T16 | `Failed` + toggle on → retry | controller test "retry from Failed" | T16 |
| T17 | coalesced no-change `changes` → no emission | `display_enumerator_contract_test.dart` "identical list emits nothing" | T17, BR-U8-05 |
| FP-1 | codec round-trip | `caption_overlay_codec_properties_test.dart` | PBT-02 |
| FP-2 | codec total-on-error | same file, second property | PBT-03 |
| FP-3 | frame conversion identity / multiply / y-flip | `to_platform_frame_properties_test.dart` + named examples | PBT-05 |
| FP-4 | open resolution + absent id kept | `resolve_open_display_properties_test.dart` + examples | PBT-03 |
| FP-5 | state-machine closure + closed invariant + single window | `display_state_machine_properties_test.dart` | PBT-03/04/06 |
| — | PBT-04 close idempotence, asserted once directly | controller test "close twice == close once" | PBT-04 |
| — | BR-U8-20 theme-wiring / contrast (acceptance) | `overlay_window_app_test.dart` "theme swap changes surface colour" | BR-U8-20, NFR-5.1 |
| — | opaque surface (acceptance) | `overlay_window_app_test.dart` "opaque" | BR-U8-26, B-8 |
| — | position-selector persistence (B-8) | controls test "Caption Position writes and reaches launch" | B-8, T9 pointer in review |
| — | redaction record test | `external_display_redaction_test.dart` | BR-U8-18, S2 |
| — | "Window unavailable" frame | `overlay_window_app_test.dart` + `overlay_window_entry_test.dart` | BR-U8-19 |

**PBT framework**: the in-tree shim `packages/zip_broadcast/test/helpers/pbt.dart`
(`Generator<T>`, the `any` generators, `Glados<T>(gen).test(...)` with 100 fixed
seeds `0..99`, async bodies, **no shrinking**). There is no `glados` dependency
and none is added (PBT-09 Q7). Counterexamples are hand-reduced and pinned as
example tests (PBT-10). `fake_async` drives the ready timeout and the coalescer;
`mocktail` mocks `DesktopWindowService`.

**Mock/fake list**:

| Helper | Shape |
|---|---|
| `MockDesktopWindowService` (extended in place, doc only) | mocktail; `setFrame`/`show` stubbed per test; `isSupported`, `createWindow`, `closeWindow`, `invokeMethod` as today |
| `FakeDisplayEnumerator` | scripted `displays()`, pushable `changes` replaying the latest list, recorded idempotent `dispose()` |
| `FakeOverlayMethodHandlerInstaller` | records the installed handler (and uninstall), exposes it |
| `FakeScreenEventSource` (inside F34) | a `ScreenListener`-shaped fake so the io adapter's diff normalisation can be tested without the plugin |
| `OutputTargetSettingsNotifier` | provider override (existing harness) |
| `DisplaySettings Function()` | a plain closure in tests |

---

## 4. Numbered, ordered steps (TDD-first)

Each step: **write the failing test first**, confirm it fails for the expected
reason, then implement, then re-run. One commit per group unless stated.
Commit scaffolding follows `docs/04-technical-specification.md` §7
(Conventional Commits, package scope).

### Group A — dependency and contracts

1. [x] **`pubspec.yaml`** — add `screen_retriever: ^0.2.2` with the §1.2
    comment; run `flutter pub get` in `packages/zip_broadcast`; confirm the
    resolved version is 0.2.2 (not 0.3.x) and `git diff pubspec.lock` shows
    exactly the five entries of §1.3. Run `dart analyze --fatal-infos` (clean)
    and `flutter test` — the resolution alone must not change any result. The
    plugin import and its deprecation check under the pin (ID-3) land with
    Step 10, which is the first step to import it.
    *Test*: none. *Commit*: `feat(zip_broadcast): add screen_retriever dependency for display enumeration`.

2. [x] **F01 `display_info.dart`** (+ freezed). *Test*: F33's generator
    compiles and `DisplayInfo` equality holds over `Rect`/`scaleFactor`
    (asserted inside F35's named examples).
    *Commit*: `feat(zip_broadcast): add DisplayInfo model`.

3. [x] **F09-F13** (`overlay_window_mode`, `overlay_activity`,
    `caption_position`, `overlay_event`, `external_display_status`) — plain
    Dart sealed types. *Test*: an exhaustive `switch` compiles in
    `overlay_window_controller_test.dart`'s fixture and the controls test's
    status matrix (F45); `const OverlayConfig()` (after Step 18) equals
    `ExternalDisplayMode()` + defaults.
    *Commit*: `feat(zip_broadcast): add external display state and event types`.

4. [x] **F24 `output_target_settings.dart`** — add `externalDisplayId` and
    `externalDisplayCaptionPosition`; regenerate freezed. *Test*: F49
    (`providers/output_target_settings_test.dart`, written first and failing on
    the missing fields; it also covers the persistence in Step 5).
    *Commit*: `feat(zip_broadcast): add external display settings fields`.

5. [ ] **F23 `broadcast_providers.dart`** — the two keys, persistence, and the
    launch force-off. *Test*: F49 (per-field persistence; stored
    `overlayEnabled=true` → loaded false; absent id stays null).
    *Commit*: `feat(zip_broadcast): persist external display selection and caption position`.

### Group B — pure logic (no I/O)

6. [ ] **F14 `caption_overlay_snapshot.dart`** + **F15
    `caption_overlay_codec.dart`**. *Test first*: **F39** named examples, then
    **F40** (FP-1, FP-2). Implement until both pass; FP-2 must be `null`, never
    a throw, for every malformed generator output.
    *Commit*: `feat(zip_broadcast): add versioned caption overlay codec`.

7. [ ] **F16 `overlay_window_controller.dart` — the pure part**: `resolveOpenDisplay`
    only (the class lands in Step 12). *Test first*: **F37**, then **F38** (FP-4).
    *Commit*: `feat(zip_broadcast): add open-display resolution`.

8. [ ] **F06/F07/F08 — the frame conversion**: add `toPlatformFrame` to
    `desktop_multi_window_service_io.dart` (pure, platform inputs as
    arguments; their callers are Step 9's `setFrame` and Step 12's reframe —
    see Step 12's note) *before* the interface methods, so the function has a
    test subject. *Test first*: **F35** named examples, then **F36**
    (FP-3). *Commit*: `feat(zip_broadcast): add platform frame conversion`.

### Group C — window service and enumeration

9. [ ] **F06/F07/F08 — the B-6 interface additions**: `setFrame(int, Rect)` and
    `show(int)` on the abstract class, the io implementation (calling
    `WindowController.fromWindowId(id).setFrame(converted)` /
    `.show()`), the stub's throwing versions; extend F32's doc.
    *Test first*: a new test file
    `output/overlay/desktop_window_service_io_test.dart` with two cases:
    (a) `toPlatformFrame` is a pure function — same inputs, same output, no
    enumerator or platform call (the frame-conversion half of F35/F36 also
    covers its rules); (b) the `@visibleForTesting` constructor accepts a
    `FakeDisplayEnumerator` and the adapter's `isSupported` is unchanged by it
    (the platform-channel calls themselves are not exercised — the plugin is
    never loaded in a test, per SECURITY-10 §5 item 3). The interface contract
    stays at the mock level (`MockDesktopWindowService`, F32).
    *Commit*: `feat(zip_broadcast): add setFrame and show to DesktopWindowService`.

10. [ ] **F02-F05 — the enumerator triplet**. *Test first*: **F34** (contract,
    id normalisation, repeated-name suffix, error keeps the stream open,
    idempotent dispose). Implement the interface + conditional export + io
    adapter (the single plugin import) + stub. Then run
    `rg -l "package:screen_retriever" packages/zip_broadcast/lib` and assert one
    path.
    *Commit*: `feat(zip_broadcast): add display enumeration behind the screen_retriever fence`.

### Group D — the controller

11. [ ] **F16 — the `OverlayMethodHandler`/installer typedefs and the production
    const** in `desktop_multi_window_service_io.dart` (+ the no-op in the stub),
    surfaced through the existing conditional export. *Test*: none of its own;
    exercised by F41's "handler installed before createWindow" and F42.
    *Commit*: folded into Step 12's commit.

12. [ ] **F16 — `OverlayWindowController`**. *Test first*: **F41** (the T1-T17
    table, the three close paths, the ready timeout under `fakeAsync`, the
    `'-1'` vs ignored-error discrimination, the held snapshot, the coalescer,
    the reframe, the retry, the open order). *Test first*: **F42** (FP-5).
    Implement R1-R6/P1-P5 exactly as the patterns file specifies:
    `_lifecycleLock` chaining, `_setState` structural timer cancellation,
    `_release` per-step `on Object` + `runtimeType`, `_windowCall` seam,
    `_readyTimer` started before `createWindow`, `_updateTimer` re-arming
    (not reset), the `changes` watch at controller lifetime, the held snapshot
    sent on ready, `resolveOpenDisplay` used by `open`, `selectDisplay` the only
    id writer, `reframe` calling `setFrame` with the current work area (the
    platform inputs travel through the io adapter's enumerator seam, Step 9
    and the note below), `dispose()` uninstalling the handler and disposing
    the enumerator.
    *Commit*: `feat(zip_broadcast): add OverlayWindowController`.

    **Note (implementation detail, not a design change).** The macOS
    conversion needs the primary **full** height, which `DisplayInfo` does not
    carry (B-1). The io adapter takes it as an argument (FP-3's signature).
    The io adapter reads it from the enumerator through one additive interface
    member, `Future<Size?> primarySize()`, declared on `DisplayEnumerator`
    (F02) and implemented in F04 (the plugin's `getPrimaryDisplay().size`) and
    F05 (`null`). The io adapter receives the platform inputs through a
    `@visibleForTesting` constructor seam,
    `DesktopMultiWindowService({DisplayEnumerator? enumerator})`, that defaults
    to the production enumerator; the controller never passes a height. A
    `null` height cannot occur on a real open (the open only proceeds on a
    resolved display, which implies `primarySize()` succeeded). This changes
    no BR, state, wire shape or test, and is recorded in Step 24's Part 2
    summary.

13. [ ] **F17 — `caption_overlay_target.dart` rewrite**. *Test first*: **F44**.
    Implement the thin delegator + caption-bus adapter (B-9); delete the shipped
    `_isVisible` field.
    *Commit*: `feat(zip_broadcast): reduce CaptionOverlayTarget to a controller delegator`.

14. [ ] **F22 — the providers**. *Test*: covered by F45/F48 via override;
    the provider file itself has no dedicated test (a hand-written `Provider`
    is wiring, not logic).
    *Commit*: `feat(zip_broadcast): add overlay window controller providers`.

### Group E — the sub-engine

15. [ ] **F19 — `overlay_window_bridge.dart` triplet**. *Test*: F47 uses the
    stub bridge; no separate test.
    *Commit*: folded into Step 16.

16. [ ] **F18/F21 — `overlay_window_entry.dart` and `overlay_window_app.dart`**.
    *Test first*: **F47** (entry) and **F46** (app: standby/live/paused,
    "Window unavailable", position, BR-U8-20 wiring, opaque). Implement; the
    app reads `AppTheme` and never a literal; `GoogleFonts.config` mirrored;
    handler installed before `overlayReady`; decode failures total.
    *Commit*: `feat(zip_broadcast): add the external display sub-engine entry and window app`.

17. [ ] **F25 `overlay_config.dart`** — `targetDisplayId` → `mode`; regenerate
    freezed. *Test*: a compile + equality case in F45's fixture and the
    controller's config construction.
    *Commit*: `feat(zip_broadcast): replace OverlayConfig.targetDisplayId with a window mode`.

18. [ ] **F28 `main.dart`** — the `main(List<String> args)` signature and the
    overlay branch. *Test*: F47's `isOverlayWindowLaunch` cases cover the
    predicate; the branch itself is three lines and is verified by
    `dart analyze` plus the entry test's `overlayWindowMain` cases (which prove
    the overlay path never reaches Supabase startup). No test invokes the
    top-level `main` (none does today; `flutter run` passes an empty list, so
    the broadcast path is unchanged).
    *Commit*: `feat(zip_broadcast): route the multi-window launch to the overlay sub-engine`.

### Group F — controls and settings surface

19. [ ] **F20 — `external_display_controls.dart`**. *Test first*: **F45**.
    *Commit*: `feat(zip_broadcast): add ExternalDisplayControls`.
20. [ ] **F27 — `output_targets_panel.dart`** — swap the Phase 1 card for the
    controls. *Test*: extend the existing panel/widget test to assert the
    section renders and no Phase 1 switch remains.
    *Commit*: `feat(zip_broadcast): host ExternalDisplayControls in the output targets panel`.

### Group G — shell wiring

21. [ ] **F26 — `zb_app_shell.dart`**. *Test first*: **F48** (register/deregister,
    `WindowClosed`/`OpenFailed` → `overlayEnabled` false, `DisplayLost`
    bookkeeping, no recognition listener).
    *Commit*: `feat(zip_broadcast): wire the overlay controller into the app shell`.

### Group H — strings

22. [ ] **F29 — `app_en.arb`** + `flutter gen-l10n` (§6 keys). Never edit
    `lib/src/l10n/*.dart` by hand. *Test*: F45 using the real generated
    localizations (the harness already provides `ZipBroadcastLocalizations`).
    *Commit*: `feat(zip_broadcast): add external display ARB strings`.

### Group I — runners (D-2, B-3)

23. [ ] **`macos/Runner/MainFlutterWindow.swift`** — in `awakeFromNib`, after
    `self.contentViewController = flutterViewController`, register
    `FlutterMultiWindowPlugin.setOnWindowCreatedCallback` setting the borderless
    `styleMask` (`controller.view.window?.styleMask.remove([.titled, .closable,
    .miniaturizable, .resizable])`); the plugin list is empty (A-5). No
    `didBecomeKey` observer. **`windows/runner/flutter_window.cpp`** — in
    `OnCreate`, after `RegisterPlugins`, before `SetChildContent`, call
    `DesktopMultiWindowSetWindowCreatedCallback` (include
    `desktop_multi_window/desktop_multi_window_plugin.h`), cast to
    `flutter::FlutterViewController*`, `GetAncestor(...view()->GetNativeWindow(),
    GA_ROOT)`, remove `WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
    WS_MAXIMIZEBOX | WS_SYSMENU` from `GWL_STYLE`, then `SetWindowPos(hwnd,
    nullptr, 0, 0, 0, 0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
    SWP_FRAMECHANGED)`. **`linux/runner/my_application.cc`** — in
    `my_application_activate`, before the main window shows, call
    `desktop_multi_window_plugin_set_window_created_callback` (include
    `desktop_multi_window/desktop_multi_window_plugin.h`) with
    `gtk_window_set_decorated(GTK_WINDOW(gtk_widget_get_toplevel(...)), FALSE)`.
    *Test*: no Dart test; macOS compiles in Step 25; Windows/Linux compile in
    CI's `build-verify.yml` after the push; behaviour is a Unit 9 manual check.
    *Commit*: `feat(zip_broadcast): apply borderless styling from the window-created callback on all runners`.

### Group J — final gates

24. [ ] Run the three gates from package roots (§5). Run
    `rg -l "package:screen_retriever" packages/zip_broadcast/lib` (exactly one
    path) and `rg -n "window_manager|kIsWeb|popOut|PopOut|pipContent|ping"
    packages/zip_broadcast` (no match in the unit's files). Record the results.
    *Commit*: none yet — the results feed Step 26.

25. [ ] **`flutter build macos --debug`** in `packages/zip_broadcast`
    (compile only, nothing launched). Then inspect `git diff
    packages/zip_broadcast/macos/Podfile.lock` (§1.3). If anything outside the
    allowed set moved, record it — do not stage.
    *Commit*: the `Podfile.lock` entries (if any) join Step 26.

26. [ ] **Lockfile review + final commit.** `git diff --stat pubspec.lock
    packages/zip_broadcast/macos/Podfile.lock`; stage only §1.3's entries.
    Write `aidlc-docs/construction/external-display/code/` summaries (Part 2
    artifact, same shape as Unit 7's). The commit message:
    `feat(zip_broadcast): add external display output (S-20)`.
    The PR body (stage 6's job, per A3) lists the stages, gate output, the
    review-comment pointer, and the Unit 9 manual checks (§5.3).

**Commit split summary**: Steps 1-23 are 21 commits (Step 11 folds into 12,
Step 15 into 16); Step 26 is the final one. Test commits are
folded into each feature step because each step's test is written and kept in
the same commit — the TDD order is enforced by the step sequence, matching the
Unit 7 plan's shape, which the project records as "test-first within the
step").

---

## 5. Verification

### 5.1 Final gates (from package roots)

| Package | Command | Must |
|---|---|---|
| `packages/zip_core` | `dart analyze --fatal-infos && flutter test` | clean, all pass (regression guard — must not change) |
| `packages/zip_captions` | `dart analyze --fatal-infos && flutter test` | clean, all pass (regression guard — must not change) |
| `packages/zip_broadcast` | `dart analyze --fatal-infos && flutter test` | clean, all pass |

### 5.2 Build verification

- `cd packages/zip_broadcast && flutter build macos --debug` — **compile only**,
  nothing launched. This compiles the Swift runner change (Step 23).
- **Windows and Linux runner code is not compiled locally.** It is compiled by
  CI's `build-verify.yml` after the push (A3/Stage 6); CI must be green before
  the run hands off. A Windows/Linux compile failure is a fix-commit in the
  same stage, not a silent exclusion.
- Web is not built; the stub path is exercised by `flutter test` on the host
  and by `dart analyze`.

### 5.3 Unit 9 manual checks (recorded, **not claimed**)

The device policy forbids a device, emulator, simulator, launched app or a
second display. The following are **manual checks for Unit 9**; the PR body
lists them under that heading and no stage claims them verified:

1. Display placement and work-area framing on real multi-monitor hardware,
   including fractional scaling and Wayland.
2. Borderless rendering on all three platforms (macOS `styleMask`, Windows
   `GWL_STYLE`, Linux `gtk_window_set_decorated`), including A7's "borderless
   applied on macOS".
3. Reopen-on-reconnect with a real hot-plug (unplug the selected display, wait,
   re-plug).
4. Closing the window by the OS shortcut (the real `'-1'` path).
5. Sub-window font rendering on macOS (B-4's "confirm by running", A-5).

---

## 6. Strings (ARB keys to add to `l10n/arb/app_en.arb`)

All English source; no string contains caption text (BR-U8-18). Keys follow
the existing `settings*`/`outputTargets*` style.

| Key | English (Proto-13 source) | Notes |
|---|---|---|
| `externalDisplayTitle` | `External Display` | section label |
| `externalDisplayDescription` | `Show captions on a second monitor or projector.` | section sub-copy |
| `externalDisplayAvailable` | `Available Displays` | list header |
| `externalDisplayNoDisplays` | `No displays detected` | `NoDisplays` body |
| `externalDisplayDisplayNumber` | `Display {index}` | `int index` placeholder |
| `externalDisplayPrimarySuffix` | `primary` | meta line |
| `externalDisplaySelectedSuffix` | `selected` | meta line |
| `externalDisplayConnectedSuffix` | `connected` | `Open` meta line |
| `externalDisplayDisconnectedSuffix` | `disconnected` | waiting row meta |
| `externalDisplayActive` | `Active` | pill (`Open`) |
| `externalDisplayOpening` | `Opening…` | `Opening` affordance |
| `externalDisplayCaptionPosition` | `Caption Position` | selector label |
| `externalDisplayPositionTop` | `Top` | selector button |
| `externalDisplayPositionBottom` | `Bottom` | selector button |
| `externalDisplayDisconnected` | `The {label} was disconnected — captioning continues, but the external display output has stopped.` | `String label`; banner (D-4) |
| `externalDisplayWaiting` | `waiting for display` | status line |
| `externalDisplayCancel` | `Cancel` | waiting action (no `Cancel` key exists today) |
| `externalDisplayOpenFailed` | `The external display window could not start.` | fixed copy; the reason code is never shown |
| `overlayWindowUnavailable` | `Window unavailable` | sub-engine fixed frame |

Run `flutter gen-l10n` after editing; never edit `lib/src/l10n/*.dart`.

---

## 7. Non-goals (hard fences)

- **No `window_manager`** anywhere — not a dependency, not an import, not a
  file. Its record `window-manager-security-10.md` was deleted in Stage 1
  (D-13).
- **No pop-out of any kind** — no `PopOutMode`, `popOutEnabled`,
  `popOutDisplayId`, `PipContent`, `popOutSize`, `PopOutToggle`, `PopOutHint`,
  the inbound `popOutToggle` message, or pop-out ARB keys. The pop-out is its
  own Phase 2 unit after Unit 8, blocking the v2.0 RC, definition pending
  (D-1, A7).
- **No `zip_core` / `zip_captions` / `zip_supabase` change** (D-8; unit
  exception 1). The codec is hand-written in `zip_broadcast`.
- **No new dependency** beyond `screen_retriever: ^0.2.2`. A dependency need is
  BLOCKED, not a fix (Q7, A5).
- **No translation fields.** Unit 8 adds none (YAGNI, A7). Forward note,
  recorded not implemented: the codec's per-entry `key` **is**
  `CaptionDisplayEntry.entryId` (the segment ID Phase 8 keys translations by),
  and the codec's `v` is the field Phase 8 bumps for bilingual mode. Both are
  documented in the codec's doc comment and nowhere else.
- **Always-on-top is not implemented** — not a Unit 8 requirement (ID-5,
  review §3). The pop-out unit owns its own topmost behaviour.
- **`OverlayConfig.opacity` is not applied** — the external display renders an
  opaque surface (B-8, BR-U8-26); the field stays for the shipped contract.
- **No native full-screen** (D-3, Backlog); the work-area frame is the
  full-screen stand-in.
- **No per-input colour** (`sourceColorValues`/`AudioInputVisualStyle`) in the
  window — Backlog (D-7, BR-U8-13).
- **No recognition-state listener in the shell** (D-5); recognition changes
  only the snapshot `activity`.
- **Web is excluded by `DesktopWindowService.isSupported`**, never `kIsWeb`
  (BR-U8-11).
- **No `docs/` change**; no `pip-ux-parity.md`, `v1-parity/`, `spikes/` or
  `opencode.json` change; no pop-out unit definition.
- **No CMake, manifest, Podfile or entitlement edits** (ID-5 "additionally").
- **No string literal** in `ExternalDisplayControls` or `OverlayWindowApp`.

---

## 8. Self-check

### 8.1 S-20 acceptance criteria (AC4 as amended) → steps/tests

| AC | Satisfied by | Evidence |
|---|---|---|
| All connected displays listed, one selectable | Steps 10, 14, 19, 20 | F34, F45 (`Off` rows, tap writes id), paths F01-F05, F20 |
| Enabling opens a borderless window on that display showing live captions with the broadcaster's display settings | Steps 9, 12, 13, 16, 23 | F41 (T5/T7/T15), F35/F36 (frame), F46 (live render), Step 23 runners |
| Signed-out works unchanged (no account) | Steps 16, 18 | `overlayWindowMain` never initialises Supabase; no auth read anywhere (BR-U8-14); F47 |
| **Disabling closes the window and releases its resources (AC4 as amended)** | Step 12, 21 | F41 (T13), F42 (closed invariant, BR-U8-15), F48 |
| Disconnect falls back gracefully, notifies, no orphaned window | Step 12, 19 | F41 (T10/T11), F45 (`WaitingForDisplay`), F42 |
| Web: not offered | Steps 10, 19, 14 | F05 stub, F45 (`Unsupported` renders nothing), BR-U8-11 |
| Contrast WCAG AAA (7:1) | Step 16 | F46 BR-U8-20 theme-wiring; ratio owned by `zip_core/test/pbt/theme_contrast_test.dart` (not repeated) |
| (B-8) Caption Position Top/Bottom, persisted | Steps 4, 5, 19 | F49, F45 position selector, F46 top vs bottom |

### 8.2 BR-U8-xx → steps/tests

| Rule | Step(s) | Test(s) |
|---|---|---|
| BR-U8-01 one window, serialised | 12 | F41 (second open no-op), F42 (single window) |
| BR-U8-02 closing releases | 12 | F41 (three close paths), F42 |
| BR-U8-03 failed open changes nothing but the notice | 12 | F41 (T6/T8), F43 |
| BR-U8-04 `'-1'` only, never into the UI | 12 | F41 (`'-1'` vs ignored), F48 |
| BR-U8-05 list reflects the platform | 10 | F34 |
| BR-U8-07 resolution; saved id kept | 7, 12, 14 | F37, F38, F41 (T12), F45 (Cancel keeps id) |
| BR-U8-08 empty label selectable | 19 | F45 ("Display N") |
| BR-U8-09 work area, fixed order, re-apply | 8, 9, 12 | F35/F36, F41 (T7/T15) |
| BR-U8-11 web by capability | 10, 19 | F45 (`Unsupported`), F05 |
| BR-U8-12 live content | 13, 16 | F44 (settings reach next snapshot), F46 |
| BR-U8-13 no per-input colour | 13, 16 | F44/F46 (no `sourceColorValues` in the snapshot) |
| BR-U8-14 signed-out only | 16, 18 | F47, no auth import |
| BR-U8-15 closed invariant | 12, 21 | F42, F48 |
| BR-U8-17 recognition changes activity only | 13, 21 | F44, F48 (regression guard) |
| BR-U8-18 no caption text outside | all | F43 |
| BR-U8-19 malformed input dropped | 6, 16 | F39/F40 (`null`), F47 |
| BR-U8-20 theme wiring | 16 | F46 |
| BR-U8-21 switch starts off | 5 | F49 |
| BR-U8-22 disconnect closes/keeps on/waits/reopens | 12, 19 | F41 (T10-T12), F45 |
| BR-U8-23 one handler, ready handshake, fixed timeout | 11, 12 | F41 (T7/T8), F42 |
| BR-U8-24 codec hand-written, versioned, total | 6 | F39, F40 |
| BR-U8-25 window mirrors the main window | 16 | F46 |
| BR-U8-26 opaque surface, position persisted | 4, 5, 16, 19 | F46 (opaque), F45/F49 (position) |

### 8.3 Strict-transcription statement

This plan is a strict transcription of the revised design. Every file, step,
test, constant, string and non-goal cites the FD, NFR Requirements, NFR Design,
Infrastructure Design artifact or the PR #37 review comment (D-n/B-n/A7) that
fixes it. **There are zero open questions, zero TBD items and zero
"to be decided" items.** The five assumptions in §1.4 are transcriptions of
decisions already recorded in the binding stages, not new questions. No design
decision is made here that the artifacts do not already make; the two
"implementation detail" notes (Step 12's `primaryFullHeight` accessor and the
file-count arithmetic) are additive plumbing, recorded for the Part 2 summary,
and change no rule, state, wire shape or test.

**Application Design deviations recorded (review §3), all approved by the
review:** `OverlayConfig.targetDisplayId` → `mode`; `DisplayEnumerator.dispose()`;
the `OverlayEvent` variants; the new `OverlayWindowController`; the
`DesktopWindowService.setFrame`/`show` additions; the S-20 AC4 amendment.
The disconnect behaviour is **not** a deviation (F8 conformance).