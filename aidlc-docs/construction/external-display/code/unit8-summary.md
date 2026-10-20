# Code Summary — Unit 8: External Display (`zip_broadcast`)

## Story Implemented

- **S-20**: The external display output — a broadcaster plugs in a second
  screen, turns the output on from the output targets panel, and the captions
  appear on that screen in a borderless, opaque window while the main window
  keeps working. Disconnecting the display stops the output but never the
  captioning, and the saved display is remembered rather than silently
  replaced.

## Verification Results

| Check | Result |
|-------|--------|
| `dart analyze --fatal-infos` (`zip_broadcast`) | 0 errors, 0 warnings, 0 infos |
| `flutter test` (`zip_broadcast`) | 259 passed |
| `dart analyze --fatal-infos` (`zip_core`) | 0 issues |
| `flutter test` (`zip_core`) | 603 passed, 4 skipped |
| `dart analyze --fatal-infos` (`zip_captions`) | 0 issues |
| `flutter test` (`zip_captions`) | 139 passed |
| `flutter build macos --debug` | built `build/macos/Build/Products/Debug/zip_broadcast.app` |
| `rg -l "package:screen_retriever" packages/zip_broadcast/lib` | exactly one path: `lib/src/output/overlay/screen_retriever_display_enumerator_io.dart` |
| `rg -n "window_manager\|kIsWeb\|popOut\|PopOut\|pipContent\|ping"` | no match in this unit's files (the two `popOut` hits are test fixtures asserting unknown-mode rejection; `kIsWeb` in `main.dart` is the pre-existing Supabase storage choice) |
| Lockfiles | `pubspec.lock` unchanged since the `screen_retriever` addition; `macos/Podfile.lock` unchanged |

## Files Created

| File | Purpose |
|------|---------|
| `lib/src/output/overlay/display_info.dart` (+ `.freezed.dart`) | One connected display: opaque id, label, logical work area, scale, primary flag |
| `lib/src/output/overlay/display_enumerator.dart` | The display-source interface and its event contract |
| `lib/src/output/overlay/screen_retriever_display_enumerator.dart` / `_io.dart` / `_stub.dart` | The only place `screen_retriever` is imported; id normalisation, primary derivation, re-read-and-diff change stream |
| `lib/src/output/overlay/overlay_window_mode.dart` | Sealed window-intent hierarchy with the single `ExternalDisplayMode` variant |
| `lib/src/output/overlay/overlay_activity.dart` | `standby` / `live` / `paused` |
| `lib/src/output/overlay/caption_position.dart` | `top` / `bottom` for the caption block |
| `lib/src/output/overlay/overlay_event.dart` | `DisplayLost` / `WindowClosed` / `OpenFailed` |
| `lib/src/output/overlay/external_display_status.dart` | The seven rendered statuses |
| `lib/src/output/overlay/caption_overlay_snapshot.dart` | One frame: activity, entries, interim, settings, with value equality |
| `lib/src/output/overlay/caption_overlay_codec.dart` | Versioned, size-capped, never-throwing snapshot and launch codecs |
| `lib/src/output/overlay/overlay_window_controller.dart` | The window lifecycle state machine: one window at a time, ready timeout, 16 ms update coalescing, serialised open/close/fail |
| `lib/src/output/overlay/overlay_window_bridge.dart` / `_io.dart` / `_stub.dart` | The sub-engine's channel to its host |
| `lib/src/output/overlay/overlay_window_entry.dart` | Launch predicate, sub-engine entry, handler-before-ready ordering, drop-and-keep on a bad update |
| `lib/src/providers/overlay_window_controller_provider.dart` | The one controller, plus the status and display-list streams |
| `lib/src/widgets/overlay_window_app.dart` | The window itself: opaque themed surface, standby/live/paused, caption position, fixed unavailable frame |
| `lib/src/widgets/external_display_controls.dart` | The output targets section: one row per display, one toggle, position selector, waiting and failure banners |
| `test/output/overlay/*` (12 files) | Codec, resolution, frame conversion, enumeration, controller, properties, entry, redaction |
| `test/widgets/overlay_window_app_test.dart`, `test/widgets/external_display_controls_test.dart` | The window and the controls |
| `test/helpers/fake_display_enumerator.dart` | Scriptable display source, replays the current list to late subscribers |

