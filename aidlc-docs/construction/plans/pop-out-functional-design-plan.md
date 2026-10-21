# Functional Design Plan — Unit 8.1: Pop-out Live Captions (S-21)

**Unit**: 8.1 — Pop-out Live Captions (PiP)
**Story**: S-21 (`aidlc-docs/inception/user-stories/phase2-stories.md`)
**Packages**: `zip_core` (promoted window machinery), `zip_broadcast`, `zip_captions`
**Branch**: `feature/popout-live-captions` (off `develop` at `5e3bd3b`)
**Stages this unit runs**: Functional Design, NFR Requirements, NFR Design,
Infrastructure Design, Code Generation Parts 1 and 2. Each runs, gated before Code Generation
Part 1 and again before Part 2's first edit.
**Run mode**: interactive. Every stage stops for explicit human approval; no stage is
pre-approved.

---

## Binding design inputs (read before this plan was written)

| Input | Status |
|---|---|
| `aidlc-docs/construction/output-targets/functional-design/pip-ux-parity.md` §8 (all of it; §8.3, §8.4, §8.5, §8.7, §8.8 are the contract) | Binding. §8 is the **sole** specification of both toggles (approved Proto-15 has no pop-out control). |
| `aidlc-docs/inception/application-design/phase2-unit-of-work.md` — Unit 8.1 | Binding scope, package split, platform scope, plugin-registration decision. |
| `aidlc-docs/inception/user-stories/phase2-stories.md` — S-21 | Binding acceptance criteria (per app) and deferrals. |
| `aidlc-docs/construction/pop-out/functional-design/window-manager-security-10.md` | Binding dependency record (SECURITY-10). |
| `phase2-unit-of-work-dependency.md`, `-story-map.md` | U8.1 depends on U8 only; Jordan and Alex; blocks the v2.0 RC and U9. |
| `aidlc-docs/aidlc-state.md` | Current stage and Backlog (NSPanel limitation accepted). |
| Shipped Unit 8 code (below) | The refactor subject. Verified by reading, not by the vault. |

## Shipped code read before designing (verified 2026-10-21)

| File | What it establishes |
|---|---|
| `zip_broadcast/lib/src/output/overlay/overlay_window_controller.dart` (744 lines) | `OverlayWindowController` state machine (T1-T17 equivalent), `resolveOpenDisplay`, `CloseReason`, `OverlayMethodHandler`/`Installer` typedefs, `overlayReadyTimeout` 10 s, `captionUpdateInterval` 16 ms, `_lifecycleLock`, `_windowCall` `'-1'` seam, `_release`, `_setState`. |
| `.../overlay_window_mode.dart` | `sealed class OverlayWindowMode` + `final class ExternalDisplayMode({displayId})`. |
| `.../caption_overlay_codec.dart` | `CaptionOverlayCodec` (v1, 16 KiB cap, total-on-error), `OverlayWindowLaunch`, top-level `encodeLaunch`/`decodeLaunch`/`encodeSnapshot`/`decodeSnapshot`. Encodes `mode: 'externalDisplay'` as a fixed string. |
| `.../caption_overlay_snapshot.dart` | `CaptionOverlaySnapshot{activity, entries, interim, settings}` with hand-written equality. |
| `.../overlay_activity.dart`, `overlay_event.dart`, `external_display_status.dart` | `OverlayActivity`; `OverlayEvent` (`DisplayLost`/`WindowClosed`/`OpenFailed`); `ExternalDisplayStatus` (`Unsupported`/`NoDisplays`/`Off`/`Opening`/`Open`/`WaitingForDisplay`/`Failed`). |
| `.../desktop_window_service.dart` | `DesktopWindowService` interface: `createWindow`, `closeWindow`, `invokeMethod`, `setFrame`, `show`, `isSupported`. |
| `.../desktop_multi_window_service_{io,stub}.dart` | The conditional-export fence; `toPlatformFrame` (pure); `overlayMethodHandlerInstaller`; `isSupported = macOS || Windows || Linux`. |
| `.../overlay_window_bridge{,_io,_stub}.dart` | `OverlayWindowBridge` sub-engine seam; `DesktopMultiWindowBridge` sends `overlayReady` to window `0`; `NoopOverlayWindowBridge`. |
| `.../overlay_window_entry.dart` | `isOverlayWindowLaunch(args)` (`args.length >= 3 && args.first == 'multi_window'`); `overlayWindowMain(args, {bridge, pump})`; `OverlayWindowEntry` (handler installed before ready; bad `captionUpdate` dropped). |
| `.../display_enumerator.dart`, `display_info.dart`, `screen_retriever_display_enumerator{,_io,_stub}.dart` | The display fence and the documented `changes` contract. |
| `.../caption_overlay_target.dart` | `CaptionOverlayTarget` — bus adapter + controller delegator; `_activityFor(RecordingState)`; `isVisible => controller.isWindowOpen`. |
| `zip_broadcast/lib/src/models/overlay_config.dart`, `overlay_position.dart` | `OverlayConfig{mode, position, opacity}`, `OverlayPosition` sealed family. |
| `zip_broadcast/lib/src/widgets/overlay_window_app.dart`, `external_display_controls.dart` | The window's `MaterialApp`/surface/standby matrix; the output-panel controls. |
| `zip_broadcast/lib/src/providers/overlay_window_controller_provider.dart` | The single shared enumerator, controller provider, status and display-list streams. |
| `zip_broadcast/lib/src/shell/zb_app_shell.dart` | `_syncOverlay`, `_onOverlayEvent`, `_unregisterOverlay`, `_retarget`, `_switchOverlayOff`. |
| `zip_broadcast/lib/main.dart` | `main(List<String> args)` routes `isOverlayWindowLaunch` **before** Supabase/logging. |
| `zip_broadcast/{macos,windows,linux}/runner/...` | The three window-created callbacks (borderless only, today). |
| `zip_core/lib/src/widgets/caption_display_widget.dart`, `providers/caption_output_target_registry_provider.dart`, `providers/on_screen_caption_target_provider.dart`, `providers/recording_state_notifier.dart`, `services/stt/stt_engine_registry.dart` | The shared surface, the registry, the buffer provider, the recognition state, the engine registry. |
| Unit 8 artifacts under `aidlc-docs/construction/external-display/` | FD/NFR-D/ID decisions this refactor must preserve (B-1..B-9, D-1..D-13). |

