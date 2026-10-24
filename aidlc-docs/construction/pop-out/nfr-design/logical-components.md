# Logical Components — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (answers recorded in
`plans/pop-out-nfr-design-questions.md`; `dispose()` re-specified unchanged in review round 2).
**Branch**: `feature/popout-live-captions`
**Companion artifact**: `nfr-design-patterns.md` (the why, by NFR domain). This file is the what and
the where.
**Placement rule**: everything except per-app UI and per-runner native code lives in `zip_core`,
behind the existing `_io`/`_stub` conditional-export fence (FD Q2 A, BR-U8.1-02).

---

## 1. Component inventory

`NEW` = does not exist anywhere today. `MOVED` = Unit 8 code relocated from `zip_broadcast` with
import-path changes only. `CHANGED` = moved and carrying one of the FD's additive changes.

| Component | Kind | Package / path | Status |
|---|---|---|---|
| `OverlayMethodRouter` + `OverlayHandlerToken` | class | `zip_core/lib/src/output/overlay/overlay_method_router.dart` | **NEW** |
| `OverlayWindowHost` + `overlayWindowHost` | class + keepAlive provider | `zip_core/lib/src/output/overlay/overlay_window_host.dart`, `.../providers/overlay_window_host_provider.dart` | **NEW** |
| `DisplayEnumeratorLease` | class | `zip_core/lib/src/output/overlay/display_enumerator_lease.dart` | **NEW** |
| `SubWindowClosedChannel` (+ `_io` / `_stub`) | class, conditional export | `zip_core/lib/src/output/overlay/sub_window_closed_channel.dart`, `_io.dart`, `_stub.dart` | **NEW** |
| `WindowConfigurator` (+ `_io` / `_stub`) | class, conditional export | `zip_core/lib/src/output/overlay/window_configurator.dart`, `_io.dart`, `_stub.dart` | **NEW** |
| `OverlayWindowConfig` | `freezed` value | `zip_core/lib/src/models/overlay_window_config.dart` | **NEW** |
| `PopOutMode` | `final class`, sibling of `ExternalDisplayMode` | `zip_core/lib/src/output/overlay/overlay_window_mode.dart` | **NEW** |
| `PopOutContentMode` | `enum` | `zip_core/lib/src/output/overlay/caption_overlay_snapshot.dart` | **NEW** |
| `PopOutGeometry`, `popOutSize`, `chromeAllowance`, the chrome constants | `const` holder + pure functions | `zip_core/lib/src/output/overlay/pop_out_geometry.dart` | **NEW** |
| `computePopOutFrame` | pure top-level function | same file | **NEW** |
| `popOutAvailability` | pure top-level function | `zip_core/lib/src/output/overlay/pop_out_availability.dart` | **NEW** |
| `PopOutWindowBody` | `StatelessWidget` | `zip_core/lib/src/widgets/pop_out_window_body.dart` | **NEW** |
| `OnScreenCaptionSource` | not used — see §6 | — | **REJECTED (L4 B)** |
| `OverlayWindowController` | class | `zip_core/lib/src/output/overlay/overlay_window_controller.dart` | **CHANGED** (7 deviations) |
| `CaptionOverlayCodec` | class | same directory | **MOVED**, mode token added |
| `DesktopWindowService`, `DesktopMultiWindowService`, `toPlatformFrame` | class + seam | same directory | **MOVED** |
| `ScreenRetrieverDisplayEnumerator`, `DisplayEnumerator`, `DisplayInfo` | classes | same directory | **MOVED** |
| `ExternalDisplayStatus`, `OverlayActivity`, `OverlayEvent`, `CaptionPosition`, `OverlayWindowBridge` | types | same directory | **MOVED** |
| `OverlayWindowEntry`, `overlayWindowMain`, `isOverlayWindowLaunch` | functions/class | same directory | **CHANGED** (configurator, `popOutHost`) |
| `OverlayWindowUnavailableApp` | widget | `zip_core/lib/src/widgets/` | **CHANGED** (`required String message`) |
| `OverlayWindowApp` | widget | `zip_core/lib/src/widgets/` | **CHANGED** (injected copy) |
| `CaptionDisplayWidget` | widget | `zip_core/lib/src/widgets/caption_display_widget.dart` | **CHANGED** (`Widget? controls`) |
| `overlay.dart` | library barrel | `zip_core/lib/overlay.dart` | **NEW** |
| `PopOutCaptionTarget` | class | `zip_broadcast/lib/src/output/overlay/`, and `zip_captions/lib/src/output/overlay/` | **NEW** (per app) |
| `PopOutControls`, `PopOutBanner` | widgets | each app's `lib/src/widgets/` | **NEW** (per app) |
| `popOutNotifierProvider` | keepAlive `Notifier<bool>` | `zip_captions/lib/src/providers/` | **NEW** |
| `broadcastEngineAvailableProvider`, `captionsEngineAvailableProvider` | providers | each app's `lib/src/providers/` | **NEW** |
| `runZipCaptions(args, {runApp, isWeb})` | function | `zip_captions/lib/src/bootstrap.dart` | **NEW** |
| `_popOutEnabled`, `_popOutTarget`, `_onPopOutEvent`, `_syncPopOut`, `_togglePopOut` | shell members | `zip_broadcast/lib/src/shell/zb_app_shell.dart` | **NEW members** |
| `ZcAppShell` | widget | `zip_captions/lib/src/shell/` | **CHANGED** (stateful; see §6 deviation) |
| Runner `configure` + close handlers | native | 6 runners (2 apps x 3 platforms) | **NEW** |