## Files Modified

| File | Change |
|------|--------|
| `lib/src/output/overlay/caption_overlay_target.dart` | Rewritten as a thin controller delegator plus caption-bus adapter; the Phase 1 `_isVisible` field is gone |
| `lib/src/output/overlay/desktop_window_service.dart` | `setFrame` and `show` added |
| `lib/src/output/overlay/desktop_multi_window_service_io.dart` / `_stub.dart` | The two new methods, the pure `toPlatformFrame`, and a production constructor separate from the test seam |
| `lib/src/models/overlay_config.dart` | `targetDisplayId` replaced by a window `mode` |
| `lib/src/models/output_target_settings.dart` | Saved display id and caption position |
| `lib/src/providers/broadcast_providers.dart` | Persists both new settings; forces the output off on load |
| `lib/src/shell/zb_app_shell.dart` | Builds the delegating target, subscribes to window events, switches the output off when the window goes away, opens after registering |
| `lib/src/widgets/output_targets_panel.dart` | The Phase 1 overlay card is replaced by the external display section |
| `lib/main.dart` | `main(List<String> args)` routes a multi-window launch to the overlay engine before Supabase or main-app logging start |
| `l10n/arb/app_en.arb` | 18 new keys, with descriptions and the two placeholders |
| `macos/Runner/MainFlutterWindow.swift`, `windows/runner/flutter_window.cpp`, `linux/runner/my_application.cc` | Borderless styling from the window-created callback |

## Decisions Worth Knowing

- **The controller is the only thing that knows a window exists.** The
  target delegates, the shell reacts to events, and the widget reads status —
  so "is a window open" has exactly one source.
- **A missing saved display is waited for, not replaced.** Opening on a
  different screen would move the broadcast without the broadcaster asking;
  the controller stays in `WaitingForDisplay` and reopens when the display
  comes back (T11).
- **The window signals ready only after its handler is installed**, so the
  first caption update always has somewhere to land.
- **An undecodable update is dropped whole.** A partial frame would be worse
  than a stale one, and caption text must never reach a log line: every log
  in this unit is a fixed string or a `runtimeType`.
- **The surface is always opaque**, even when the shipped config asks for
  translucency: it is shown to a room, not composited over a desktop.
- **`screen_retriever` is imported in exactly one file**, and the calling
  code reaches it through an interface, so the fence is structural rather
  than conventional.

## Deviations

1. **`selectDisplay` is a method, not a setter-lint violation.** The design
   names `void selectDisplay(String? id)`; the analyser's
   `use_setters_to_change_properties` would flag it, so the id lives in a
   small `_Selection` holder and the public signature and the single write
   path are unchanged.
2. **The production constructor of `DesktopMultiWindowService` is separate
   from the test seam** (`DesktopMultiWindowService()` versus
   `DesktopMultiWindowService.withEnumerator(...)`). The design used a single
   optional-parameter constructor marked `@visibleForTesting`, which made the
   production call site a lint warning — correct as a test seam, wrong as the
   production entry point.
3. **`OverlayWindowApp` builds its own `MaterialApp`.** The design described
   it as a widget taking a snapshot; because the shipped
   `CaptionDisplayWidget` is a Riverpod consumer and the sub-engine has no
   shell, the window owns its scope and theme. Behaviour is as specified
   (opaque, themed, positioned).
4. **The Windows and Linux runner callbacks are unverified locally.** They
   follow the plugin's published signatures, but neither toolchain is
   available here and the plugin's C headers are not vendored in this
   checkout, so their compilation is a CI check rather than a local one. The
   macOS callback is verified by the debug build.

## Unit 9 Manual Checks

- Plug a second display in and out while the output is on; the rows update
  and the window follows.
- Confirm the window is borderless on macOS, Windows and Linux.
- Confirm captions render on the external display in the shipped font, and
  that the surface is opaque.
- Confirm a theme change in the app reaches the window on the next frame.
- Confirm turning the output off does not disturb recognition, and that a
  pause keeps the window on screen.