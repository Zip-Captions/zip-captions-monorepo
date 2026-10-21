# Window Manager Dependency Record (SECURITY-10)

**Unit**: Unit 8.1 — Pop-out Live Captions (S-21)
**Dependency**: `window_manager`
**Decision**: approved for `zip_broadcast` on 2026-10-20 by the project owner. No
further condition is attached; this document is the supply-chain justification
`docs/04-technical-specification.md` Section 6 requires, and the record SECURITY-10
expects for a new dependency.

**Approval history**: `window_manager` was proposed and recorded for Unit 8 on
2026-10-19 (OQ-1 Option B, commit `6f4eaea`) for always-on-top on the external
display window, then **removed** by the PR #37 review (D-13) because Unit 8's window
is framed to a display's work area and does not need to float above other
applications. It is reintroduced here for the opposite reason: Unit 8.1's pop-out
window exists specifically to float above other applications. Unit 8 remains free of
it; this record covers Unit 8.1 only.

---

## 1. Why a new dependency is needed at all

S-21's core acceptance criterion is that the pop-out window "remains above that
application's window" when the user activates any other application. That is not a
styling preference; it is the feature. A pop-out that falls behind the user's editor
or presentation software is not a pop-out.

**`desktop_multi_window` cannot provide it.** Verified by reading the shipped 0.2.1
sources rather than the README: there is no `alwaysOnTop` setter, no window-level or
`HWND_TOPMOST` call, and no `gtk_window_set_keep_above` call on any of its three
backends (`macos/Classes/MultiWindowManager.swift`, `windows/multi_window_manager.cc`,
`linux/multi_window_manager.cc`). `WindowController` exposes `setFrame`, `center`,
`setTitle`, `resizable`, `setFrameAutosaveName`, `show`, `hide`, `close` and the codec
style calls, and nothing else. Step 1 of the Section 6 approval process ("check if an
existing dependency already provides it") is therefore answered: it does not.

The remaining alternative is hand-written native code in all three runners — macOS
`NSWindow.level`, Windows `SetWindowPos(HWND_TOPMOST)`/`WM_ACTIVATE`, Linux
`gtk_window_set_keep_above` plus WM-protocol handling. That is three untested native
implementations and three build-verification surfaces, against one maintained plugin
that already does exactly this. It is strictly more supply-chain surface, not less.

## 2. What the package does, and the verified API

`window_manager` (leanflutter, MIT) is the standard Flutter desktop window-control
plugin. The specific API this unit relies on:

| API | Verified behaviour |
|---|---|
| `setAlwaysOnTop(bool)` | No platform exclusion. Documented on the API reference without a platform tag, unlike neighbouring methods which carry `macos`, `windows` or `linux` tags. |
| `WindowOptions.alwaysOnTop` | Constructor field (nullable `bool`), applied in `waitUntilReadyToShow`. |
| `isAlwaysOnTop()` | Read-back, useful for a Unit 9 verification and for a test double. |

**Platform mechanisms** (the documented effect of the call): macOS `NSWindow.level`
(`NSFloatingWindowLevel`), Windows `SetWindowPos(HWND_TOPMOST)`, Linux
`gtk_window_set_keep_above`. All three are the platform's own "above normal windows"
primitive, which is what S-21 asks for.

**Documented limitation, accepted 2026-10-20**: on macOS the window floats above
normal windows but not above another application's full-screen window.
`window_manager`'s own docs note that floating above a full-screen window on another
screen requires the window class to inherit `NSPanel`. The project owner accepted the
limitation for Phase 2 and the `NSPanel` work is recorded in Backlog rather than
claimed. This is a functional limitation, not a security one.

## 3. Where the call must run

`windowManager` is a single-instance global bound to the main window of the process
that initialises it. The pop-out window is created by the app's sub-engine, which is a
separate Flutter engine and a separate Dart isolate (Unit 8's `OverlayWindowEntry`
contract). The `ensureInitialized()` + `setAlwaysOnTop(true)` sequence must therefore
execute **inside the sub-engine**, not in the main window's isolate, or it would
address the wrong native window. This is a design constraint for Functional Design and
a review point for Code Generation; it does not change the dependency decision.

## 4. Version, licence and maintenance

| Fact | Value | How checked |
|---|---|---|
| Requested pin | `^0.5.1` | docs-mcp `window_manager@0.5.1` quick start, current pub.dev version |
| Licence | MIT | pub.dev package page |
| Maintainer | leanflutter (verified publisher) | pub.dev package page |
| Scope | window control only; no network, storage or telemetry | API surface read in full; every method is a window operation |
| Transitive dependencies | none beyond `flutter` for the plugin itself | pub.dev dependencies listing |

`^0.5.1` follows the Section 6 caret convention. Exact pinning is not warranted: no
known-broken version is being avoided.

## 5. Supply-chain (SECURITY-10) assessment

- **Data egress**: none. The plugin calls platform window APIs through a method
  channel. There is no network client, no analytics, no crash reporting, no file
  access. It cannot observe caption text; it only receives booleans and geometry.
- **Transcript constraint (`AGENTS.md`, SECURITY-03)**: unaffected. The plugin never
  sees caption payloads; `setAlwaysOnTop` carries a `bool`.
- **Import fence**: to be restated in Unit 8.1's Functional Design in the same shape
  as Unit 8's `screen_retriever` fence — the plugin is imported only by the pop-out
  sub-engine's window setup, never by `zip_core` and never by the caption pipeline.
- **Platform configuration**: `window_manager` must be registered in each desktop
  runner. **Decided 2026-10-20**: registration happens in the `desktop_multi_window`
  **window-created callback**, which every runner already installs, rather than by
  adding the plugin to Unit 8's deliberately-empty sub-engine plugin list (ID-1). The
  callback receives the created window's `FlutterViewController` on macOS, `FlView` on
  Linux, and the created window on Windows, so it can register the plugin against that
  engine before the window is shown, keeping ID-1's invariant intact. Unit 8.1 extends
  the existing callbacks; the Dart-side `setAlwaysOnTop` call still runs inside the
  sub-engine, because the plugin's channel only exists once registration has happened.
- **Lockfile footprint**: `window_manager` plus its federated entries
  (`window_manager_*` platform implementations, if any are published separately).
  Unit 8.1's plan must fence the lockfile change exactly as Unit 8 fenced
  `screen_retriever`.

**Verdict**: Approved. The dependency is the smallest available way to meet a
release-gate acceptance criterion, it is MIT-licensed, actively maintained, has no
transitive weight and cannot observe transcript content.

## 6. Consequences for other artifacts

- `docs/04-technical-specification.md` Section 6 gains an approved-dependency row with
  this rationale, so future units do not re-litigate it.
- Unit 8's records stay as written: `window_manager` is absent from Unit 8 and its
  D-13 reasoning (framed to a display work area; no floating needed) remains correct.
  This is not a reversal of D-13; it is a different window with a different requirement.
- `pip-ux-parity.md` §8.1 carries the verified always-on-top note for the UX contract.