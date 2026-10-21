# Business Logic Model — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: Draft for approval.
**Scope**: The promotion of Unit 8's window machinery into `zip_core`, the pop-out's lifecycle, and
the exact per-app wiring. User-visible rules live in `business-rules.md`; types in
`domain-entities.md`; widget structure in `frontend-components.md`.

---

## 1. What the promotion actually moves

The unit definition calls the subject "the window controller and its state machine, the versioned
launch/snapshot codec, the sub-engine entry contract and the `window_manager` registration helper".
Read against the shipped code, that is 23 files, and the "ready handshake" is spread across three
layers. The inventory:

```
zip_broadcast/lib/src/output/overlay/
  overlay_window_controller.dart          -> zip_core  (state machine, T1-T17, resolveOpenDisplay)
  overlay_window_mode.dart                -> zip_core  (+ PopOutMode)
  caption_overlay_codec.dart              -> zip_core  (+ 'popOut' token, contentMode)
  caption_overlay_snapshot.dart           -> zip_core  (+ contentMode)
  overlay_activity.dart                   -> zip_core
  overlay_event.dart                      -> zip_core
  external_display_status.dart            -> zip_core  (name kept)
  desktop_window_service.dart             -> zip_core  (+ setBounds, setAlwaysOnTop)
  desktop_multi_window_service.dart       -> zip_core  (export)
  desktop_multi_window_service_io.dart    -> zip_core  (+ 2 methods, no new logic)
  desktop_multi_window_service_stub.dart  -> zip_core  (+ 2 throwing methods)
  overlay_window_bridge.dart              -> zip_core
  overlay_window_bridge_io.dart           -> zip_core
  overlay_window_bridge_stub.dart         -> zip_core
  overlay_window_entry.dart               -> zip_core  (+ alwaysOnTop, pop-out body)
  NOTE: overlay_window_app.dart is in lib/src/widgets/, not overlay/; it moves
        to zip_core/lib/src/widgets/overlay_window_app.dart because
        OverlayWindowEntry builds it (+ injected unavailable copy,
        shared _themeModeOf helper, no ARB dependency).
  display_enumerator.dart                 -> zip_core
  display_info.dart                       -> zip_core
  display_info.freezed.dart               -> zip_core  (regenerated at the new path)
  screen_retriever_display_enumerator.dart-> zip_core
  ..._io.dart                             -> zip_core
  ..._stub.dart                           -> zip_core
  caption_position.dart                   -> stays (external-display-only concept)
  caption_overlay_target.dart             -> stays (app bus adapter; imports updated)

zip_broadcast/lib/src/models/
  overlay_config.dart                     -> zip_core  (freezed; app file becomes a re-export)
  overlay_position.dart                   -> zip_core  (app file becomes a re-export)

new in zip_core:
  output/overlay/always_on_top_installer.dart / _io.dart / _stub.dart
  output/overlay/pop_out_geometry.dart
  output/overlay/overlay.dart              (barrel)
  widgets/pop_out_window_body.dart
```

**The re-export exception (Q3 A)**: `zip_broadcast/lib/src/models/overlay_config.dart` and
`overlay_position.dart` become
`export 'package:zip_core/src/output/overlay/overlay_config.dart';` (and the position equivalent).
`OverlayConfig`'s generated `part` file moves with it, so `overlay_config.freezed.dart` is deleted
from `zip_broadcast` and regenerated in `zip_core`. This is the one shim Q12 A allows: it keeps
`const OverlayConfig()` and `const OverlayPositionTop()` working at every existing call site
(including `x.overlayPosition.dart` test fixtures) without a 40-file import rewrite. It is a
one-line file with no logic and is deleted when its last consumer migrates.

**Why `ExternalDisplayStatus` keeps its name**: see `domain-entities.md` §1.1. The pop-out reuses
the same seven states; the pop-out-specific rendering is `PopOutMode` in the launch, plus the
`Failed` reason mapping below.

---