---

## 2. The host: one owner for the three engine-wide resources

```
overlayWindowHost  (@Riverpod(keepAlive: true), zip_core)
└── OverlayWindowHost
    ├── OverlayMethodRouter        one static handler slot (DesktopMultiWindow.setMethodHandler)
    ├── ScreenRetrieverDisplayEnumerator   one platform observer
    ├── SubWindowClosedChannel     one main-engine MethodChannel
    └── dispose()                  called from ref.onDispose(host.dispose)

OverlayWindowController createController({
  required OverlayWindowMode mode,
  required String prefix,          // Logger name -> 'zip_core.<caller>'
})
  -> windowService : DesktopMultiWindowService.withEnumerator(lease)
  -> enumerator    : DisplayEnumeratorLease (reference-counted over the host's one instance)
  -> handlerInstaller : router.installerFor(token)   (token bound to this controller)
  -> closeChannel  : the host's            (controller subscribes in _bootstrap)
```

`DisplayEnumeratorLease` (in `zip_core/lib/src/output/overlay/display_enumerator_lease.dart`):

```
class DisplayEnumeratorLease implements DisplayEnumerator {
  Future<List<DisplayInfo>> displays() => _shared.displays();        // delegate
  Stream<List<DisplayInfo>> get changes => _shared.changes;          // delegate
  Future<Size?> primarySize() => _shared.primarySize();              // delegate
  Future<void> dispose();   // release this share; last release (or host.dispose) disposes _shared
}
```

The lease is what lets the controller keep calling `_enumerator.dispose()` at `:702` and keeping its
`isDisposed` observable, while the host stays the only owner of the platform observer (FD BR-PIP-01,
NFR-R §3.2). Full rationale and the lease tests are in §3.

**Dependency direction**: host -> (router, enumerator, channel); controller -> host-supplied
collaborators; apps -> host. Nothing in `zip_core` imports an app. The host imports no plugin: the
enumerator's `_io` file does, and the channel/configurator `_io` files do
(`package:flutter/services.dart` only).

**Why the host also owns the channel (D1 B, corrected)**: there is no startup gap — only a
controller creates a window, and each controller subscribes in `_bootstrap` before it can call
`open()`. Putting the channel where the router and enumerator already live means one
`ref.onDispose`, no eager read in `main`, nothing added to the overlay-launch branch of `main`, and
no `ProviderContainer` lookup inside a native callback.

**App-side shapes** (names preserved so dependents survive):

```
zip_broadcast: overlayWindowControllerProvider   -> host.createController(mode: ExternalDisplayMode(), prefix: 'zip_broadcast.OverlayWindowController')
               popOutWindowControllerProvider    -> host.createController(mode: PopOutMode(), prefix: 'zip_broadcast.PopOutWindowController')
               displayList                       -> host.displays        (was controller.enumerator.changes)
zip_captions:  overlayWindowControllerProvider   -> as broadcast
               popOutWindowControllerProvider    -> as broadcast
```

Both controller providers keep `ref.onDispose(controller.dispose)`; the host owns the rest.

---

## 3. Controller surface after the move

Unchanged, plus exactly the seven permitted deviations (BR-U8.1-01, FD BLM §4.1):

