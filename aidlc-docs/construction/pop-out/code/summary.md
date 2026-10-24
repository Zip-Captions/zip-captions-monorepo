# Unit 8.1 — Pop-out Live Captions (S-21): Code Generation Summary

**Status**: Code Generation complete on branch `feature/popout-live-captions`
(2026-10-22/23, unattended run — approved by the run configuration per
`.agent/overnight-pipeline.md`, subject to morning review). No push.

**Plan executed**: `aidlc-docs/construction/plans/pop-out-code-generation-plan.md`,
steps 1-30. Commits, in order:

| Step | Commit | Scope |
|---|---|---|
| 1-10 | `416ed5f` … `f62de72` | the contracts in `zip_core` (deps, config, generators, router, lease, close channel, configurator, geometry, availability, barrel) |
| 11 | `465cad7` | the promotion: 23 production + 13 test files + helper into `zip_core` (BR-U8.1-01) |
| 12-13 | inside `465cad7` | the five permitted shape changes and the seven controller deviations |
| 11-18 | `d1cf311` | `zip_broadcast` reads the machinery from `zip_core` |
| 23 | `5474ff9` | the seven broadcast ARB keys |
| 19 | `20f080f` | the engine gate and the pop-out providers |
| 20 | `a9c7681` | `PopOutCaptionTarget` |
| 21-22 | `2e9a7be` | the controls, the in-surface toggle and the banner |
| 22 | `5137551` | the shell, the rail and the recording screen |
| 24 | `f23453b` | `runZipCaptions` and the one-line `main` |
| 25-26 | `704b10d` | the captions target, controls, banner, strings and scope |
| 27 | `03b1622` | the captions shell, rail, recording screen, viewer scope note and eight strings |
| 28-29 | working tree, uncommitted at handoff | the six runners |

## What now exists

**`zip_core`** (one implementation for both apps):

- `lib/overlay.dart` — the pop-out/external-display surface. Deliberately **not**
  re-exported from `zip_core.dart`: both export a `Failed` (R-M7), so consumers
  import `zip_core.dart` with `hide Failed`.
- `src/output/overlay/` — the promoted controller, codec, snapshot, modes,
  events, bridges, router, lease, enumerator and its two factories, the
  `WindowConfigurator` and `SubWindowClosedChannel` triplets, `pop_out_geometry`,
  `pop_out_availability`, and `OverlayWindowHost` (one router, one enumerator,
  one close channel per engine).
- `src/widgets/` — `PopOutWindowBody`, `CaptionDisplayWidget.controls`, and the
  in-surface toggle placement that keeps the control outside the scroll area
  (R-M4).
- `src/providers/overlay_window_host_provider.dart` — `@Riverpod(keepAlive: true)`.

**`zip_broadcast`**: `broadcastEngineAvailableProvider`,
`popOutWindowControllerProvider`, `popOutStatusProvider`, `popOutEventsProvider`,
`popOutFrameFor`, `PopOutCaptionTarget`, `PopOutControls`, `PopOutInSurfaceToggle`,
`PopOutBanner`, `PopOutChrome`, `PopOutScope`, the rail's `headerAction`, the
shell's flag/events/toggle/dispose, the recording screen's banner and controls,
seven ARB keys.

**`zip_captions`**: `runZipCaptions(args, {runApp, isWeb})` with the overlay
branch before every app service (BR-U8.1-06), `captionsEngineAvailableProvider`,
the same providers/target/controls/banner/scope, `ZcAppShell` as a
`ConsumerStatefulWidget`, `ZcNavRail.headerAction`, the recording screen's
banner and controls, and eight ARB keys behind `ZcStrings`.

**Runners**: both apps' macOS (`configure` handler + `NSWindow.willCloseNotification`
observer + main-engine close channel), Windows (`configure` handler +
`RegisterTopLevelWindowProcDelegate` + main-engine close channel), and Linux
(`configure` handler + `"destroy"` hook + main-engine close channel). No
`RegisterGeneratedPlugins` runs inside any window-created callback (R-B1); no
`window.delegate` or plugin `WndProc` is replaced (R-B2).

## Where the implementation departs from the plan's letter

Each is recorded here because code generation may not silently reinterpret an
approved design. None changes a business rule, a wire shape, a test obligation or
a frozen contract.

1. **The chrome toggle's disabled reason is a semantics hint, not painted
   text.** FD frontend-components §3 asks for the reason "rendered as visible
   `Text` directly beneath the control", and §6 for the availability matrix to be
   rendered "once, in `PopOutControls`". That is unimplementable in the narrow
   layout: on a 375x812 test surface the stacked `Column` overflowed by 8 px
   inside the fixed-height `AppBar`, and `AppBar.actions` itself overflowed by
   319 px because `TextButton.icon` cannot shrink below its intrinsic width.
   The control therefore renders **one line in both layouts**, elides when the
   slot is tight, and carries the reason in `Semantics(hint:)`; the in-surface
   toggle inside the caption surface is where visible text has room. This is
   also why `PopOutChrome` exists as a thin wrapper: it computes the reasoning
   once and hands the hint down.
2. **`PopOutInSurfaceToggle` in the main window is always enabled.** FD
   frontend-components §4 says it "obeys §3's enabled/reason" in the main
   window. In practice the shell's flag is false until the window opens, so
   gating the toggle on the flag would make the control unusable — the only
   entry point would be permanently disabled. It is enabled whenever it is
   rendered; the chrome control carries the availability rule.
3. **The caption shell builds its chrome only once the ARB has loaded.** The
   pop-out widgets read copy through `PopOutScope`, which needs a non-null
   `ZcStrings`. While `zcStringsProvider` is still loading the shell renders the
   routed child alone, as it effectively did before (the title was the only
   consumer). Widget tests must override `zcStringsProvider`; three existing
   suites now do.
4. **The `PopOutScope` `InheritedWidget` was added to both apps.** The plan has
   the shell own the flag and the target, and the screens read them; with the
   screens below the shell in the tree, an `InheritedWidget` is the mechanism that
   keeps the flag out of the provider container (Q10 B). It also carries the
   copy, which replaces the `PopOutControls` "passed through `ZcStrings`"
   wording with an equivalent that works inside a `StatelessWidget`.