## 2. The promoted state machine (unchanged behaviour)

`OverlayWindowController`'s transitions are Unit 8's T1-T17 (in
`external-display/functional-design/business-logic-model.md`). They are **not** re-derived here and
**are not modified**. The pop-out inherits every one:

| Event | State change | Pop-out consequence |
|---|---|---|
| construct, platform capable | → `Off` after enumeration | toggle renders (enabled per §3.1 of `domain-entities.md`) |
| construct, platform incapable | → `Unsupported` | toggle not rendered |
| `open()` | → `Opening`, 10 s ready timer | toggle reads "Exit Picture in Picture" |
| `overlayReady` | `setFrame`/`setBounds` + `show` → `Open(activity)` | window visible; always-on-top already applied (3.2) |
| ready timeout | → `Failed(ready_timeout)`, `OpenFailed` | shell clears `popOutEnabled`, banner shows |
| `createWindow` throws | → `Failed(create_failed)`, `OpenFailed` | same |
| `close(toggleOff)` | → `Off` | shell clears `popOutEnabled` |
| window `'-1'` while `Open` | → `Off`, `WindowClosed` | shell clears `popOutEnabled` (BR-PIP-03) |
| `close(dispose)` | → `Off` (or keeps `Failed`) | app shutdown |
| display change while `Open` | re-frames to the display's bounds (T15) | **not applicable**: the pop-out is not framed to the display's work area and does not follow displays (3.4) |
| display lost while `Open` | → `WaitingForDisplay` | **not applicable**: same reason |

**Mode-conditional behaviour, the only additions to the machinery.** Two table rows above are
external-display-only. Rather than a new state, the controller gains one private predicate,
`bool get _isPopOut => _mode is PopOutMode;` and:

- `_onDisplaysChanged`'s `Open` branch: for `PopOutMode`, **skip** the `T15` re-frame and the `T10`
  display-lost transition. A pop-out on a display that disappears is repositioned by the OS, not
  closed: closing it would end the user's pop-out because they unplugged a monitor.
- `_runReady`: for `PopOutMode`, frame with the computed geometry (`setBounds` + `center`) rather
  than the display work area (`setFrame`).
- `_runOpen` with a `PopOutMode` config: skip `resolveOpenDisplay` and the
  `WaitingForDisplay`-for-a-saved-display path entirely (no persisted selection exists).
- `open()`'s `persistedDisplayId` parameter is ignored for `PopOutMode` (documented, not an error).

These are the **only** behaviour differences, and each is a guard on a single branch. Unit 8's
external-display branches keep their exact code and tests.

---

## 3. Pop-out lifecycle (main engine)

```
            toggle pressed
                 |
                 v
   _popOutEnabled = true            (shell, in-memory; Q10 B)
   registry.add(_popOutTarget)      (so the first snapshot has the buffer)
   target.show(OverlayConfig(mode: PopOutMode()))
                 |
                 v
   controller.open() --- unsupported/off/opening/open -> no-op (BR-PIP-02)
                 |
                 v
   computePopOutFrame(displays, mainWindowCentre, settings, textTheme, textScaler)
   createWindow(encodeLaunch(launch))
                 |
     [sub-engine starts]  (3.2)
                 |
   overlayReady -----> setBounds(frame) ; show() ; Open
                 |
   caption events -> snapshot -> 16 ms coalesced captionUpdate
```

Toggle off: `_popOutEnabled = false`; `registry.remove(target)`; `target.hide()` →
`close(toggleOff)` → window closed. Main window re-registers nothing.

**Why register before showing**: identical to `CaptionOverlayTarget`'s shipped ordering — the
launch's first frame must already contain the live buffer, not an empty one.

**Why in-memory**: Q10 B. There is no settings write on any pop-out path, so BR-PIP-03's coherent
state is a pure function of the controller's status plus the shell's boolean.

### 3.1 Recognition continuity

