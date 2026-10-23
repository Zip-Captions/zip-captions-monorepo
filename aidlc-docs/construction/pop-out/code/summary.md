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
`window.delegate` intact) are unverified here by design.

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
| 2 | Major | **Fixed.** Both shells' `_togglePopOut` now read `controller.displays` (`overlay_window_controller.dart:207`, kept current by the enumerator at `:238-240`) instead of `ref.read(displayListProvider).value`, which is auto-dispose and unwatched by the shell. The geometry therefore resolves a display and the pop-out opens on the computed 2-line strip. | `zip_captions/test/widgets/pop_out_shell_test.dart` — "the toggle computes a frame from the controller displays": the provider is overridden with an empty list while the controller's enumerator holds one display; the test drives the real ready handshake and asserts the `Rect` handed to `setFrame` equals the geometry computed from `controller.displays`. `zip_broadcast/test/shell/pop_out_shell_test.dart` — "the toggle hands the computed frame to setFrame": same shape on `/recording`; the frame equals `computePopOutFrame(displays: controller.displays, ...)`. Both tests fail against the old provider read (verified by re-applying it) and pass now. |
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
| `minWidth` | `double` (`OverlayWindowConfig.minWidth`, `@Default(0)` typed `double`) | `_valueFloat64` (`:305-307`) | `double_value`: `get_if<double>` | `FL_VALUE_TYPE_FLOAT` | `as? Double` | OK |
| `minHeight` | `double` (`OverlayWindowConfig.minHeight`) | `_valueFloat64` | `double_value`: `get_if<double>` | `FL_VALUE_TYPE_FLOAT` | `as? Double` | OK |

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
