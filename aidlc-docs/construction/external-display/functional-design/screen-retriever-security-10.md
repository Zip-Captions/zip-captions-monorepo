# Screen Retriever Dependency Record (SECURITY-10)

**Unit**: Unit 8 — External Display (S-20)
**Dependency**: `screen_retriever`
**Decision**: approved for `zip_broadcast` on 2026-10-19, **conditional on this
record**, per `phase2-unit-of-work.md` Unit 8 and FR-9.5. The condition — a
supply-chain justification — is this document.

---

## 1. Why a new dependency is needed at all

FR-9.6 records that Phase 1 already shipped the window side of this feature:
`desktop_multi_window: ^0.2.0` creates the secondary native window, and
`CaptionOverlayTarget` already carries `OverlayConfig.targetDisplayId`. What
Phase 1 never had is the ability to **list connected displays** and detect
**connect/disconnect**. `desktop_multi_window` 0.2.1 exposes no display
enumeration: `WindowController` offers `setFrame`, `center`, `setTitle`,
`resizable`, `setFrameAutosaveName`, `show`, `hide`, `close`, and nothing else
(verified against the cached package source). The platform channels it installs
have no display-name method. So S-20's "all connected displays are listed and
one can be selected" and "the selected display is disconnected" cannot be met
without either a new Dart-side plugin or hand-written native code in three
runners.

Hand-written native enumeration would be macOS `NSScreen.screens` +
`NSApplication.didChangeScreenParametersNotification`, Windows
`EnumDisplayMonitors`/`GetMonitorInfo`, and Linux X11/RandR or GDK monitor
discovery — three native implementations, three build-verification surfaces,
and no test reachability at all. That is strictly more supply-chain surface
(our own untested C/Swift) for the same result. `screen_retriever` is the
maintained, narrowly-scoped option the Application Design already fixed
(plan Q6:A, `phase2-application-design.md` line 16).

---

## 2. Version decision

The binding decision for this run says 0.3.0 requires Dart 3.13 / Flutter 3.47,
and that if the monorepo SDK constraint does not satisfy it we pin 0.2.x and
use the legacy API.

**Checked, in this order:**

| Fact | Value | Source |
|---|---|---|
| Monorepo SDK floor (`pubspec.yaml` workspace) | `>=3.10.0 <4.0.0` | repository root |
| `zip_broadcast` SDK floor | `>=3.10.0 <4.0.0`, Flutter `>=3.38.0` | `packages/zip_broadcast/pubspec.yaml` |
| SDK Dart available to the analyzer in this environment | 3.11.5 | `dart --version` |
| Flutter available | 3.41.7 | `flutter --version` |
| `screen_retriever` 0.3.0 environment | Dart `^3.13.0`, Flutter `>=3.47.0` | pub.dev package metadata |
| `screen_retriever` 0.3.0 dependencies | `nativeapi`, `nativeapi_flutter`, `plugin_platform_interface` | pub.dev package metadata |
| `screen_retriever` 0.2.2 environment | Dart `>=3.0.0 <4.0.0`, Flutter `>=3.3.0` | pub.dev package metadata |
| `screen_retriever` 0.2.2 dependencies | `flutter`, `screen_retriever_linux`, `screen_retriever_macos`, `screen_retriever_platform_interface`, `screen_retriever_windows` | pub.dev package metadata |

3.13.0 > 3.10.0 and 3.47.0 > 3.38.0. **0.3.0 is excluded by the monorepo's own
SDK constraint**, and it would additionally pull in `nativeapi` /
`nativeapi_flutter` — a second-order supply-chain surface that the 0.2.x line
does not have.

**Decision: pin `screen_retriever: ^0.2.2`.**

`^0.2.2` resolves to the latest 0.2.x and cannot float into 0.3.x. The
pre-0.3 API is the one this unit uses. There is no `legacy.dart` import in
0.2.x — that shim exists only inside 0.3.0 for its renamed API — so the "use
legacy.dart" half of the binding decision does not apply under this pin. The
0.2.x surface used is:

```dart
import 'package:screen_retriever/screen_retriever.dart';
// ScreenRetriever.instance.getAllDisplays() -> Future<List<Display>>
// ScreenRetriever.instance.addListener(ScreenListener) / removeListener(...)
// ScreenListener.onScreenEvent(String eventName) -> void
//   eventName is 'display-added' or 'display-removed'; no payload
// Display { id, name, size, visiblePosition, visibleSize, scaleFactor }
```

**The 0.2.x change signal has no notifier.** There is no
`displayChangedNotifier` in 0.2.2 (that is a 0.3-only API). The 0.2.x model is a
listener mixin: `ScreenRetriever.instance.addListener(myListener)` where
`myListener` is a class with `onScreenEvent(String)`. The event carries only
the *kind* of change (`display-added` / `display-removed`), never a display
list and never the changed display's id, so the adapter must re-call
`getAllDisplays()` and diff. The platform sources were read to confirm the
event names are identical on all three backends
(`screen_retriever_macos/.../ScreenRetrieverMacosPlugin.swift:96-105`,
`screen_retriever_windows/windows/screen_retriever_windows_plugin.cpp:90-96`,
`screen_retriever_linux/linux/screen_retriever_linux_plugin.cc:165-170`). The
three backends also report the event differently on the way out (macOS's
`didChangeScreenParametersNotification` fires for resolution changes as well as
add/remove; Windows and Linux fire only on add/remove), so the adapter treats
*every* event as "re-read the list and diff", which is also the only way
re-arrangement is observed (see `domain-entities.md` coordinate note).