`PopOutCaptionTarget.onCaptionEvent` folds `SessionStateEvent` into `OverlayActivity` (same mapping
as `CaptionOverlayTarget._activityFor`) and pushes a snapshot. It never calls into
`RecordingStateNotifier`. Adding/removing it is a registry change only.

### 3.2 Pop-out sub-engine startup sequence

The order is the contract (BR-U8.1-05, BR-U8.1-06, BR-PIP-11):

```
1  WidgetsFlutterBinding.ensureInitialized()        (from main)
2  isOverlayWindowLaunch(args) -> true
3  decodeLaunch(args[2])
4  if decode fails: pump OverlayWindowUnavailableApp, return   (never signals ready)
5  GoogleFonts.config.allowRuntimeFetching = false
6  await alwaysOnTop.install()          <-- window_manager's own engine's window
7  install bridge handler
8  pump ProviderScope(OverlayWindowEntry(launch, bridge, alwaysOnTop: null))
9  OverlayWindowEntry.initState: send('overlayReady')
```

Steps 6 and 7 both precede step 9, so (a) the window is already topmost and resizable when it is
shown, and (b) the first `captionUpdate` always finds a handler.

`alwaysOnTop.install()` failing is caught inside the installer: the window still opens, the user
simply may not get always-on-top, and a fixed string is logged. It must **not** prevent ready,
because a failed cosmetic call must not turn a working pop-out into an `OpenFailed`.

### 3.3 The in-surface toggle from the pop-out window

§8.3 UX-PIP-02 requires the in-surface toggle to work **from the pop-out window itself**. The
pop-out's engine has a bridge to window `0` and nothing else. The toggle therefore sends a new
method over the existing bridge:

- sub-engine → `bridge.sendToggle()` → `DesktopMultiWindow.invokeMethod(0, 'popOutToggle', null)`.
- main engine's shared handler → `popOutToggle` → the shell's `_togglePopOut()` (same code path as
  the chrome toggle), and the window closes through the normal `close(toggleOff)` +
  `WindowClosed`/window-teardown path.

`OverlayWindowBridge` gains `void sendPopOutToggle();` (implemented in `_io`, no-op in `_stub`),
and the controller's `_handleWindowCall` gains one case, `'popOutToggle'`, which emits a
`PopOutToggled` `OverlayEvent` that the shell listens for. The controller does not toggle itself:
the toggle decision belongs to the shell (it owns `popOutEnabled`), the same separation Unit 8
uses for `WindowClosed` (controller reports, shell decides).

**Security**: the message carries no payload and is only accepted from the current window id, using
the existing stale-window guard. Nothing about caption text crosses this direction.

### 3.4 Framing (Q9 amended)

`computePopOutFrame` is a pure top-level function in `pop_out_geometry.dart`:

```
({Rect frame, String? displayId}) computePopOutFrame({
  required List<DisplayInfo> displays,
  required Offset? mainWindowCentre,     // null -> fall back to primary
  required DisplaySettings settings,
  required TextTheme textTheme,
  required double textScaler,
})
```

1. Pick the display whose `bounds.contains(mainWindowCentre)`; else the `isPrimary`; else the
   first; else return `(Rect.zero, null)` meaning "no display known, let the platform place it".
2. `size = popOutSize(settings, textTheme, textScaler)` (see `domain-entities.md` §3.3), clamped to
   the display work area.
3. `frame.left = workArea.center.dx - size.width / 2`;
   `frame.top  = workArea.bottom - size.height`.
4. Clamp `left`/`top` inside the work area so a tiny display cannot push the window off-screen.

