# Tech Stack Decisions — Unit 8.1: Pop-out Live Captions (S-21)

**Status**: APPROVED 2026-10-21 by James Petersen (revised after the pre-build review: RQ-1 A / RQ-2 A / RQ-3 A-amended; revision 2 same day).
**Answers carried**: Q1 A, Q2 A, Q3 A, Q4 A, Q5 A, Q6 A, Q7 A, Q8 A, Q9 A, Q10 A, Q11 A, Q12 A,
clarification Q1 A.

---

## 1. Dependency placement (Q2 A)

| Package | Dependency | Change | Version | Justification |
|---|---|---|---|---|
| `zip_core` | `desktop_multi_window` | **new** | `^0.2.0` | The promoted window service and bridge need it, behind the `_io` fence. Same constraint `zip_broadcast` already ships. |
| `zip_core` | `screen_retriever` | **new** | `^0.2.2` | The promoted display enumerator needs it. The pin is chosen for the monorepo floor (0.3.0 needs Dart 3.13 / Flutter 3.47), exactly as `zip_broadcast`'s comment records. |
| `zip_core` | `window_manager` | **not added** | — | **Withdrawn 2026-10-21 (RQ-1 A).** Its macOS `ensureInitialized` replaces `desktop_multi_window`'s window delegate, which is the only path from an OS close to `shutDownEngine()` (R-B2), and it cannot restore the decoration the runners strip (R-B3). Replaced by a first-party native `configure` channel. |
| `zip_broadcast` | `desktop_multi_window` | unchanged | `^0.2.0` | Its runners compile against the plugin; it also has no reason to stop declaring it. |
| `zip_broadcast` | `screen_retriever` | **removed** | — | After the move nothing in the app imports it. SECURITY-10 forbids unused dependencies. |
| `zip_broadcast` | `window_manager` | **not added** | — | Not a dependency of anything (RQ-1 A). |
| `zip_captions` | `desktop_multi_window` | **new** | `^0.2.0` | Its first windowing: `main` routing, the sub-engine entry, the runner callbacks. |
| `zip_captions` | `window_manager` | **not added** | — | Same: withdrawn entirely. |
| `zip_captions` | `screen_retriever` | **not declared** | — | No app import; it arrives through `zip_core`. |

**Why the apps omit `screen_retriever`.** Flutter resolves native plugins from the whole package
graph, not from the app's own `dependencies` list: `zip_core` is a path dependency, so the
`screen_retriever_*` federations are linked into each app's build regardless. Declaring them in an
app would add a dependency with no call site (SECURITY-10: no unused dependencies). This is also why
`zip_broadcast`'s `Podfile.lock` keeps `screen_retriever_macos` after the app drops *its own*
declaration — R-M10.
The one exception is `desktop_multi_window` in `zip_broadcast`, which is kept only because its
runners include the plugin's headers directly and the declaration documents that coupling; the same
argument now applies to `zip_captions`, so it declares it too.

**Rejected alternatives**:
- All three in all three packages (Q2 B): unused declarations, which SECURITY-10 names explicitly.
- `window_manager` in both apps (Q2 C): moot — the dependency was withdrawn entirely.
- Keeping `window_manager` and *also* a native channel (RQ-1 B): two mechanisms for one property,
  and the macOS delegate replacement (R-B2) would still happen because the plugin would still be
  initialised. Rejected.

---

## 2. Plugin registration per platform (Q1 A)

| Platform | File | Call added | Precedent |
|---|---|---|---|
| macOS | `macos/Runner/MainFlutterWindow.swift` | **no plugin registration.** The callback registers only the app's own `configure` `FlutterMethodChannel` on `controller.registrar(forPlugin: …)`; the unconditional borderless `styleMask` removal moves into that channel's `configure` handler | the plugin's own example registers exactly one **named** plugin per callback (`example/macos/Runner/MainFlutterWindow.swift:15-18`) |
| Windows | `windows/runner/flutter_window.cpp` | the callback (corrected to the plugin's real one-argument signature, R-B4) registers only the app's own `configure` channel; the shipped `GWL_STYLE` stripping moves into its `configure` handler | `example/windows/runner/flutter_window.cpp:32-38` registers one named plugin |
| Linux | `linux/runner/my_application.cc` | the callback (corrected signature, R-B4) registers only the app's own `configure` channel; `gtk_window_set_decorated(FALSE)` moves into its `configure` handler | `example/linux/my_application.cc:65-69` registers one named plugin |
| `zip_captions` (all three) | as above | the whole callback is **new** in each of its three runners (it has none today) | `zip_broadcast`'s shipped runners |

**R-B1 corrected the draft**: `RegisterGeneratedPlugins` must **never** be called in the
window-created callback. It reaches `FlutterMultiWindowPlugin.register(with:)`, which calls
`MultiWindowManager.shared.attachMainWindow(window:mainWindowChannel:)`, and that assigns
`windows[0]` on the **sub-engine's** messenger (`FlutterMultiWindowPlugin.swift:8-23`,
`MultiWindowManager.swift:29-33`). After the first sub-window, every `invokeMethod(0, …)` — the
pop-out's `overlayReady` and `popOutToggle`, and Unit 8's external-display `overlayReady` — lands
back inside the sub-engine, so every open ends in `ready_timeout` and the shipped external display
stops working for the rest of the app's life. The draft's claim that the plugin's example does this
was also false: the examples register one named plugin.
Also corrected: `RegisterGeneratedPlugins(registry: controller.view)` does not type-check (the
registry is the `FlutterViewController`), and the reason given for rejecting Q1 B was wrong — the
example imports the plugin's own public module and registers a public symbol.