**Unit 8's test suite (the safety net)** — 18 test files/suites touch the machinery:
`test/output/overlay/{caption_overlay_codec_test, caption_overlay_codec_properties_test,
desktop_window_service_io_test, display_enumerator_contract_test, display_info_test,
display_state_machine_properties_test, external_display_status_test,
overlay_window_controller_test, overlay_window_entry_test, resolve_open_display_test,
resolve_open_display_properties_test, to_platform_frame_test,
to_platform_frame_properties_test}.dart`, `test/output/caption_overlay_target_test.dart`,
`test/widgets/{external_display_controls_test, overlay_window_app_test}.dart`, plus the
overlay/redaction parts of `test/shell/zb_app_shell_test.dart`. Helpers in play:
`test/helpers/{fake_display_enumerator, generators, mock_desktop_window_service, pbt}.dart`.
`test/helpers/pbt.dart` is byte-identical to `zip_core/test/helpers/pbt.dart`.

## Contradictions found between the design inputs and the shipped code

None that block. Two facts worth recording because the inputs describe them loosely:

- The unit definition says the "ready handshake" and "sub-engine entry contract" are promoted.
  Shipped, the handshake is three things in three places: the `OverlayMethodHandler`/`Installer`
  typedefs and the controller's `_handleWindowCall`/`_runReady` (controller), the
  `DesktopMultiWindowBridge.send` call (bridge), and the `desktop_multi_window` static handler
  slot (io adapter). The promotion has to move all three, not one.
- `OverlayConfig.mode`'s default is `ExternalDisplayMode()`. That default is a
  Unit-8-specific choice inside a type the pop-out must share; the promotion has to decide what
  the neutral default is (Q3).

---

## Functional Design questions

Answer by filling the letter after each `[Answer]:`.

## Question 1
Which `OverlayWindowMode` variant does the pop-out window use, and what does the codec carry for it?

A) New `PopOutMode` (no fields) as a sibling of `ExternalDisplayMode`; the codec's `config.mode`
   encodes `'popOut'`, and `decodeLaunch` accepts both `'externalDisplay'` and `'popOut'`
   (per-mode `position` decoded the same way for both).
B) Reuse `ExternalDisplayMode(displayId: null)` for the pop-out and carry the intent in a new
   `CaptionOverlaySnapshot` field instead of the mode.
C) One `OverlayWindowMode` variant with a `kind` flag (`externalDisplay`/`popOut`) and an optional
   `displayId`.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 2
Where do the promoted types live, and behind which fence?

A) Everything desktop-only (controller, mode, codec, entry, snapshot, status, events, activity,
   `DesktopWindowService`, bridge, `DisplayEnumerator`/`DisplayInfo`, `window_manager` helper)
   moves into `zip_core/lib/src/output/overlay/` as `lib/src/...` internals, exported from a new
   `lib/src/output/overlay/overlay.dart` barrel that `zip_core.dart` exports; the two plugin
   imports stay inside the existing conditional-export fence files (`_io`/`_stub`), and the
   winning `_io` files are the only ones importing `desktop_multi_window`/`window_manager`, each
   now also gated on `dart.library.io` rather than `dart.library.html`.