The window is not reframed later (3.0's table). `mainWindowCentre` comes from the enumerator's
`displayListProvider` plus the main window's own size: the main engine reads
`View.of(context)` — but because the shell is a widget, the simplest honest source is
`MediaQuery.sizeOf(context)` and the platform's primary display, so:

- If the app already knows the window's position (it does not today), use it.
- Otherwise, use the primary display's work area as the anchor **and** expose the anchor as a
  parameter so a later unit can pass a real window centre without changing this function.

**Recorded limitation**: without main-window geometry the pop-out opens bottom-centre of the
primary display. This is a deliberate simplification, not a claim of "on the window's display"; the
function takes the centre so it can be improved without redesign. Unit 9's manual check records
where it actually appears per platform.

---

## 4. Cross-cutting mechanics

### 4.1 The shared method-handler dispatcher (BR-U8.1-04, BR-PIP-01)

`DesktopMultiWindow.setMethodHandler` is one static slot. Two controllers (external display and
pop-out) in one engine need both handlers. The promoted `overlayMethodHandlerInstaller` cannot be
passed to both, because the second call replaces the first.

Resolution, in `zip_core`:

```
class OverlayMethodRouter {
  void register(OverlayMethodHandler handler) -> token
  void unregister(token)
  OverlayMethodHandlerInstaller get installer   // wraps the static slot
}
```

- Constructed once per engine (in the provider in the main engine; not at all in the sub-engine).
- `register` increments a count; the first registration calls the static installer with the
  router's dispatch function; the last unregistration calls it with `null`.
- Dispatch tries each registered handler in registration order and stops after the first one that
  recognises the method (the controller's existing stale-window guard already ignores unknown
  window ids; the `'overlayReady'`/`'captionUpdate'` handlers are per-window-id, so only one
  controller matches).
- Each controller receives `router.installer` as its `handlerInstaller`, so Unit 8's fail-closed
  `null` check still holds (it is never null in production).
- Alternative rejected: a `null` installer for the second controller. It would fail every pop-out
  open closed with `create_failed` — correct-looking and completely wrong.

**The main engine's two controllers**: `overlayWindowControllerProvider` keeps its name and now
also owns the router plus a second, `popOutWindowControllerProvider`-shaped constructor argument
list. Both share the enumerator (one platform observer) and the router, and both are disposed with
the container.

### 4.2 Coalescing and the ready handshake

Unchanged (Unit 8's P1/R3). The pop-out benefits from the same 16 ms cadence and the same held
snapshot on ready.

### 4.3 Own-window settings (BR-U8.1-05)

`AlwaysOnTopInstaller.install()` runs in the sub-engine. `window_manager` binds `windowManager` to
"the main window of this engine", which is the pop-out engine's only window, so no window id is
needed and none is passed. `setResizable(true)` and `setMinimumSize` are applied there because they
are window properties the plugin owns and `desktop_multi_window` cannot express.

### 4.4 The `zip_captions` main-entry routing (BR-U8.1-06)

`zip_captions/lib/main.dart` today is `void main() async` with no args. It becomes:

```
Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (isOverlayWindowLaunch(args)) {
    await overlayWindowMain(args);
    return;
  }
  ... existing body unchanged ...
}
```

The three runners already pass argv through to Dart on every platform (macOS via the plugin's
engine creation, Windows/Linux via `dart_entrypoint_arguments`), which Infrastructure Design
verifies requirement-by-requirement.

---

## 5. Where each piece lives (both apps)

| Concern | `zip_broadcast` | `zip_captions` |
|---|---|---|
| Controller ownership | existing provider, extended with the router + a second controller | new provider file, same shape |
| Pop-out target | `PopOutCaptionTarget` next to `CaptionOverlayTarget` | new `PopOutCaptionTarget` |
| Toggle state | shell field `_popOutEnabled` (in-memory) | `popOutNotifierProvider` (in-memory `Notifier<bool>`) |
| Chrome toggle placement | `ZbAppShell` header action | `ZcAppShell` header action |
| Hint | `PopOutBanner` above the caption surface in `RecordingScreen` | same in `RecordingScreen` |
| In-surface toggle | `RecordingScreen` passes `controls:` | `RecordingScreen` passes `controls:` |
| Copy | `l10n/arb/app_en.arb` | `l10n/arb/app_en.arb` + `ZcStrings` |
| Sub-engine entry | existing `main(List<String> args)` | new `main(List<String> args)` |
| Runner registration | existing callbacks gain `window_manager` registration | callbacks added |

`zip_captions` uses a notifier rather than a shell field because its shell is stateless and its
screens are the toggles' siblings; `zip_broadcast` uses a shell field because its shell already
owns the overlay target and the registry, so putting the pop-out anywhere else would create a
second owner of output-target registration.

---

## 6. Failure paths

| Failure | Result |
|---|---|
| Platform unsupported | control hidden; `open()` no-ops; nothing logged |
| No engine registered, session idle | control disabled with reason; no window call |
| `createWindow` throws | `Failed(create_failed)`, `OpenFailed`; shell clears flag; banner |
| ready never arrives (10 s) | `Failed(ready_timeout)`; shell clears flag; banner |
| `setBounds`/`show` throws non-`'-1'` | logged fixed string, ignored (Unit 8 R4) |
| window disappears (`'-1'` while `Open`) | `WindowClosed`; shell clears flag (OS-close path) |
| `window_manager` install throws | fixed-string warning; window still opens (3.2) |
| codec decode fails in sub-engine | unavailable frame; never signals ready; main engine times out |
| `popOutToggle` arrives from a stale window | ignored by the existing window-id guard |
| decode of a `captionUpdate` fails | dropped, last frame stays (unit 8 behaviour) |

No path logs caption text. No path leaves a window registered without a state that explains it.

---

## 7. Tests: move, shape, and the two freedom points

**Move unchanged (import-path change only)** — these must pass verbatim in `zip_core`:

`caption_overlay_codec_test`, `caption_overlay_codec_properties_test`, `display_enumerator_contract_test`,
`display_info_test`, `display_state_machine_properties_test`, `external_display_status_test`,
`overlay_window_controller_test`, `overlay_window_entry_test`, `resolve_open_display_test`,
`resolve_open_display_properties_test`, `to_platform_frame_test`, `to_platform_frame_properties_test`,
`desktop_window_service_io_test`, plus `helpers/{fake_display_enumerator, generators, pbt}`.

**Move with a documented shape change** — exactly these, and nothing else:

1. `overlay_window_entry_test`'s two `overlayWindowMain` tests reference the app's ARB string
   `'Window unavailable'`. In `zip_core` there is no ARB, so `OverlayWindowUnavailableApp` takes the
   copy as a `required String message` (or `OverlayWindowLabels`) and the test asserts on the
   injected string. This is a required decoupling, not a weakening: the assertion still proves the
   frame renders and ready is never sent.
2. `test/output/caption_overlay_target_test.dart` and `test/widgets/overlay_window_app_test.dart`
   stay in `zip_broadcast` and only have import paths updated (the target is app-level). If
   `OverlayWindowApp` moves to `zip_core` (it must, since `OverlayWindowEntry` builds it), its test
   moves too and its `'Window unavailable'`-style assertions take the injected copy.
3. `helpers/mock_desktop_window_service.dart` gains mocktail stubs for the two new interface
   methods; no assertion changes.
4. `helpers/generators.dart`'s overlay generators move to `zip_core/test/helpers/generators.dart`
   (appending to the existing file), and `zip_broadcast` imports them from... **nothing**: an
   app cannot import another package's `test/` directory. So the overlay generators are duplicated
   into `zip_core/test/helpers/overlay_generators.dart`, and `zip_broadcast`'s copy shrinks to the
   generators its own tests still need. This is the one unavoidable test-helper duplication; it is
   test code, has no production cost, and both copies are covered by their own package's suite.

**New tests** (list finalised in Code Generation Part 1): pop-out mode/codec, geometry, router,
always-on-top installer fake, pop-out window body, both apps' toggles/banners/availability matrix,
redaction audits, and the `zip_captions` main-entry routing.

**Freedom points**: (1) a test may only be re-shaped for the four reasons above; (2) if a test
fails after the move and the cause is not one of those four, the work stops and the failure is
reported — not patched into the test.