**Verification**: macOS by `flutter build macos --debug` plus a Unit 9 manual check of the floating
behaviour; Windows and Linux by CI's `build-verify.yml` compile only. Stated as such, not claimed.

---

## 3. Lockfile and generated-file fence

`pubspec.lock` movements expected, in full:

| File | Entries added | Entries removed | Anything else |
|---|---|---|---|
| `pubspec.lock` (workspace) | none | none | **R-M10**: the draft's `window_manager` entry does not exist, because 0.5.1 is a single package, not federated (`pubspec.yaml:31-32`); with RQ-1 A it is not added at all |
| `packages/zip_broadcast/macos/Podfile.lock` | none | none | **R-M10**: `screen_retriever_macos` **stays** (`:19,99,124`). The draft's "−" row was wrong: the plugin still reaches the app through `zip_core` |
| `packages/zip_captions/macos/Podfile.lock` | `desktop_multi_window`, `screen_retriever_macos` | none | none |

The draft's `window_manager_macos` entries were fabricated — there is one
`macos/window_manager.podspec`, not a federation. As written, the fence would have stopped the build
on a false "unexpected lockfile movement".

Generated, not committed, listed so the build evidence can be read: each app's
`windows/flutter/generated_plugins.cmake`, `linux/flutter/generated_plugin_registrant.cc` and
`macos/Flutter/GeneratedPluginRegistrant.swift`.

**Rule**: any other movement is reported in the code summary, not committed silently. This mirrors
Unit 8's `screen_retriever` fence.

---

## 4. Test stack

| Need | Choice | Why not the alternative |
|---|---|---|
| Fakes for window service / enumerator / handler installer / always-on-top / bridge | hand-written fakes in `zip_core/test/helpers/` | `mocktail` mocks are the project's choice where a collaborator has no behaviour to script; these five all record ordering or push events, which is the hand-written-fake pattern Unit 5-8 use |
| Property testing | in-tree `test/helpers/pbt.dart` shim, copied to `zip_core/test/helpers/pbt.dart` | `glados` is incompatible with Dart 3; the shim is the project decision (Unit 7) and Unit 8 already relies on it |
| Async timing | `fake_async` | already a dev dependency of all three packages |
| App-level widget tests | `flutter_test` + the per-app harnesses (`zb_test_harness.dart`, Zip Captions' existing helpers) | no new framework |

No new dev dependency is introduced.

---

## 5. Rejected designs (with reasons)

| Rejected | Why |
|---|---|
| Declare `window_manager` in the apps (Q2 C) | moot: not a dependency of anything (RQ-1 A) |
| Register only `window_manager` on macOS (Q1 B) | moot: the dependency is withdrawn, and the generated registrant is actively harmful (R-B1) |
| A separate bridge channel for the pop-out (Q3 C) | a second channel is a second thing to secure, version and test; the shipped bridge plus a payload-free message is strictly smaller |
| Treat an always-on-top failure as `OpenFailed` (Q8 B) | turns a working window into an error dialog |
| `WindowOptions(alwaysOnTop: true)` through `waitUntilReadyToShow` (FD Q4 C) | `waitUntilReadyToShow` is designed for the main window lifecycle; in a sub-engine the window is created and shown by `desktop_multi_window`, so the option would race the plugin's own `show` |
| Keeping `window_manager` and adding the native close hook only (partial RQ-1 B) | The delegate replacement (R-B2) is caused by `ensureInitialized`, not by the always-on-top call, so it still happens. Only removing the dependency removes the defect. |
| A per-window method channel in the runner keyed by id, with the sub-engine calling a handler that targets another window | The runner's channel is bound to the sub-engine's messenger; it can only act on the window whose view it was created with. The `windowId` parameter is for tagging the close event, not for addressing other windows. |
| A startup-time budget for the pop-out engine (Q7 B) | there is no measurement infrastructure for it; the ready timeout already bounds the user-visible wait |
| One shared `PopOutCaptionTarget` with an injected reader (Q6 B) | the approved FD shape (Q5 A) keeps the adapter app-local; the matching-test constraint is the cheaper guard, and B can be a later refactor if the two files ever diverge in behaviour |

---

## 6. Tech stack table (delta only)

| Concern | Choice | Version |
|---|---|---|
| Window creation | `desktop_multi_window` | `^0.2.0` |
| Always-on-top, decoration, minimum size | first-party `configure` `MethodChannel` per runner | n/a (our code) |
| Display enumeration | `screen_retriever` | `^0.2.2` |
| Error/exception handling | existing `try`/`on Object` + `Logger` | unchanged |
| Logging | `package:logging`, fixed strings | unchanged |
| State management | Riverpod (`@riverpod` / hand-written `Provider`) | unchanged |
| Immutable models | `freezed` (`OverlayConfig`, `DisplayInfo`) | unchanged |
| Persistence | **none added** (Q10 B) | — |
| Native code | runner callbacks only, no new source files | — |