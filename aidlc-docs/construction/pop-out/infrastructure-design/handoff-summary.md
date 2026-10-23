# Handoff: Infrastructure Design -> Code Generation
**Unit**: pop-out (Unit 8.1, S-21)
**Date**: 2026-10-21 (unattended run; approved by the run configuration per `.agent/overnight-pipeline.md`, subject to morning review)

## Decisions Made
- ID-1: `runZipCaptions(args, {runApp, isWeb})` in `zip_captions/lib/src/bootstrap.dart` is authoritative; `main(List<String> args)` delegates to it in one line; the overlay branch returns before `GoogleFonts.config`, logging, `SharedPreferences`, `Supabase.initialize`, the `ProviderContainer` and the debug `FakeSttEngine`. FD BLM §4.4's snippet is that function's body. `zip_broadcast` keeps its inline branch (deliberate asymmetry).
- ID-2a (sub-engine, `zip_core/overlay_window_configure`): registered inside the existing window-created callback on the sub-engine's own registrar; allowlist-by-type validation (`windowId` int >= 0, `floating`/`decorated` bool, `minWidth`/`minHeight` finite >= 0) else `FlutterError('configure_invalid')`; platform: macOS `level`/`styleMask`/`contentMinSize`, Windows `HWND_TOPMOST`/style bits + `SWP_FRAMECHANGED`/`WM_GETMINMAXINFO`, Linux `gtk_window_set_keep_above`/`set_decorated`/`gtk_widget_set_size_request`. All styling moves here; runners become mode-blind-free.
- ID-2b (main engine, `zip_core/overlay_sub_window_events`): registered once in main-window setup (macOS `awakeFromNib`, Windows `OnCreate`, Linux `my_application_activate`), fire-and-forget `subWindowClosed {windowId}` (null result callback, never block the close path); Dart validates method name + single non-negative int map key, silent drop.
- ID-3 (per-runner close-id map, native-only): keyed by native handle — macOS `ObjectIdentifier(NSWindow)` via `NSWindow.willCloseNotification` observer, Windows `HWND` via `RegisterTopLevelWindowProcDelegate` on the sub-engine's registrar (`WM_CLOSE` before the plugin's branch, returns `nullopt`/`null` so the plugin still closes), Linux `GtkWindow*` via `"destroy"` (NOT `delete-event`: the plugin's handler returns `TRUE` and aborts the signal). Populated only by `configure`, which always precedes `overlayReady` and `show()`.
- ID-4: `tech-stack-decisions.md` §3's "generated, not committed" fence is wrong — the ten registrant files are tracked. Movement is specified exactly: `zip_broadcast` **loses** `screen_retriever_*`, `zip_captions` **gains** `desktop_multi_window` + `screen_retriever_*`. Files are tool-generated, never hand-edited.
- ID-5: no dependency change beyond the approved set — `zip_core` and `zip_captions` add `desktop_multi_window: ^0.2.1` (`^0.2.0` in three approved artifacts corrected to `^0.2.1`); `zip_broadcast` drops `screen_retriever`; `window_manager` stays absent; no `dev_dependencies` change; no CI change.

## Key Entities / Components
| Name | Type | Constraint for Code Generation |
|---|---|---|
| `runZipCaptions(List<String> args, {runApp, isWeb})` | bootstrap seam (`zip_captions`) | overlay branch before all app init; one-line `main` |
| Runners (six files) | native | no new source file; edits inside the existing window-created callback / `OnCreate` / `my_application_activate` and the main-window setup |
| `zip_core/overlay_window_configure` | `MethodChannel`, sub-engine | `configure`, five args, `configure_invalid` |
| `zip_core/overlay_sub_window_events` | `MethodChannel`, main engine | `subWindowClosed`, `{windowId: int}` |
| `closeIds` map | native runner state | handle -> windowId; written by `configure`, read and erased by the close hook |

## Constraints
- Missing `MainFlutterWindow.swift`, `flutter_window.cpp`, `my_application.cc` on both apps; `#include <desktop_multi_window/desktop_multi_window_plugin.h>` / `import desktop_multi_window` added where absent (`zip_captions` all three).
- Never call the generated registrant from a window-created callback (R-B1); never replace the plugin's `NSWindowDelegate` or `WndProc` (R-B2); Linux hook is `"destroy"`.
- Preserve `RegisterPlugins`/`fl_register_plugins`/`RegisterGeneratedPlugins` order and the `WM_FONTCHANGE` branches in both existing runners.
- Windows evidence is compile-only (`flutter_windows.h` absent on macOS — CI is the check); macOS compiles at Part 2; float/decoration/min-size/OS-close/multi-monitor are Unit 9 manual checks — record, do not claim.
- Runners log nothing; `windowId` never interpolated into a log line; `configure_invalid` carries no field values.
- Gates: `dart analyze --fatal-infos` then `flutter test` in `zip_core`, `zip_broadcast`, `zip_captions`.

## Open Questions for Next Stage
- None. `windows/include/desktop_multi_window/desktop_multi_window_plugin.h` and the `flutter_windows.h` symbol set are the one compile-only surface; if CI rejects the delegate shape, the fallback is `SetWindowLongPtr(GWLP_WNDPROC)` subclassing with the plugin proc chained — report, do not improvise.
- Unit 9 manual checks into the PR body: decoration/resize/move/float (1-3), OS close clears banner + toggle in the same frame — **no Linux degradation recorded** (4), external display still borderless after the `configure` move (5), multi-monitor (6).