B) Same placement, but only the controller/mode/codec/entry are public; the enumerator, window
   service and bridge stay package-private behind a single `OverlayWindowHost` facade that the
   apps use.
C) Put the machinery in a new fourth package `zip_windowing` that both apps depend on.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 3
`OverlayConfig` (and `OverlayPosition`) are app-local Phase 1 types today. Once the machinery is
shared, where does the launch configuration type live?

A) Move `OverlayConfig` and `OverlayPosition` into `zip_core` too; `zip_broadcast`'s
   `models/overlay_config.dart`/`overlay_position.dart` become re-exports of the `zip_core` types
   so every existing import and its generated `freezed` file keep compiling unchanged.
B) Keep `OverlayConfig` in `zip_broadcast` and make the promoted codec generic over it via a
   small `OverlayLaunchConfig` interface in `zip_core` that `OverlayConfig` implements.
C) Move them into `zip_core` and update every call site to the `zip_core` path (no re-exports).
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 4
The pop-out must always be on top, and `windowManager` is a process global acting on the window
that exists in *its own* engine. How does `setAlwaysOnTop` reach the pop-out window?

A) The sub-engine calls `windowManager.ensureInitialized()` then
   `windowManager.setAlwaysOnTop(true)` in its own startup path (before `overlayWindowMain`
   pumps the app), with `windowManager.setResizable(true)` and a minimum size applied the same
   way; this is a new `AlwaysOnTopInstaller` seam in `zip_core`'s `_io` adapter implemented with
   `window_manager`, no-op in the `_stub`, injected into `overlayWindowMain`.
B) The sub-engine passes the window id to the main engine, and the main engine calls
   `setAlwaysOnTop` on that id.
C) `overlayWindowMain` calls `WindowOptions(alwaysOnTop: true)` through a fresh
   `windowManager.waitUntilReadyToShow` in a wrapper `MaterialApp`.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 5
What exactly does the app-level pop-out (per app) own, and how does "an open is in progress" work?

A) A thin `PopOutSession`/`PopOutControls` pair per app: the session subscribes to the bus and the
   controller exactly as `CaptionOverlayTarget` does, and the toggle is idempotent through the
   controller's own `Opening`/`Open` guard (BR-PIP-02 is satisfied by the state machine, with no
   second flag in the UI). `CaptionOverlayTarget` stays in `zip_broadcast` unchanged except for
   import paths, and a sibling `PopOutCaptionTarget` implements the same `CaptionOutputTarget`
   contract with `PopOutMode`.
B) One `PopOutController` in `zip_core` above `OverlayWindowController` that owns the isOpening
   flag, the ARB-free state, and the toggle semantics, with each app rendering only.
C) A single app-level flag (`popOutOpening`) in each app's shell, checked before the call.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 6
UX-PIP-02's in-surface toggle lives *inside* the caption surface and must work from the pop-out
window. `CaptionDisplayWidget` is shared and takes no callbacks today. How is it added?

A) Add optional `Widget? trailing` (or a `List<Widget> controls`) parameter to
   `CaptionDisplayWidget`, defaulted to `null` so both apps' existing call sites are untouched;
   the pop-out window passes the in-surface toggle, and the main-window caption surface passes
   the same button. The widget stays platform-agnostic; the callback is factored out by the caller.
B) Add an optional `VoidCallback? onTogglePopOut` plus `bool isPoppedOut` to
   `CaptionDisplayWidget` directly.
C) Wrap `CaptionDisplayWidget` in a `Stack` at both call sites and overlay the button; the shared
   widget is not changed at all.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 7
UX-PIP-05's hint and return, UX-PIP-01's chrome toggle and UX-PIP-03/04's visibility rule: how
are the two toggles placed in each app's chrome, given Proto-15 shows neither?

A) Both apps put the chrome toggle in the app shell (`ZbAppShell` and `ZcAppShell`) as a header
   action on the recording/caption screen's `AppBar` (narrow layout) and as an icon button in the
   persistent rail header (wide layout); the in-surface toggle is passed into
   `CaptionDisplayWidget`. The hint is an inline banner above the caption surface.
B) Both apps put everything on the recording/caption screen only (no shell involvement): an
   `AppBar` action and a banner inside the screen body.
C) Zip Broadcast reuses the existing output-targets panel card for the chrome toggle and Zip
   Captions gets a header button; the hint goes into the existing status-pill row.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 8
How is "a session is active" defined for UX-PIP-03, and what does the disabled reason say
(BR-PIP-12/13)?

