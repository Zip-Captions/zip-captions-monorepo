# window_manager Dependency Record (SECURITY-10)

**Unit**: Unit 8 — External Display (S-20)
**Dependency**: `window_manager`
**Decision**: approved for `zip_broadcast` on 2026-10-19 by the run's human
decision (OQ-1, Option B), **conditional on this record**, per
`phase2-requirements.md` FR-9.5 ("Any new dependency needs human approval and a
supply-chain justification before it is added"). This document is that
justification.

**Read this first: what the dependency does and does not deliver here.**
Option B was chosen to give the pop-out window always-on-top and frameless
behaviour on Windows and Linux. Investigation during implementation showed the
pin this repo can use does **not** reach a `desktop_multi_window` sub-window.

- The only `window_manager` API that can address an arbitrary window is the
  0.6.0 native API (`Window.isAlwaysOnTop`, `titleBarStyle`,
  `isNonActivating`, `setParentWindow`, `nativeHandle`). 0.6.0 declares
  `sdk: ^3.13.0` and `flutter: ">=3.47.0"`, above this monorepo's floor
  (`>=3.10.0` / `>=3.38.0`; environment Dart 3.11.5 / Flutter 3.41.7). It is
  excluded for the same reason `screen_retriever` 0.3.0 is.
- 0.5.2, the newest version this repo can use, is **single-window**: one
  `MethodChannel('window_manager')`, and no method takes a window id. Its
  native plugins act on the app's own window (macOS: the main
  `FlutterWindow`; Windows/Linux: the runner's window). Calling
  `windowManager.setAlwaysOnTop(true)` from any engine therefore affects the
  main window, never the overlay.
- The sub-window's always-on-top on macOS is delivered by
  `desktop_multi_window`'s own `onWindowCreatedCallback` (ID-5), not by this
  dependency.

So the dependency is approved for the capability it *can* provide at this SDK
floor, and the platform gap it was expected to close is recorded as still open.
Approving Option B did not, by itself, deliver work item §8.8 item 15 on
Windows or Linux.

---

## 1. Why the dependency is wanted at all

The pop-out window must stay above other windows (`pip-ux-parity.md`
UX-PIP-11, §8.8 item 15) and should remove its own title bar (§8.8 item 13's
"frameless" reading, S-20's "borderless"). `desktop_multi_window` 0.2.1
creates the sub-window and offers `setFrame`, `setTitle`, `center`,
`resizable`, `show`, `hide`, `close`, `setFrameAutosaveName` and nothing about
stacking order or window style (`WindowController`, verified in the cached
source).

`window_manager` 0.5.2 is the maintained desktop-window package from the same
organisation as `desktop_multi_window`, it is already the de-facto standard for
this class of work in Flutter desktop apps, and its 0.5.x line runs inside the
SDK constraint this monorepo has today.

### The alternative that was rejected

Vendoring a patched `desktop_multi_window` (adding one method that calls
`gtk_window_set_keep_above` / `SetWindowPos(HWND_TOPMOST)` on the sub-window)
would actually deliver the feature on all three platforms and adds no
third-party surface. It is rejected because it puts native code we cannot build
on this machine (no Windows or Linux host) into the repo, which is the same
"untested native code" objection that rejected hand-written display
enumeration in `screen-retriever-security-10.md` §4. This is recorded so the
trade-off is visible: the dependency secures a maintained binary we do not
build; the patch secures the feature we cannot test.

---

## 2. Version decision

| Fact | Value | Source |
|---|---|---|
| Monorepo SDK floor | `>=3.10.0 <4.0.0`; Flutter `>=3.38.0` | repository root and `packages/zip_broadcast/pubspec.yaml` |
| Environment | Dart 3.11.5 / Flutter 3.41.7 | `dart --version`, `flutter --version` |
| `window_manager` 0.6.0 | `sdk: ^3.13.0`, `flutter: ">=3.47.0"`; deps `nativeapi ^0.5.2`, `nativeapi_flutter ^0.5.2` | repo `main` `pubspec.yaml` |
| `window_manager` 0.5.2 | `sdk: >=3.0.0 <4.0.0`, `flutter: >=3.3.0`; deps `flutter`, `path ^1.8.2`, `screen_retriever ^0.2.2` | pub.dev API metadata |
| `screen_retriever` pin in this unit | `^0.2.2` | `screen-retriever-security-10.md` §2 |

**Decision: pin `window_manager: ^0.5.2`.** It resolves below the SDK floor
problem, and its `screen_retriever ^0.2.2` constraint is satisfied by the pin
already chosen, so the two plugins agree by construction rather than by
resolution luck. `^0.5.2` cannot float into 0.6.x, which is the version that
would silently raise the SDK requirement.

**Upgrade path, recorded.** When the monorepo's SDK floor moves to Dart 3.13 /
Flutter 3.47 (the same move that would unlock `screen_retriever` 0.3.0), both
plugins should be upgraded in one commit and the sub-window always-on-top
re-pointed at `Window.isAlwaysOnTop` / `titleBarStyle`. That is a later unit's
decision; it is written down so the current pin is not read as a permanent
choice.

---

## 3. Supply-chain assessment

| Question | Finding |
|---|---|
| Maintainer and provenance | `leanflutter` organisation, the publisher of `desktop_multi_window` (already in the repo since Phase 1), `screen_retriever` (approved in this unit) and `launch_at_startup`, `local_notifier`. Public repository `leanflutter/window_manager`, MIT licensed, 1.13k likes / 160 pub points / ~814k downloads. |
| Release cadence | 42 published versions since 2021; the 0.5.x line has three releases (0.5.0 to 0.5.2), 0.5.2 published 2026-07-04. A 0.6.0 rewrite exists on `main` and is being migrated to `nativeapi`; it is not on pub.dev yet at the time of this record. |
| Transitive dependencies | `flutter`, `path` (Dart SDK team, already pervasive in the toolchain), `screen_retriever ^0.2.2` (already approved in this unit). No other tree. |
| Native code | Swift (macOS: `NSWindow` level, style mask, title bar), Win32 C++ (Windows: `SetWindowPos`, `DwmSetWindowAttribute`, frameless styles), GTK/X11 (Linux: `gtk_window_set_keep_above`, `gtk_window_set_decorated`). No dynamic code loading, no network access, no file access, no obfuscated blobs. |
| Permissions | None requested. No entitlement, manifest capability or sandbox exception is added. macOS window management needs no TCC permission. |
| Telemetry / data flow | None. The package has no networking code. It moves and decorates windows; it never sees caption text. |
| Supply-chain mitigations applied here | (1) pinned to `^0.5.2`, cannot float to the SDK-raising 0.6 line; (2) imported in **exactly one file**, behind a narrow interface, so the blast radius of a future compromise is one adapter; (3) the real plugin is never invoked in tests (fakes only), matching the project's no-native-stack-in-unit-tests rule; (4) no user input reaches it as anything but a boolean or a fixed string; (5) it is used only for window state, never as a data path. |
| What the package cannot do | It cannot read or write files, cannot reach the network, cannot inspect window contents, cannot enumerate other processes' windows, and cannot execute anything. Its API surface is window geometry, stacking and decoration. |
| Residual risk accepted | (a) A future 0.5.x patch could be compromised; mitigations (1) and (2) bound the effect to window decoration and one adapter. (b) The package is between major lines (0.6 migration in progress), so the 0.5.x line will eventually stop receiving fixes. That is accepted because the 0.6 line is unusable at this SDK floor, and the upgrade path is recorded above. (c) Most importantly: the dependency does **not** close the Windows/Linux gap it was added for, so this record buys a maintained window API for future use and for any main-window needs, not the §8.8 item 15 deliverable. That is an accepted cost, stated plainly rather than glossed. |

---

## 4. Alternatives considered and rejected

| Alternative | Why rejected |
|---|---|
| `window_manager` 0.6.0 | SDK floor (`^3.13.0` / Flutter 3.47) exceeds the monorepo's. Same exclusion logic as `screen_retriever` 0.3.0. |
| Vendor a patched `desktop_multi_window` | Native code we cannot build or test on this machine (see §1). |
| `bitsdojo_window` | Smaller maintainer base, no macOS/Linux parity comparable to this package, would not reach the sub-window either for the same single-window reason. |
| Do nothing (the previous OQ-1 Option A) | Still viable and was the earlier recommendation. The human chose B; this record documents what B actually yields at this SDK floor so that choice can be revisited with facts rather than an assumption. |
| Raise the monorepo SDK floor to Flutter 3.47 now | Out of scope for Unit 8 and would affect every package; recorded as the correct long-term path in §2. |

---

## 5. Confinement and verification obligations

Binding for Code Generation and review:

1. Exactly one file imports `package:window_manager/...`:
   `packages/zip_broadcast/lib/src/output/overlay/desktop_window_decorator_io.dart`.
   A second import anywhere in the package is a review finding.
2. Everything else depends on the platform-neutral `DesktopWindowDecorator`
   interface (`setAlwaysOnTop`, `setFrameless`), with `_stub` implementations on
   web and for unsupported platforms.
3. `pubspec.lock` gains `window_manager` 0.5.2 and, if not already present,
   `path`. `screen_retriever` and its four federated packages are the only other
   lockfile change this unit is allowed to make (see
   `screen-retriever-security-10.md` §5 item 3). Anything else is a
   resolution side-effect to report, not silently accept.
4. The adapter must be called only for the **main** window's needs. It must not
   be used in the sub-engine in an attempt to decorate the overlay: that call
   silently affects the wrong window, and a test must assert it is never made
   from `OverlayWindowApp`.
5. No `// ignore` comment is used to satisfy the analyzer around the plugin.
6. The Windows/Linux always-on-top gap for the **sub-window** stays recorded in
   ID-5 and §8.8 item 15 remains a Unit 9 manual item. This record does not
   claim otherwise.