**Deprecation check (corrects Infrastructure Design ID-3).**
`ScreenRetriever.instance` is **not deprecated** in 0.2.2
(`screen_retriever/lib/src/screen_retriever.dart:9` declares it without a
`@Deprecated`). Infrastructure Design ID-3 states the 0.2.x entry point is
deprecated and shapes its conditional-export form around that; the claim is
**not applicable under this pin** and must be corrected when Infrastructure
Design is re-run (per D-10 it is a later stage). The conditional-export
obligation itself (this record §5 item 4) stands regardless.

That surface is confined to `screen_retriever_display_enumerator_io.dart`; see
§5 item 1.

---

## 3. Supply-chain assessment

| Question | Finding |
|---|---|
| Maintainer and provenance | `leanflutter` organisation (the Flutter desktop plugin group behind `window_manager`, `launch_at_startup`, `desktop_drop`, `local_notifier` and similar). Public GitHub repository `leanflutter/screen_retriever`, MIT licensed. |
| Release cadence | 16 releases from 0.0.1 to 0.3.0 (counted against the pub.dev release list, verified 2026-10-20); the 0.2.x line has three patch releases (0.2.0-0.2.2), each a federated-platform bump. |
| Federated structure | 0.2.x splits into `screen_retriever_platform_interface`, `_macos`, `_windows`, `_linux`. Each is a small, separately-versioned package under the same organisation. All are pinned by the 0.2.x resolution. |
| Native code | Swift (macOS), C++ (Windows, Linux). No dynamic code loading, no network access, no file access outside the platform's own display APIs, no obfuscated blobs. The macOS side reads `NSScreen`; the Windows side calls `EnumDisplayMonitors`; the Linux side reads the X11/GDK monitor list. |
| Permissions | None requested. No entitlement is added to the macOS runner, no manifest capability is added on Windows, no `dlopen` of system frameworks beyond those already linked by the Flutter runner. |
| Telemetry / data flow | None. The plugin's only output is a list of display descriptors, which are local OS facts. Nothing is sent anywhere, and nothing about it is caption content. |
| Transitive dependencies | 0.2.2's five dependencies are the Flutter SDK plus its own four federated sub-packages. No third-party transitive tree. |
| Supply-chain mitigations applied here | (1) version range pinned to `^0.2.2`, cannot float to the unapproved 0.3 line; (2) **the plugin is imported in exactly one file**, behind `DisplayEnumerator`, so the blast radius of a future compromise or breaking change is one adapter; (3) the adapter is exercised only through a fake in tests — the real plugin is never invoked in the suite, matching the project's "no real native stack in unit tests" rule (Unit 5 NFR Requirements Q5 precedent); (4) no configuration value from user input reaches the plugin; (5) the plugin returns data, it does not accept commands. |
| What the plugin cannot do | It cannot open, close, resize or raise windows (`desktop_multi_window` owns that), cannot read captions, cannot store anything, and cannot reach the network. The dependency is read-only display metadata. |
| Residual risk accepted | A future compromise of the leanflutter organisation could ship a malicious 0.2.x patch release. Mitigations (1)-(3) bound the effect to display metadata and one adapter; the version range does not auto-upgrade across a major. This is the same residual risk class as any federated Flutter desktop plugin and is accepted for the same reason `desktop_multi_window` was accepted in Phase 1. |

---

## 4. Alternatives considered and rejected

| Alternative | Why rejected |
|---|---|
| Hand-written native enumeration in all three runners | Three untested native codebases; more surface than the plugin; no unit-test reachability; violates the project's "no hand-written native code without a real build to verify it" posture set in Unit 2's Linux OAuth decision. |
| Derive display geometry from `desktop_multi_window`'s `setFrame`/window events | The plugin reports nothing about displays. A window can be placed only if its target rectangle is already known; that is the missing input, not the output. |
| `window_manager` | Pulls a second full window-management plugin with overlapping responsibilities (it also creates/manages windows), which would compete with `desktop_multi_window` for the same native window. Its display API is `screen_retriever` re-exported. |
| `display_info` / `flutter_display_info` | Smaller, less-maintained alternatives; neither has the three-platform federation or the maintainer track record. Choosing between them would be a coin flip; the Application Design already fixed `screen_retriever`. |
| User-entered window coordinates only (no enumeration) | Directly contradicts S-20 AC1 ("all connected displays are listed and one can be selected") and Proto-13's display list. |

---

## 5. Confinement and verification obligations

These are binding for Code Generation and for review:

1. Exactly one file imports `package:screen_retriever/...`:
   `packages/zip_broadcast/lib/src/output/overlay/screen_retriever_display_enumerator_io.dart`.
   A second import anywhere in the package is a review finding. The sibling
   `screen_retriever_display_enumerator.dart` is the conditional export and
   `screen_retriever_display_enumerator_stub.dart` is the non-io adapter; neither
   imports the plugin (the `_io` file is only *listed* in the export's
   conditional URI, which is not an import of the plugin, and `_io` is the only
   file where the plugin symbol is named).
2. Every other type in the unit depends on `DisplayEnumerator`, `DisplayInfo`
   or `OverlayWindowMode` — never on the plugin.
3. `pubspec.yaml`/`pubspec.lock`: the root `pubspec.lock` gains
   `screen_retriever`, `screen_retriever_linux`, `screen_retriever_macos`,
   `screen_retriever_platform_interface` and `screen_retriever_windows`. Those
   five lock entries are the only lockfile change this unit is allowed to make.
   Anything else that moves in the lock is a resolution side-effect and must be
   reported in the PR, not silently accepted.
4. The package compiles for web: the adapter file must be picked by the same
   conditional-export pattern the shipped `desktop_multi_window_service.dart`
   uses, so `dart analyze` and `flutter test` for `zip_broadcast` (which run on
   the host) never load the plugin on an unsupported target. The exact shape is
   settled in Infrastructure Design (ID-3).
5. No `// ignore` comment is used to satisfy the analyzer around the plugin.