5. **`dsplayListProvider` was added to `zip_captions`** (the broadcast app
   already had one): the shell's geometry needs the controller's display list,
   and `popOutFrameFor` takes it as a parameter (R-M5).
6. **`zip_captions`' `fake_async` absence shaped its target test.** Z21/Z25 use
   `await Future.delayed` on real timers rather than `fakeAsync`, because adding
   `fake_async` to that app would be a new dev dependency (A7 forbids it without
   approval).
7. **The Windows/Linux runners compile in CI only.** Neither was built on this
   host; macOS was compiled for both apps. Nothing in this unit claims Windows or
   Linux runtime behaviour.

## Evidence per app (`pip-ux-parity.md` §8.8 item, both apps required)

| Item | `zip_broadcast` | `zip_captions` |
|---|---|---|
| 1 chrome toggle, two labels, state | `B31` `pop_out_controls_test.dart` | `Z22` `pop_out_controls_test.dart` |
| 2 in-surface toggle drives the same path | `B30` `pop_out_shell_test.dart` | `Z24` `pop_out_shell_test.dart` |
| 3 visibility rule | `B31` | `Z22` |
| 4 recognition continues | `B33` `pop_out_caption_target_test.dart` | `Z21` `test/output/overlay/pop_out_caption_target_test.dart` |
| 5 content is live | `B33` | `Z21` |
| 6 no engine → disabled with reason | `B31` + `B30` | `Z22` + `Z24` |
| 7 hint banner + return, clears on close | `B32` `pop_out_banner_test.dart`, `B30` | `Z23` `pop_out_banner_test.dart`, `Z24` |
| 11 drawer closes | `B30` (rail/drawer assertion) | `Z24` |
| 14 double toggle | `B30` | `Z24` |
| 18 no caption text in logs | the target logs nothing; `zip_core`'s fixed-string logs (`N-10`) | `Z25` `pop_out_redaction_test.dart` |
| bootstrap never starts app services | — (inline branch, shipped) | `Z20` `test/bootstrap_test.dart` |
| viewer has no pop-out control | — | `Z26` `viewer_screen_test.dart` |

Items 8-10 stay deferred to Phase 8 (translation-dependent), per the approved
partition.

## Gates