A) Active = `RecordingState` is `RecordingActiveState`, `PausedState` or `ReconnectingState`
   (idle/stopped are not); engine-unavailable = `sttEngineRegistryProvider` reports no registered
   engine at all. Disabled copy: "Start captioning to pop captions out" for no session and
   "No speech recognition engine is available on this device" for no engine, both from ARB.
B) Active = only `RecordingActiveState`; paused/reconnecting count as inactive.
C) Active = the caption buffer has at least one entry.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 9
What is the pop-out window's default size, minimum size, frame and chrome (UX-PIP-10 and §8.7's
"small always-on-top window the user positions" versus Unit 8's work-area frame)?

A) 640x320 at open, minimum 320x180, positioned centred on the display containing the main window's
   centre (fallback: primary), resizable and decorated normally (unlike the external display, which
   is borderless and work-area framed). Size/position are not persisted (BR-PIP-10's permitted
   but not required clause).
B) 640x320 at open, minimum 320x180, centred on the primary display, no persistence. The user
   positions it; the app never reframes it after open.
C) 640x320 at open, framed to the main window's screen work area like the external display, but
   with ordinary window chrome and resize enabled.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 10
BR-PIP-03/§8.8 item 16 ("closed by the OS close button leaves a coherent state") and BR-PIP-10
("must not reopen on next launch"): how is the restored state stored per app?

A) A new persisted boolean per app (`output.popOutEnabled` in `zip_broadcast`'s
   `OutputTargetSettings`; a `zip_captions` equivalent in its own settings), forced to `false` on
   load exactly as `overlayEnabled` is (Unit 8 D-6), so nothing reopens on launch. The OS-close
   path is the controller's existing `WindowClosed` event, which writes `false`.
B) No persistence at all: session state only, so a relaunch is trivially clean and the OS-close
   path only needs to reset in-memory state.
C) Persist it, and reopen on launch if it was open at quit.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 11
Which of §8.8's items does this unit actually claim, and how are the rest recorded?

A) Claim 1-7, 11-14, 16-18 as automated or platform checks where §8.8 says so; record 8-10 as
   deferred to Phase 8 (translation-dependent) and 15 (always-on-top) plus 12/13/16/17 as Unit 9
   manual checks, exactly as §8.8's "Automated versus manual" paragraph partitions them, with
   per-app evidence rows for 1-3, 5-7, 11, 14, 18 and Unit 9 rows for the rest.
B) Claim everything 1-7 and 11-18 now, with 8-10 deferred; push 15's manual verification into the
   unit's own `flutter build macos --debug` evidence.
C) Claim 1-7, 11-14, 16-18 and record 15 as unverifiable in Phase 2.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 12
Packages that currently import the machinery — what happens to `zip_broadcast`'s files after the
move?

A) The files are **deleted** from `zip_broadcast` and every import is rewritten to
   `package:zip_core/zip_core.dart` (or a new `package:zip_core/output/overlay.dart` barrel), with
   the app-local types `OverlayConfig`/`OverlayPosition` following Q3's answer. Nothing is left
   behind as a re-export shim except what Q3 requires for the public config types.
B) The files stay in `zip_broadcast` as one-line `export` shims over the `zip_core` originals, and
   only new code imports `zip_core` directly.
C) Copy the machinery into `zip_core` and leave `zip_broadcast`'s copy in place, unused by the pop-out.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

---

## Plan steps (checkboxes ticked as each completes)

- [x] Step 1: Analyze the Unit 8.1 definition, S-21, §8, the dependency record, and the shipped code
- [x] Step 2: Write this plan and its questions; verify the package fence facts against the shipped io/stub files
- [x] Step 3: Collect answers; resolve any ambiguity or contradiction with clarification questions
- [x] Step 4: Write `business-logic-model.md` (promotion inventory, the promoted state machine, the pop-out lifecycle, the toggle/availability model, the sub-engine startup order per app)
- [x] Step 5: Write `business-rules.md` (BR-PIP-01..12 restated against the promoted machinery plus the refactor-preservation rules)
- [x] Step 6: Write `domain-entities.md` (promoted types, `PopOutMode`, the codec's mode extension, the content-setting field, per-app setting keys)
- [x] Step 7: Write `frontend-components.md` (both toggles, the hint, the visibility matrix, both apps' placement)
- [x] Step 8: Write the PBT-01 "Testable Properties" section for the promoted code and the pop-out's new logic
- [x] Step 9: Write `handoff-summary.md` (Functional Design -> NFR Requirements)
- [ ] Step 10: Present for approval and stop (awaiting)

**Stage gates**: no production code is written in this stage. Every artifact lands under
`aidlc-docs/construction/pop-out/functional-design/`.