| # | Deviation | Call sites that make it necessary |
|---|---|---|
| 1 | Six `_isPopOut` guards | `_onDisplaysChanged` (T15 + display-lost), `_runReady`, `open()`, `_runOpen`, `_bootstrap`'s capability rule |
| 2 | `'popOutToggle'` case in `_handleWindowCall` | emits `PopOutToggled`; the shell decides |
| 3 | `open({Rect? frame})` | shell-computed frame (R-M5) |
| 4 | Mode fixed at construction | `createController(mode:)`; `open()` validates the config's mode |
| 5 | Token-bound installer | `router.installerFor(token)`; `dispose()`'s `call(null)` removes only itself |
| 6 | `int? get windowId` | `router.register(windowIdOf: () => controller.windowId, …)` |
| 7 | `void onNativeWindowClosed(int)` | the channel subscription in `_bootstrap` |

**`dispose()` is byte-for-byte unchanged, and the moved `dispose` tests pass verbatim.** This is a
correction (2026-10-21, review round 2): an earlier draft of this section said `dispose()` must stop
disposing the enumerator and stop nulling the method-handler slot. That was wrong against the moved
suite — `overlay_window_controller_test.dart:721-749` asserts
`harness.enumerator.isDisposed` is `true` after controller dispose (`:736` and `:749`), so a
`dispose()` that stopped disposing would fail for a reason outside BR-U8.1-01's five, and the build
would stop (correctly).

Two mechanisms keep `dispose()` literally unchanged:

1. **The enumerator is handed over as a reference-counted lease.** `OverlayWindowHost` gives each
   controller a `DisplayEnumeratorLease` over the one `ScreenRetrieverDisplayEnumerator` — the
   enumerator's counterpart to the handler's installer token, so both shared collaborators are
   reached through a per-controller handle:
   - `displays()`, `changes` and `primarySize()` all **delegate to the shared instance**;
   - `dispose()` **releases that controller's share**;
   - the real enumerator is disposed by the **last release** or by `host.dispose()`, whichever comes
     first;
   - `dispose()` is **idempotent** (a second release is a no-op);
   - the controller's `await _enumerator.dispose()` (`:702`) and its `isDisposed` observation are
     both satisfied by the lease, so no controller code changes.
   The moved test needs no change: `_Harness` passes one `FakeDisplayEnumerator` straight to the
   controller (`overlay_window_controller_test.dart:126-143`), so `harness.enumerator.isDisposed` at
   `:736`/`:749` keeps observing exactly the object the controller destroyed — in production that
   object is the lease, and the assertion still means "this controller released".
2. **`:708`'s `_handlerInstaller?.call(null)` already routes through `router.installerFor(token)`,
   which maps `null` to `unregister(token)`.** No code change at the call site; the lease and the
   token are two instances of one pattern, not two new behaviours.

Allowed deviation table entry **5** above is therefore accurate as written: `installerFor(token)`
maps `null` to unregister, which is exactly what `dispose()` means by passing `null`.