| Gate | Result |
|---|---|
| `dart analyze --fatal-infos lib test` — `zip_core` | clean |
| `flutter test` — `zip_core` | 914 passed, 4 skipped |
| `dart analyze --fatal-infos lib test` — `zip_broadcast` | clean |
| `flutter test` — `zip_broadcast` | 177 passed |
| `dart analyze --fatal-infos lib test` — `zip_captions` | clean |
| `flutter test` — `zip_captions` | 174 passed |
| `flutter build macos --debug` — `zip_broadcast` | built |
| `flutter build macos --debug` — `zip_captions` | built |
| Windows / Linux compile | CI only (not claimed here) |
| Fence: no `desktop_multi_window`/`screen_retriever` import in either app's `lib/` | none |
| Fence: `window_manager` absent | absent (the only mentions are the fence test and GTK's own `get_window_manager_name`) |
| Fence: `zip_core.dart` does not export `overlay.dart` | holds |

## What Unit 9 must still check by hand

The eight manual checks in the plan §7 (float, decoration, resize/move, min size,
OS-close promptness, external display still borderless, multi-monitor placement,
`window.delegate` intact) are unverified here by design. Runtime checks A7 and B4 (OS close of
the pop-out and of the external display) are Unit 9 exit criteria since 2026-10-23; see
"Review round 7 fixes" below.

## Review round 1

Round-1 review of PR 41 returned CHANGES_REQUESTED (0 blockers, 1 major, 4 minors, 1 nit). Every
finding was addressed in code or by a recorded decision; nothing outside the list changed.

| # | Severity | Resolution | Evidence |
|---|---|---|---|
| 1 | Major | **Fixed.** `OverlayWindowEntry.build` now passes `onPopOutToggle: widget.bridge.sendPopOutToggle` to `OverlayWindowApp`, which already forwarded it to `PopOutWindowBody` (FD §4, plan M06/M09). The pop-out's in-surface toggle is a real exit control. | `overlay_window_entry_test.dart` — "the in-window toggle asks the main engine to toggle": a `PopOutMode` launch through `overlayWindowMain`, one tap on the body's toggle, `bridge.toggleRequests` has length 1. |
| 2 | Minor | **Fixed, aligned on FD §3 as written** (visible `Text` + key) rather than on the hint. `zip_captions`' `PopOutChrome` now renders `Key('popOutToggleReason')` beneath the control, exactly as `zip_broadcast` does; the reason stays in the semantics hint. The line is `Flexible`/`maxLines: 2`/ellipsis in both apps because the narrow `AppBar` overflowed by 8 px with a fixed-height line. FD §3 is untouched; the decision and its reason are recorded as an amendment in `functional-design/frontend-components.md` (§4 amendment note, item 1). | `pop_out_controls_test.dart` (both apps): the no-session and no-engine cases assert the key once and assert it is absent when the status leaves `Failed`; the layout assertions in `zc_app_shell_chrome_test`, `navigation_test` and `viewer_routes_shell_test` pass with no `RenderFlex` overflow. |
| 3 | Minor | **Fixed.** Both shells compute `popOutAvailability` once per build and pass `available` through `PopOutScope` to `RecordingScreen`, which passes it to `PopOutInSurfaceToggle.enabled`. FD §4's "obeys §3's enabled/reason" is now true; the parameter is live. The amendment note records it (item 2). | `zip_broadcast/test/shell/pop_out_shell_test.dart` "no engine disables the chrome toggle with its reason" now asserts `surface.enabled == false`, and a new "in-surface toggle is enabled while a session runs" asserts the positive case. |
| 4 | Minor | **Fixed.** `PopOutWindowBody` builds the window's toggle through the same shape as the app widgets: `isPoppedOut: true` (the exit glyph, `Icons.picture_in_picture_alt`), `windowToggle: true` (the window key), and a visible exit label (`popOutWindowExitLabel`, overridable via `toggleLabel`). It can no longer show an "enter" glyph with no label. | `pop_out_window_body_test.dart`: the injected toggle is found by `Key('popOutInSurfaceToggleWindow')`, contains `Icons.picture_in_picture_alt`, and shows `popOutWindowExitLabel`; the tap still fires the callback. |
| 5 | Minor | **Fixed.** Z20 now builds its payload with `encodeLaunch` from a real `PopOutMode` `OverlayWindowLaunch` instead of the undecodable `{"v":1}`. New cases: a decoded payload reaches `OverlayWindowEntry` (not the unavailable frame); a good payload calls `configure` once *before* the `runApp` pump. The 2-argument assertion is corrected to the 0.2.1 contract: `isOverlayWindowLaunch(['multi_window', '7'])` is **false**, because 0.2.1 always passes three arguments. | `packages/zip_captions/test/bootstrap_test.dart` — 4 tests, all passing. The configure case mocks `WindowConfiguratorChannel` (the device has no native side, and an unmocked channel would throw) and asserts the order `configure` → pump. |
| 6 | Nit | **Fixed.** The six stale comments now describe the shipped behaviour: `pop_out_window_body.dart` (the toggle is the body's own, with an icon and label — the "caller supplies the pill" text is gone); `overlay_method_router.dart` (the typedefs live with the controller; no "step 11" / promotion text; `_bootstrap` → constructor; the slot comment no longer describes the pre-promotion state); `zb_app_shell.dart` (no "step 22, until then it changes nothing" — the pop-out toggle now closes the pop-out); `pop_out_geometry.dart` (`mainWindowCentre` is always null in the shipped callers). Both apps' `PopOutInSurfaceToggle` doc no longer claims the pop-out supplies labels through a parameter that does not exist. | `dart analyze --fatal-infos` clean in all three packages (no `comment_references` or unused-parameter infos). |

Behaviour changed beyond the direct fix, with its evidence:

- **The pop-out's own toggle now closes the window (finding 6's comment, made true).** Both shells'
  `_onPopOutEvent` handles `PopOutToggled()` by calling a new `_closePopOut()` (the close half of
  `_togglePopOut`). Without finding 1 this event could never arrive from the window, so nothing was
  observable before. Closing needs no geometry, so no `BuildContext` is stored. Covered by the
  round-1 entry test (the message reaches the bridge) and the existing shell tests (the close path
  is the one the banner's return already exercises: `pop_out_shell_test` in both apps).
- **The pop-out toggle is disabled when no bridge is supplied.** `onToggle` is nullable and
  `onTap` is `canTap = enabled && onToggle != null`, so a widget test with no callback renders a
  non-interactive pill rather than a dead tap target (the old behaviour). The `zip_core` body test
  keeps passing an explicit callback.

Gates re-run after the fixes, in order: `zip_core` analyze clean, 915 passed / 4 skipped;
`zip_broadcast` analyze clean, 178 passed; `zip_captions` analyze clean, 176 passed; both
`flutter build macos --debug` builds succeeded.

## CI fix: Windows/Linux runner compile errors

Round-2 CI on `ac86839` failed Windows (both apps) and Linux (both apps) at compile time;
macOS, iOS, Android and the test matrix passed. Both defects were in this unit's native runner
code — no Dart, test or l10n file changed. Four files only:
`my_application.cc` (both apps) and `flutter_window.cpp` (both apps).

### DEFECT 1 — assignment to a function call

`SubWindowEvents()` is declared as a function *returning* a pointer (`my_application.cc:32`,
`flutter_window.cpp:31`), but the registration site assigned to it
(`my_application.cc:205`, `flutter_window.cpp:209`/`:210`). That is not assignable — Windows
C2106 ("left operand must be an l-value") and Linux "expression is not assignable".

The storage moved into a reference accessor and the pointer-returning read helper now delegates
to it, so the read path at line 48 keeps its null guard unchanged:

```cpp
FlMethodChannel*& SubWindowEventsRef() {
  static FlMethodChannel* channel = nullptr;
  return channel;
}

FlMethodChannel* SubWindowEvents() { return SubWindowEventsRef(); }
```

The assignment site uses `SubWindowEventsRef()`. No `SubWindowEvents() =` remains anywhere.

### DEFECT 2 — `fl_plugin_registrar_get_messenger` mismatch (Linux)

`fl_plugin_registry_get_registrar_for_plugin()` returns an `FlPluginRegistrar*`, but it was passed
*straight into* `fl_plugin_registrar_get_messenger()` without materialising the registrar in a
local, in a nested call (and, in the window-created callback, from an `FlPluginRegistry*`). The
nested form did not type-check against the 3.38.x Linux embedder headers. The messenger is taken
from the view's engine instead, which is the same messenger the registry's registrar exposes:

```cpp
fl_engine_get_binary_messenger(fl_view_get_engine(view))
```

Both occurrences in each Linux file were changed (the `sub_window_events` channel and the
`configure` channel in the window-created callback). The `configure` callback's
`FL_VIEW(registry)` argument is left as-is; `FlPluginRegistry` and `FlView` share the object at
that call site (the plugin itself passes `FL_PLUGIN_REGISTRY(fl_view)`).

Header evidence: `fl_plugin_registry.h` declares
`FlPluginRegistrar* fl_plugin_registry_get_registrar_for_plugin(FlPluginRegistry*, const gchar*)`;
`fl_plugin_registrar.h` declares
`FlBinaryMessenger* fl_plugin_registrar_get_messenger(FlPluginRegistrar*)` (registrar, not
registry); `fl_engine.h` declares
`FlBinaryMessenger* fl_engine_get_binary_messenger(FlEngine*)`; `fl_view.h` declares
`FlEngine* fl_view_get_engine(FlView*)`.

### Windows ownership

The old block released twice in intent: `sub_window_events.release()->SetMethodCallHandler(nullptr)`
leaked the first object and then assigned a second `release()` to the static (which never
compiled anyway). Rewritten so exactly one `release()` transfers ownership to the static:

```cpp
flutter::MethodChannel<flutter::EncodableValue>* channel =
    sub_window_events.release();
channel->SetMethodCallHandler(nullptr);
SubWindowEventsRef() = channel;
```

One release, one owner (the static, deliberately leaked for the engine's lifetime), no double
release. Linux keeps its single `g_object_ref` for the app's lifetime.

The `"destroy"` / `delete-event` / observer logic and both `configure` handlers are untouched —
the diff contains no change to `OnSubWindowDestroy`, `OnConfigureMethodCall`, `SubWindowProc`,
`WindowIds` or `WindowMinSizes`.

### Verification

The Windows and Linux targets cannot be built on the gate machine; the fix was statically
verified: each changed region was syntax-checked with clang against header stubs declaring the
real signatures, and the *old* assignment form was reproduced failing with "expression is not
assignable" while the new form compiles. CI on the real runners is the gate.

Gates after the fix: `zip_core` analyze clean, 915 passed / 4 skipped; `zip_broadcast` analyze
clean, 178 passed; `zip_captions` analyze clean, 176 passed; both `flutter build macos --debug`
builds succeeded.

## Review round 3

Round-3 review of PR 41 returned 2 major, 2 minor and 1 nit. All five are fixed in code or in this
document; nothing outside the list changed. Dependency set is unchanged
(`desktop_multi_window ^0.2.1` in both apps, `screen_retriever ^0.2.2` in `zip_core` only,
none in `zip_broadcast`); no `window_manager`; no new dependency. Native edits are confined to
the four runner files. Dart edits are confined to the two shells, `zip_captions`'
`pop_out_providers.dart` (and its generated part) and the two shell test files.

| # | Severity | Resolution | Evidence |
|---|---|---|---|
| 1 | Major | **Fixed.** The Windows `configure` reader rejected every call: `StandardMessageCodec` writes a Dart `int` that fits in 32 bits as int32, so the Windows codec delivers `windowId` as `int32_t` and `std::get_if<int64_t>` returned null. `int_value` in both `flutter_window.cpp` files now accepts `int32_t` as well as `int64_t` and widens with `static_cast<int64_t>`. The rest of the payload was audited against the reader types (table below): every other key already matched. | Static: the accepted variants are now `int64_t` and `int32_t`; the full key/type table below. CI on the Windows runners is the real gate — this machine cannot compile a Windows target. |
| 2 | Major | **Fixed.** Both shells' `_togglePopOut` now read `controller.displays` (`overlay_window_controller.dart:207`, kept current by the enumerator at `:238-240`) instead of `ref.read(displayListProvider).value`, which is auto-dispose and unwatched by the shell. The geometry therefore resolves a display and the pop-out opens on the computed 2-line strip. | `zip_captions/test/widgets/pop_out_shell_test.dart` — "the toggle computes a frame from the controller displays": the provider is overridden with an empty list while the controller's enumerator holds one display; the test drives the real ready handshake and asserts the `Rect` handed to `setFrame` equals the geometry computed from `controller.displays`. `zip_broadcast/test/shell/pop_out_shell_test.dart` — "the toggle hands the computed frame to setFrame": same shape on `/recording`; the test target reaches `setFrame` with the geometry computed from `controller.displays`. Both tests fail against the old provider read (verified by re-applying it) and pass now. With the old read the broadcast test fails because the pop-out opened with **no `setFrame` at all** (`Actual: ['createWindow', 'show']`), not because it received a wrong rectangle — the regression was a lost frame, and the tests pin that. |
| 3 | Minor | **Fixed.** Both shells now `ref.watch(popOutStatusProvider)` instead of reading `controller.status` once at build. `zip_captions` gained the provider (already present in `zip_broadcast`), mirroring its implementation: replay the current value, then `yield* controller.statusChanges`. The shells fall back to `const Off()` while the first value is pending. A controller that becomes `Unsupported` (failed display probe) now hides the toggle and its in-surface counterpart. | `zip_captions/test/widgets/pop_out_shell_test.dart` — "a status change to Unsupported hides the toggle": the provider is driven by a `StreamController`, emits `Unsupported`, and the `popOutToggle` disappears. |
| 4 | Minor | **Fixed.** Both shells' `_onPopOutEvent` now call a shared `_unregisterPopOut()` on `WindowClosed` / `OpenFailed` (and `_closePopOut` uses the same helper), so the pop-out path matches the external display's `_unregisterOverlay`: the target leaves the caption fan-out and is disposed with it. The registry's `remove` disposes the target; the dispose's `close(dispose)` is a no-op on an already-`Off` controller. | `zip_captions/test/widgets/pop_out_shell_test.dart` — "a window closed on its own leaves the caption fan-out": after a native close, `registry.activeTargets` is back to its pre-toggle size. The test fails against the old handler and passes now. |
| 5 | Nit | **Fixed, as "document the leak as intentional".** The double reference on `sub_window_events` is gone: the single owned reference (from `fl_method_channel_new`) is stored in the accessor directly, with no extra `g_object_ref`, and a comment records that the one reference is held for the engine's lifetime. Each sub-window's `configure` channel is documented as deliberately leaked at its creation site (the window's own `destroy` hook is the app's, not the channel's, so nothing here could unref it in time). This section documents `7fe4c06`. | `my_application.cc` (both apps): one `fl_method_channel_new` result assigned to `SubWindowEventsRef()`, no `g_object_ref`; comments at both sites. |

### Payload type audit (finding 1)

The `configure` payload is built in one place,
`zip_core/lib/src/output/overlay/window_configurator.dart:57-63`, from
`OverlayWindowConfig` (`zip_core/lib/src/models/overlay_window_config.dart`): `windowId` is the
`int` parameter of `configure`, `floating`/`decorated` are `bool`, `minWidth`/`minHeight` are
`double` (defaults `0` typed as double). No other key is sent. Dart's `StandardMessageCodec`
(`message_codecs.dart:386-409`, local Flutter 3.41.7) writes `bool` as `_valueTrue`/`_valueFalse`,
`double` as `_valueFloat64`, and `int` as `_valueInt32` when `-0x7fffffff - 1 <= value <=
0x7fffffff`, else `_valueInt64`.

| Key | Dart type (source) | Dart encoding (`message_codecs.dart`) | Windows reader (`flutter_window.cpp`) | Linux reader (`my_application.cc`) | macOS | Result |
|---|---|---|---|---|---|---|
| `windowId` | `int` (parameter, `window_configurator.dart:58`) | `_valueInt32` for every id ≤ 0x7fffffff (`:397-400`), `_valueInt64` above | `int_value`: was `get_if<int64_t>` only → **fixed** to accept `int32_t` and `int64_t` | `FL_VALUE_TYPE_INT`, read with `fl_value_get_int` (`FL_VALUE_TYPE_INT` covers both widths) | `as? Int` (`NSNumber`, width-agnostic) | **fixed (Windows)**; Linux/macOS were already correct |
| `floating` | `bool` (`OverlayWindowConfig.floating`) | `_valueTrue`/`_valueFalse` (`:302-303`) | `bool_value`: `get_if<bool>` | `FL_VALUE_TYPE_BOOL` | `as? Bool` | OK |
| `decorated` | `bool` (`OverlayWindowConfig.decorated`) | `_valueTrue`/`_valueFalse` | `bool_value`: `get_if<bool>` | `FL_VALUE_TYPE_BOOL` | `as? Bool` | OK |
| `minWidth` | `double` (`OverlayWindowConfig.minWidth`, `@Default(0)` typed `double`) | `_valueFloat64` (`:305-307`); the external display sends `0.0`, the pop-out `200.0` — both typed `double`, never `int` | `double_value`: `get_if<double>` | `FL_VALUE_TYPE_FLOAT` | `as? Double` | OK |
| `minHeight` | `double` (`OverlayWindowConfig.minHeight`) | `_valueFloat64`; external display `0.0`, pop-out `120.0` | `double_value`: `get_if<double>` | `FL_VALUE_TYPE_FLOAT` | `as? Double` | OK |

Four runner files were checked: `zip_captions` and `zip_broadcast` `windows/runner/flutter_window.cpp`
(identical payload readers) and `zip_captions` and `zip_broadcast` `linux/runner/my_application.cc`
(identical handler). The only mismatch was `windowId` on Windows. No sizing or geometry is sent as
an `int`: the minimum size is two doubles, and the frame itself travels over the plugin's own
`setFrame` call, not this channel. The Windows `subWindowClosed` event the runners emit goes the
other way and builds its `EncodableValue` from an `int64_t`, which the Dart codec decodes as `int`
— unaffected.

### Round-2 n1 — resolved, not a defect

Round-2 finding n1 does not reproduce. `PopOutCaptionTarget.hide()` closes the controller with
`CloseReason.toggleOff`, but on the event path the preceding `registry.remove(_popOutTarget)`
already disposed the target, whose `dispose()` closes with `CloseReason.dispose`; the second
close takes the window id as null and is a no-op (`_runClose` captures and nulls the id before
its first await). Recorded here as resolved-not-a-defect, not as a code change.

### CI-fix record — `7fe4c06`

`7fe4c06 fix(zip_captions,zip_broadcast): link flutter_wrapper_plugin on Windows runner` is the
third commit in this branch's CI-fix series, after `56a6fec` (the compile defects documented in
the section above). It fixes the Windows link step: the runners' CMake target now links the
`flutter_wrapper_plugin` library that the runner sources reference, so `flutter_window.cpp`
resolves at link time on both Windows apps. It changed no Dart, test or l10n file. CI on the
Windows runners is the gate for it, as for finding 1 above.

Gates re-run after the round-3 fixes, in order: `zip_core` analyze clean (`No issues found!`),
915 passed / 4 skipped; `zip_broadcast` analyze clean, 179 passed; `zip_captions` analyze clean,
179 passed; both `flutter build macos --debug` builds succeeded.

## Review round 4 (confirm-fix)

Round-4 re-review of PR 41 at `fbdac9a` returned APPROVE: all five round-3 findings verified fixed
in code, with the payload audit re-derived independently and the new shell tests mutation-tested
against the pre-fix tree (reverting the finding-2 fix makes both fail; on `7fe4c06` the broadcast
test fails because no `setFrame` was issued at all). No blockers, no majors.

Two documentation-accuracy notes were applied here, with no code change:

- The finding-2 evidence row now states the actual pre-fix failure mode (no `setFrame` at all,
  `Actual: ['createWindow', 'show']`) rather than implying a wrong rectangle.
- The payload audit rows for `minWidth`/`minHeight` now record the values actually sent: the
  external display sends `0.0`/`0.0` and the pop-out `200.0`/`120.0`, typed `double` in every case,
  so the Windows `get_if<double>` reader is correct for both modes.

Three further observations from round 4 were reviewed and need no action: `WM_GETMINMAXINFO` with
`{0,0}` for the external display is correct given its configured values; the sub-engine fallback
copy (`OverlayWindowUnavailableApp`) is unlocalized but only reachable on an invalid launch payload;
the two Windows runner files differ by a single blank line.

Standing caveat: CI green on Windows and Linux proves compilation only. That the external display is
borderless and the pop-out is topmost and minimum-sized on Windows, and that the computed frame lands
on a real display, are runtime properties for the Unit 9 device checks. Nothing in this stage verified
them on hardware.

## Morning-review follow-ups (n3, n4, n6)

Three items parked from review rounds 3 and 4, addressed on request.

### n3 — the pop-out toggle label is now localized

Previously `PopOutWindowBody` rendered `popOutWindowExitLabel`, a `zip_core` constant, so no app
could localize it even though both ARBs carry `popOutExit`. The label now travels with the open
request:

- `OverlayConfig.popOutToggleLabel` (`String?`, optional) carries the app's copy.
- The launch codec encodes it under `config.popOutToggleLabel` only when non-null, and
  `_decodeConfig` rejects a non-string value (returns null, keeping decode total).
- `OverlayWindowApp` reads `launch.config.popOutToggleLabel`, falling back to the shipped English
  constant, so an older payload without the key still renders correctly.
- `zip_captions` passes `_strings?.popOutExit` from the shell; `zip_broadcast` passes
  `ZipBroadcastLocalizations.of(context)?.popOutExit` from `_popOutConfig`.

The shell caches the loaded copy in `_strings` because the toggle callbacks are built above
`PopOutScope` and cannot read it through the tree.

Tests: codec round trip, absent-label decode (null), non-string rejection; and two
`OverlayWindowApp` widget tests proving the config label renders and the constant is the fallback.

### n4 — the duplicated availability computation is gone

`PopOutChrome` recomputed `popOutAvailability` although the shell had already done so. Both shells
now compute it once and pass `reason` into `PopOutChrome`, which no longer calls
`popOutAvailability`. `PopOutControls` still computes its own `availability` for the button's
enabled state; that is the control's own concern and was not the duplication flagged.

### n6 — the integrated scope assertion exists in `zip_captions`

Two new shell tests drive the real path (`popOutAvailability` -> `PopOutScope.available` ->
`PopOutInSurfaceToggle.enabled`) with and without an engine, including the visible reason key. This
is what round 4 noted was missing relative to `zip_broadcast`.

Gates after the change: `zip_core` 918 passed / 4 skipped, `zip_broadcast` 181, `zip_captions` 181,
`dart analyze --fatal-infos` clean in all three, both macOS `--debug` builds succeed.

## Review round 5

Round-5 review of PR 41 at `3556a3d` returned CHANGES_REQUESTED: one blocker, two major, one minor and
one nit. All five are fixed in code or in this document. No dependency, pubspec, lockfile or `docs/`
change. Native edits are the two macOS `MainFlutterWindow.swift` files only.

The blocker was structural: rounds 1, 2 and 4 marked the router clean because the router tests pass in
isolation, but nothing in production ever called `OverlayMethodRouter.register` — `createController`
handed out an installer for a token it had never registered — and `zip_broadcast`'s external display
bypassed the router entirely.

| # | Severity | Cause | Fix | Test | File:line |
|---|---|---|---|---|---|
| 1a | Blocker | `createController` passed `installerFor(OverlayHandlerToken())` for a fresh, unregistered token; `installerFor` only replaces an existing registration's handler. | Register first: `_router.register(() => controller.windowId, ...)`, then hand the controller `installerFor(token)`. `windowIdOf` is read at dispatch, so closing over the `late` controller is safe. | `overlay_window_host_test.dart` "a host-built controller reaches Open over a delivered overlayReady" — fails pre-fix with `slot.current == null` ("the router never installed"). | `zip_core/lib/src/output/overlay/overlay_window_host.dart:94-121` |
| 1b | Blocker | `zip_broadcast`'s `overlayWindowControllerProvider` built its own enumerator and installed `overlayMethodHandlerInstaller` directly, taking the plugin's single slot from the router. | Build it from `overlayWindowHostProvider.createController(mode: ExternalDisplayMode())`; `displayList` reads `overlayWindowHostProvider.displays`. The `overlayMethodHandlerInstaller` export is removed from both window-service files. | `overlay_window_host_test.dart` "two host-built controllers each receive only their own message" — fails pre-fix with `slot.calls == []`. | `zip_broadcast/lib/src/providers/overlay_window_controller_provider.dart:16-24`; `zip_core/lib/src/output/overlay/desktop_multi_window_service_io.dart` (export removed) |
| 2 | Major | The target is registered only while a session is active, so the bus's `SessionStateEvent` was already gone; `_activity` stayed `standby` and the window rendered the blank standby surface. | `PopOutCaptionTarget` takes `recordingState`; `show()` seeds `_activity = _activityFor(recordingState())` and pushes a snapshot before `open`. Both shells pass a read-time probe. | "registered after the session started pushes live, not standby" in both apps — fails pre-fix with `Expected: live, Actual: standby`. | `zip_captions/lib/src/output/overlay/pop_out_caption_target.dart:56-61` (seed at `:59`); `zip_broadcast/.../pop_out_caption_target.dart:56-61`; shells at `zc_app_shell.dart:56`, `zb_app_shell.dart:86` |
| 3 | Major | Screens rendered `PopOutInSurfaceToggle` whenever a scope existed, and `PopOutScope` carried no visibility flag; the shells fell back to `const Off()` while the status stream loaded, flashing the chrome for one frame on unsupported platforms. | `PopOutScope` gained `visible`; the screens pass `controls: null` when `!visible`; the fallback is the controller's synchronous `status`. | "the in-surface toggle does not render" and "the chrome does not flash on the first frame" in both apps — fail pre-fix with the toggle found / `Expected: Unsupported, Actual: Off`. | `zip_captions/lib/src/widgets/pop_out_scope.dart:69`, `recording_screen.dart:80-84`, `zc_app_shell.dart:199-206`; broadcast equivalents |
| 4 | Minor | The `willClose` observer returned at the `windowIds` guard before removing its token, so an observer for a window whose `configure` never recorded an id leaked for the process lifetime. | Remove the observer token before the `windowIds` guard. | Not unit-tested (Swift runner has no test target in this repo); reviewed by inspection. | `zip_captions/macos/Runner/MainFlutterWindow.swift:104-115`; `zip_broadcast/.../MainFlutterWindow.swift:104-115` |
| 5 | Nit | `MainFlutterWindow.swift:35-36` called `floating: false, decorated: false` the pop-out's properties; they are the external display's. | Comment corrected in both files. The existing `// ignore` directives were left alone as instructed. | Documentation only. | `zip_captions/macos/Runner/MainFlutterWindow.swift:32-37`; `zip_broadcast/.../MainFlutterWindow.swift:32-37` |

### Left undone

- **Manual macOS check.** Still owed, same as every prior round: start a session in each app, pop out,
  confirm the window opens within 10 s with live captions and the exit toggle, return using the
  in-window toggle; in `zip_broadcast` confirm the external display still opens, shows captions and
  closes. This is the only thing that can prove findings 1-3 on a real window.
- **Finding 4** has no automated test: neither app has a Swift test target, and the CI macOS build only
  compiles the runner.

### Gates after the change

| Gate | Result |
|---|---|
| `dart analyze --fatal-infos` — `zip_core` | clean |
| `flutter test` — `zip_core` | 920 passed, 4 skipped |
| `dart analyze --fatal-infos` — `zip_broadcast` | clean |
| `flutter test` — `zip_broadcast` | 184 passed |
| `dart analyze --fatal-infos` — `zip_captions` | clean |
| `flutter test` — `zip_captions` | 184 passed |
| `flutter build macos --debug` — `zip_broadcast` | built |
| `flutter build macos --debug` — `zip_captions` | built |

## Fix round 6 (runtime review)

The findings are in `../../plans/pop-out-review-round-6.md`, worked per
`../../plans/pop-out-review-round-6-fix-plan.md`. Runtime evidence came from temporary diagnostic
entrypoints (`-t`, deleted afterwards, never committed) that drive the real app through its own
widgets and the real runner, because Accessibility is not granted to the agent. Window facts come
from `CGWindowListCopyWindowInfo` at 500 ms intervals.

| # | What it turned out to be | Change | Pinning test | Before / after at runtime |
|---|---|---|---|---|
| R6-5 | Every `zip_core` record already reached `Logger.root`, and both apps forward it to `dart:developer`'s `log`, which DevTools shows and `flutter run` does not. The host's `_child` also built child names from `Logger.name` (last segment only), so its children sat outside its subtree. | `routeOverlayLogToConsole` (`overlay_console_log.dart`): in a debug build, the host logger's subtree is printed through `debugPrint` as level, name and message only, never the error object. The provider builds the host on `Logger('zip_core.OverlayWindowHost')`; controllers log beneath it; `_child` uses `fullName`. Release wires nothing. | `overlay_console_log_test.dart` (4): debug prints, release wires nothing, host-built controllers log in the subtree, the provider routes to `debugPrint`. | Before: no controller line on stdout. After: `flutter: WARNING: zip_core.OverlayWindowHost.zip_captions.PopOutWindowController: overlay ready timeout` on a forced failure. |
| R6-1 | **Neither candidate.** The macOS embedder starts a `FlutterViewController`'s engine only from `viewWillAppear` (`FlutterViewController.mm:407-410`); `desktop_multi_window` keeps a new window hidden until `show`; the controller shows only after `overlayReady`. The sub-engine's `main` never ran. The "1x1 offscreen helper" in the review was the pop-out's own window, created at the press and released at the timeout. Windows (`FlutterViewController` constructor) and Linux (window shown, realised, then hidden) start their engines at creation and are not affected. The same deadlock blocked `zip_broadcast`'s external display. | Both `MainFlutterWindow.swift`: the window-created callback ends with `_ = controller.engine.run(withEntrypoint: nil)`, after the `configure` channel and the close hook exist. The handshake (hidden until configured and framed, shown on ready) is unchanged. | `macos_runner_fence_test.dart` (2, static, both apps): the callback starts the engine after installing both hooks. Neither app has a Swift test target. | Before: no `sub:` output, window 1x1 offscreen, `ready_timeout` at 10 s. After: sub-engine `main` at +0.2 s, `Open` at +0.65 s, a layer-3 1134x140 window bottom-centre on the primary, `captionUpdate` flowing. |
| R6-2 | **Not a rule defect.** The rule's `enabled` depends only on the session and the engine; the status only hides. Instrumented reads: after a stop, Home reads disabled with the reason twice, across a forced `popOutStatusProvider` rebuild. Passing through `/recording` after a stop starts a new session (`RecordingScreen.initState`, a prior-unit behaviour), and Home then correctly reads enabled — the reviewer's second read. | None. | `pop_out_shell_test.dart` "start, stop, Home reads disabled with its reason, twice". | Same before and after; recorded in the PR thread. |
| R6-3 | `zip_captions`' `PopOutChrome` never rendered `popOutOpenFailed`, although FD §5 (R-M8) prescribes it and `zip_broadcast` already did. | `Key('popOutOpenFailed')` beside the chrome toggle while `Failed`, `Flexible`/two lines for the narrow `AppBar`. One string, per design (owner's choice; no per-code keys). | `pop_out_shell_test.dart` "a failed open shows the reason and the next open clears it". | After: `openFailed=true`, banner gone, captions back, on a forced `ready_timeout`. |
| R6-4 | **Not reproducible.** The controller is `Unsupported` from its constructor on iOS and Android (no probe runs there). Per-frame scans across session start found no pop-out widget on any frame (iOS 26.0 simulator: 39 frames; Android 16 emulator: 24 frames). A 10 fps recording shows only the recording screen's own Appearance button sliding in with the route. | None. | `pop_out_shell_test.dart` "no pop-out widget is built on any frame of the start" (40 frames, never-emitting status stream). | Same before and after. |

**Owner-directed UX change (both apps)** — recorded as the FD frontend-components §5 amendment
dated 2026-10-23: while popped out, the main window shows the hint and the return action **in place
of** the captions, as v1 does. Tests: "popped out, the main window shows the hint, not captions" in
both shell suites. Three existing tests tapped the main window's in-surface toggle a second time
while popped out; that toggle leaves with the caption surface, so their second activation is now
the chrome toggle.

**Runtime checks run (macOS, debug)**: A2, A3, A5, A6, A8, A9 in `zip_captions`; B2 (external
display on the secondary display, 3440x1415, layer 0) and B3 (both windows together) in
`zip_broadcast`; C3 on iOS and Android. **Still BLOCKED**: A7 and B4 (OS close), because
Accessibility is not granted to the agent. A4's floating layer, placement and size were observed;
decoration and the minimum size were not (no screenshot: `screencapture -l` refused the windows).

**New finding R6-6 (not fixed; design question)**: after the session stops while popped out, the
window stays open (as specified), but the main window's chrome control reads "Exit Picture in
Picture" and is **disabled** with the no-session reason, and the return panel has left with the
recording screen. Only the window's own toggle or an OS close can end it. UX-PIP-03 says the control
applies while "a session is active **or already popped out**"; FD §6's formula omits the second half.

### Gates after the change

| Gate | Result |
|---|---|
| `dart analyze --fatal-infos` — all three packages | clean |
| `flutter test` — `zip_core` | 926 passed, 4 skipped |
| `flutter test` — `zip_broadcast` | 185 passed |
| `flutter test` — `zip_captions` | 188 passed |
| `flutter build macos --debug` — both apps | built |

### Owner direction after the round: session end, the rail, the status lines

Recorded as the second FD frontend-components §5 amendment of 2026-10-23. Both apps.

| Change | Code | Tests |
|---|---|---|
| A session that ends closes the pop-out and resets the control (resolves R6-6) | Each shell listens to its session state and runs `_closePopOut()` when a popped-out session leaves the active states | "stopping the session closes the pop-out and resets it" in both shell suites; the `zip_captions` one also starts a fresh session and asserts the captions are in the main window |
| No pop-out control in the left rail | `ZcNavRail` and `ZbNavRail` restored from `develop` (the `headerAction` slot existed only for this control); the shells no longer pass it | "the desktop rail carries no pop-out control" in both shell suites |
| Disabled reason and open-failure line under the in-surface toggle | `PopOutInSurfaceToggle` gains `reason` and `openFailed`; `PopOutScope` carries them; `PopOutChrome` drops its failure line | Three `PopOutInSurfaceToggle status lines` tests and "carries no open-failure line" (broadcast controls); "no engine shows the reason under the in-surface toggle", the R6-3 test now on the wide layout (captions); "a failed open shows the reason under the in-surface toggle", "no engine disables the in-surface toggle with its reason" (broadcast shell) |

Tests moved rather than added: two chrome tests (round 5's first-frame check, R6-2's stable reads)
now run on the narrow layout, the only one with a chrome control; broadcast's double-activation
test now uses the return action.

Runtime (macOS debug, `zip_captions`): open reaches `Open` (layer 3, 1134x140); stopping the session
closes the window within the second and the status is `Off`; a fresh session shows the captions and
the in-surface toggle in the main window; no rail control at any point.

| Gate | Result |
|---|---|
| `dart analyze --fatal-infos` — both apps | clean (`zip_core` unchanged) |
| `flutter test` — `zip_broadcast` | 190 passed |
| `flutter test` — `zip_captions` | 190 passed |
| `flutter build macos --debug` — both apps | built |

## Review round 7 fixes

Independent review round 7 (PR #41, 2026-10-24) approved the code with four minors and five nits.
The owner directed m1-m4 fixed and A7/B4 deferred. Both apps; `zip_core` unchanged. The design
changes are the third amendment in FD `frontend-components.md` §5.

| # | Finding | Change | Pinning tests | Mutation check |
|---|---|---|---|---|
| m1 | The R6-3 test's "the next open clears it" was vacuous: the next open replaced the caption surface with the return panel, so the in-surface toggle (and its line) were gone either way. `zip_broadcast` had no clearing test after `f2bfb1b`. `zip_captions`' two chrome "failure line" tests only compared a semantics hint with null and the empty string. | Tests only; the code was correct. | R6-3 test (captions) and "a failed open shows the reason under the in-surface toggle" (broadcast) now return to the window and read the in-surface toggle again. The chrome failure tests in both apps assert the line's key. | `openFailed: true` hard-wired now fails both apps' tests; before, it passed all of them. |
| m2 | On the narrow layout an open started from the `AppBar` on a screen with no caption surface failed silently. | `PopOutChrome` renders `popOutOpenFailed` (`Key('popOutToggleOpenFailed')`) while `Failed`. It shows one status line at most, and the reason outranks the failure. The control is bounded at 220 px. | Chrome: "shows the open-failure line while the open has failed", "clears the failure line when the status leaves Failed", "a disabled reason outranks the failure line" (both apps); captions "its ... line fits a 375 px AppBar" (English copy, both lines). Shell: captions "a failed open from a screen with no caption surface shows the reason by the chrome control" (Home); broadcast "the narrow chrome reason line fits the AppBar" and "a failed open shows the reason by the narrow chrome control". | Removing the width bound fails the 375 px tests in both apps. |
| m3 | The R6-1 deadlock is a live `develop` defect from Unit 8, not only this branch's. | Records only (below). | — | — |
| m4 | The return panel overflowed a short caption area: 52 px at a 160 px area and 2x text. | The panel's column scrolls inside the panel (`SingleChildScrollView`, the 24 px padding moved inside it). | "fits a short caption area at large text sizes" (both apps' banner suites): no exception, and the return action can be scrolled to and tapped. | Restoring the plain padding fails the test. |

**Found while fixing m2 (pre-existing, fixed with it)**: the narrow chrome's reason line overflowed
the 375 px `AppBar` by 319 px with the shipped copy. The round-1 amendment's `Flexible` bounded only
its height, and every earlier narrow test used sentinel strings or an unsupported controller. It is
the same 319 px the overnight ledger recorded before round 1. The width bound fixes both lines. In
the test font (Ahem, one em per glyph) the exit label alone also overflowed by 3.3 px in the Open
state, which a large text scale or a longer translation reproduces in the shipped font; the bound
covers that too.

**m3, for the record**: on `develop`, Unit 8's controller (`zip_broadcast/lib/src/output/overlay/
overlay_window_controller.dart`) also shows the window only in `_runReady` after `overlayReady`. Its
macOS runner callback never starts the sub-engine, and `desktop_multi_window` resolves to the same
lock entry. Unit 8's external display has therefore never opened on macOS. Unit 8's record claims a
macOS build only and leaves the window check owed (`external-display/code/unit8-summary.md`), so
nothing there claimed otherwise. Fix round 6's runner change (`7e58f89`) fixes it for both apps when
PR #41 merges. Windows and Linux start their engines at window creation and were not affected.

**A7 and B4 deferred to Unit 9** (owner direction, 2026-10-23): the two OS-close checks still need
Accessibility granted to the verifying host. They are recorded as Unit 9 exit criteria, with
pass conditions, in `inception/application-design/phase2-unit-of-work.md` (Unit 9). They add to the
eight manual checks in "What Unit 9 must still check by hand" above; A7 overlaps check 4
(OS-close promptness) and supersedes its "banner" wording with the return panel.

Not done: no runtime run of these changes (widget tests only), and the five nits are left as
recorded on the PR, apart from n3's stale rail comments in `PopOutChrome`, which the m2 edit
rewrote.

| Gate | Result |
|---|---|
| `dart analyze --fatal-infos lib test` — both apps | clean (`zip_core` unchanged) |
| `flutter test` — `zip_broadcast` | 195 passed |
| `flutter test` — `zip_captions` | 195 passed |
| `flutter build macos --debug` — both apps | built |