**Lease tests (added to this design's test obligations):** the last release disposes the shared
enumerator; an earlier release does not; a double release is a no-op; `host.dispose()` disposes the
enumerator regardless of outstanding leases and is idempotent with a later last-release.

---

## 4. The router, precisely

```
class OverlayHandlerToken { /* opaque, identity only */ }

class OverlayMethodRouter {
  OverlayHandlerToken register(
    int? Function() windowIdOf,
    OverlayMethodHandler handler,
  );
  void unregister(OverlayHandlerToken token);          // duplicate = no-op
  OverlayMethodHandlerInstaller installerFor(OverlayHandlerToken token);
  void dispose();                                      // clears the static slot
}
```

Dispatch, in registration order, and only on an exact non-null id match:

```
if (windowIdOf() == null || windowIdOf() != fromWindowId) continue;
await handler(call, fromWindowId);
return;                       // exactly one handler, never zero after a match
```

- the handler's return type is `Future<void>`, so there is no "recognised" verdict to consult
  (R-M3); the id *is* the address;
- a message whose id matches nothing is dropped with a fixed-string `FINE` log;
- first register installs `DesktopMultiWindow.setMethodHandler(dispatch)`; the last unregister
  clears it with `null`; `dispose()` clears it unconditionally (the container is going away);
- **the token-bound installer** is `(handler) { handler == null ? unregister(token) : reRegisterFor(token, handler); }`
  — it accepts `null` because Unit 8's `dispose()` calls it that way, and it maps `null` to
  "unregister me", which is exactly what the controller meant.

Tested at two layers, per NFR-R §10.4: unit-level routing (each id reaches its own handler,
unregister-one leaves the other, first-installs/last-clears, duplicate unregister is a no-op) and two
real controllers sharing one real router through the host, with the negative assertions (an
unmatched id is seen by **neither** service).

---

## 5. The two native boundaries

### 5.1 `zip_core/overlay_window_configure` — Dart (sub-engine) -> native

```
Dart (zip_core, WindowConfigurator._io):
  MethodChannel('zip_core/overlay_window_configure')
    .invokeMethod<void>('configure', {
      'windowId': int, 'floating': bool, 'decorated': bool,
      'minWidth': double, 'minHeight': double,
    })
    caught: fixed-string FINE log, never throws

Native (per runner, inside the existing window-created callback):
  register FlutterMethodChannel('zip_core/overlay_window_configure', controller.registrar(forPlugin: …))
    case 'configure':
      validate allowlist-by-type (§3.1 of the patterns file); on rejection ->
        FlutterError('configure_invalid')
      apply: macOS NSWindow.level/styleMask/contentMinSize on controller.view.window
             Windows SetWindowPos(HWND_TOPMOST), GWL_STYLE bits, WM_GETMINMAXINFO
             Linux gtk_window_set_keep_above/set_decorated, gtk_widget_set_size_request
      result(nil)
```

One name for both apps; the runner is the implementation, the contract is `zip_core`'s. The
`windowId` argument is used **only** as the close event's tag (L1 = A): the native side styles the
window whose view created the callback, because that is the only window it can address. A mismatch
is not checked, and the patterns file explains why a check would be theatre.

### 5.2 `zip_core/overlay_sub_window_events` — native -> Dart (main engine)

```
Native (per runner, main-window setup):
  main messenger -> FlutterMethodChannel('zip_core/overlay_sub_window_events')
  on the sub-window's close path:
     emit 'subWindowClosed', {'windowId': <from the configure call>}

Dart (zip_core, SubWindowClosedChannel._io):
  install(): setMethodCallHandler
    method != 'subWindowClosed'         -> return null (drop, no log)
    args is! Map / windowId is! int / < 0 -> return null (drop, no log)
    else controller fan-out -> onClosed(windowId)
  Stream<int> get closed  (broadcast, arrival order)
  dispose()
_stub: install() no-op, closed = const Stream<int>.empty(), dispose() no-op
```

The id is the one the sub-engine sent in `configure`, because the native callback cannot know it
(FD BLM §3.2). The main engine therefore learns the id from our own Dart code, not from the plugin —
which is why the `configure` call must precede ready.

---

## 6. Deviations and rejections recorded at this stage

| Item | Decision | Why |
|---|---|---|
| `OnScreenCaptionSource` (L4 A) | **Rejected** | `CaptionOutputTargetRegistry` exposes `add`/`remove`/`activeTargets`/`dispose` only — no membership signal (`caption_output_target_registry.dart:16-66`) — so a cached source needs a change to the shared registry, which BR-U8.1-01 keeps unchanged; and extracting it rewrites the shipped `CaptionOverlayTarget`, which BR-U8.1-01 limits to import changes. Each `PopOutCaptionTarget` copies the shipped read (`caption_overlay_target.dart:94-102`). |
| Per-app channel names (L5 A) | **Replaced by Other** | One name per contract, `zip_core/overlay_window_configure` and `zip_core/overlay_sub_window_events`. The apps never share a messenger, so per-app names add plumbing and prevent no collision. |
| An eighth controller deviation | **Not needed** | Everything the answers require rides deviations 1-7 or lives in a new object (the host, the channel, the configurator). If Code Generation needs one, stop and report (BR-U8.1-01). |
| `ZcAppShell` framing (FD §2.2) | **FD row needs a correction** | The row says the shell becomes stateful "to own the one target and the in-memory flag". Only the first half is true: the flag lives in `popOutNotifierProvider`; the shell is stateful because it owns the target and the events subscription. Recorded for correction before Code Generation; not edited in this session (the FD is approved). |
| Frame fallback (P1) | **Kept, re-justified** | No moved test opens a pop-out controller (the earlier justification is withdrawn). The fallback exists so a non-shell caller does not fail an already-visible window, and logs one fixed string at `FINE`. |

---

## 7. Resource lifetimes

| Resource | Created | Released | If release fails |
|---|---|---|---|
| `OverlayWindowHost` | first `ref.watch(overlayWindowHostProvider)` | `ref.onDispose(host.dispose)` | container teardown; logged `INFO` + `runtimeType` |
| Router slot | first `register` | last `unregister`, or `host.dispose` | logged `INFO`; the engine is going away |
| Enumerator observer (the one shared instance) | host construction (`_io` file) | last `DisplayEnumeratorLease.dispose()`, or `host.dispose`, whichever is first; idempotent | `host` logs `INFO`; one observer per engine is still the invariant |
| Each controller's enumerator lease | `createController` | that controller's `dispose()` (`:702`, unchanged) | logged `INFO`; the shared instance is released by the last remaining share |
| `SubWindowClosedChannel` handler | host construction | `host.dispose` | `install()` failure degrades to "no stream" (§3.4 of patterns); `'-1'` covers |
| Controller channel subscription | `_bootstrap` | `controller.dispose` | `cancel()` unawaited, logged `INFO` |
| Ready timer, update timer | `open()` / first snapshot | `_setState` + `_release` (Unit 8) | unchanged |
| `PopOutCaptionTarget` registration | app shell toggle-on | shell toggle-off and shell `dispose` | registry `remove` is a no-op if already gone |
| App `events` subscription | app shell `initState` | app shell `dispose` | shipped pattern (`zb_app_shell.dart:75`) |
| Pop-out window + sub-engine | `createWindow` | `close`/OS close → native teardown | `'-1'` + channel + ready timeout bound the damage |

**Ordering rule carried from Unit 8** and now load-bearing across two controllers: a controller
releases its subscription first, then the host releases the shared objects, because the host may be
disposed before, after, or without its controllers in a test. The lease makes that ordering safe in
either direction: `host.dispose()` disposes the shared instance immediately (any later lease release
is a no-op), while a controller disposing first only drops its own share.

---

## 8. State-to-pattern map (T1-T17 unchanged; the pop-out columns)

`OverlayWindowController`'s transitions are Unit 8's T1-T17, unmodified. The two mode-conditional
rows are external-display-only, and each is one guard:

| Unit 8 row | `ExternalDisplayMode` | `PopOutMode` | Guard site |
|---|---|---|---|
| T15 (display event while `Open`) | re-frame to the display's work area | skipped; the window keeps its frame | `_onDisplaysChanged`, `Open` branch |
| T10 (display lost while `Open`) | `_release` → `WaitingForDisplay` | skipped; the OS repositions the window | `_handleDisplayLost` |
| T8 preconditions (`open`/`_runOpen`) | `resolveOpenDisplay`; `NoDisplays` on empty | no resolution; never `NoDisplays` | `open()`, `_runOpen` |
| T7 (`_runReady`) | frame = display work area | frame = the shell's `frame` | `_runReady` |
| T1 (bootstrap) | `isSupported` only | `isSupported` only (no display required) | `_bootstrap` |
| T3/T14 (window gone) | `'-1'` and/or channel | `'-1'` and/or channel | `_windowCall`, `onNativeWindowClosed` |

`POP-5` (PBT-06) drives exactly these, plus `openPopOut`/`toggleAgain`/`toggleOff`/`windowGone`, and
asserts at most one window, one state, and no second `createWindow` while `Opening`/`Open`.

---

## 9. Test seams this design creates (for Code Generation's plan)

| Seam | Shape | Why |
|---|---|---|
| `FakeSubWindowClosedChannel` | `StreamController<int>.broadcast()` + recorded `install`/`dispose` | lets a controller test push a close for any id, including unknown and late ones |
| `FakeWindowConfigurator` | records `(windowId, config)` into a shared ordering log; can be told to throw | ordering before ready and the throwing-still-ready case (NFR-R §1.2) |
| `FakeOverlayMethodHandlerInstaller` | records install/uninstall; exposes the installed handler | already the Unit 8 shape |
| `overlayWindowHostProvider.overrideWith` | a host built on fakes | lets both controllers share one real router in the two-controller test |
| `host.displays` in tests | fake enumerator's broadcast | app-level display watchers |
| `DisplayEnumeratorLease` over a fake | real lease, fake shared instance | the four lease tests (last release / earlier / double / host-first); the moved `_Harness` keeps its single fake because it passes it directly |

The in-tree PBT shim, `fake_async`, `mocktail` and hand-written fakes only — **no new dev
dependency** (NFR-R §1.4, tech-stack §4).