# NFR Requirements Plan — Unit 8.1: Pop-out Live Captions (S-21)

**Unit**: 8.1 — Pop-out Live Captions (PiP)
**Story**: S-21 (`pip-ux-parity.md` §8 binding; §8.8 evidenced per app)
**Stage**: NFR Requirements (Stage 2 of 6)
**Inputs**: the Functional Design artifacts and `handoff-summary.md` (read first, per
`aidlc-project-rules/construction/stage-handoff.md` Rule 2)
**Branch**: `feature/popout-live-captions`

---

## What this stage must settle

The FD fixed the shapes. This stage fixes the numbers, the test strategy, the security posture and
the dependency decisions that the design must then be built to. Four things are specific to this
unit and are not covered by reusing Unit 8's answers:

1. **Dependency placement.** `zip_core` gains three plugins (`desktop_multi_window`,
   `screen_retriever`, `window_manager`). The apps gain `desktop_multi_window` (Zip Captions) and
   may lose `screen_retriever` (Zip Broadcast). Whether the apps declare `window_manager` directly,
   and how the lockfile movement is fenced, is a supply-chain decision (SECURITY-10), not a design
   one.
2. **The `OverlayMethodRouter` is new logic.** It is the only code in this unit that does not
   exist in shipped form, and it sits between two working features. Its test strategy decides
   whether a silent regression of the external display is detectable.
3. **The `AlwaysOnTopInstaller` is untestable in kind.** It calls a plugin that does nothing
   observable in a unit test. What the suite can honestly assert, and what must be a Unit 9 manual
   check, needs deciding rather than discovering later.
4. **Two apps, one contract.** §8.8 requires per-app evidence. The NFR answer has to say how the
   suite is organised so that "passing in one app" cannot be mistaken for "done".

Everything else (coalescing cadence, ready timeout, redaction discipline, no-retry policy,
logging levels, the in-tree PBT shim) is inherited from Unit 8 and should be restated, not
re-derived.

---

## Plan steps

- [ ] Step 1: Read the FD handoff summary, then the four FD artifacts (Rule 2)
- [ ] Step 2: Write this plan and its questions; verify every dependency claim against the pub cache and the shipped pubspecs before asking
- [ ] Step 3: Collect answers; resolve ambiguity or contradiction with a clarification file
- [ ] Step 4: Write `nfr-requirements.md` (testability, performance, reliability, security, maintainability, usability, observability; each with concrete numbers or a concrete strategy)
- [ ] Step 5: Write `tech-stack-decisions.md` (dependency placement per package, versions, fences, lockfile expectations, rejected alternatives)
- [ ] Step 6: Security Baseline compliance table (SECURITY-01..15) with blocking findings called out
- [ ] Step 7: PBT compliance table (PBT-01..10) against the FD's POP-1..POP-8 properties
- [ ] Step 8: Write `handoff-summary.md` (NFR Requirements -> NFR Design)
- [ ] Step 9: Present for approval and stop

---

## Verified before asking (2026-10-21)

| Claim | Verified how |
|---|---|
| `window_manager` latest is 0.5.2; `^0.5.1` resolves to it | `pub.dev` API (`/api/packages/window_manager`) |
| `window_manager` depends on `screen_retriever: ^0.2.2` only (plus `path`, `flutter`) | same |
| `window_manager` environment floor: Dart `>=3.0.0`, Flutter `>=3.3.0` | same; monorepo floor is `>=3.10.0` / `>=3.38.0`, so it is inside |
| `zip_broadcast` already pins `screen_retriever: ^0.2.2` | `packages/zip_broadcast/pubspec.yaml` |
| `zip_broadcast` pins `desktop_multi_window: ^0.2.0`; `zip_captions` has neither plugin | both pubspecs |
| `desktop_multi_window`'s channel is `mixin.one/flutter_multi_window` (single slot for `setMethodHandler`) | `~/.pub-cache/.../desktop_multi_window-0.2.1/lib/src/channels.dart` |
| macOS pod pinning: `desktop_multi_window` and `screen_retriever_macos` are already in `zip_broadcast/macos/Podfile.lock`; `zip_captions/macos/Podfile.lock` has neither | both lockfiles |
| Windows plugin linkage is per-app (`windows/flutter/generated_plugins.cmake` lists `desktop_multi_window` and `screen_retriever_windows` for `zip_broadcast` only) | that file, both apps |
| macOS plugin registration is per-app and **static** (`GeneratedPluginRegistrant.swift` has no per-engine variant) | both apps' registrants |
| `zip_captions`'s three runners have **no** window-created callback today; `zip_broadcast`'s do | reading all six runner files |
| CI compiles Windows/Linux (`build-verify.yml`) | the workflow file |

## Contradictions to record (not to resolve silently)

- **macOS plugin registration is static.** The Unit 8.1 definition says the window-created callback
  "can run `RegisterGeneratedPlugins(registry:)`-equivalent registration against that engine".
  On macOS the generated registrant takes a `FlutterPluginRegistry`, and the multi-window
  controller's `view` is a `FlutterViewController`, which *is* a registry — so the call is
  available, but the generated function registers **every** plugin of the app, not just
  `window_manager`. Registering the full set into the sub-engine is what the plugin's own example
  does, and it is harmless (the pop-out engine simply gains Supabase/WebRTC/etc. channels it never
  calls), but it is a different statement than "register `window_manager`". Windows and Linux take a
  per-plugin registration path. This asymmetry is the first question below.
- **`zip_broadcast` will no longer import `screen_retriever`.** Leaving the dependency declared is an
  unused dependency (SECURITY-10). Removing it moves `screen_retriever_macos` out of that app's
  `Podfile.lock` while `zip_core`'s own pod appears — a lockfile diff in two places, not one.

---

## NFR Requirements questions

## Question 1
How are plugins registered for the pop-out sub-engine on each platform, given the macOS registrant
is all-or-nothing and Windows/Linux are per-plugin?

A) macOS: call the app's `RegisterGeneratedPlugins(registry: controller.view)` (the full set) from
   the existing window-created callback, additive to the shipped borderless style change. Windows:
   call `WindowManagerPluginRegisterWithRegistrar(...)` — plus keep the shipped borderless code —
   inside `DesktopMultiWindowSetWindowCreatedCallback`. Linux: the same with
   `window_manager_plugin_register_with_registrar(...)` inside the shipped
   `desktop_multi_window_plugin_set_window_created_callback`. Record the macOS "full set" asymmetry
   as intentional, with the plugin's own example as precedent and Unit 9 as the check.
B) macOS: register only `WindowManagerPlugin` by hand (import the plugin's Swift module and call its
   registrar) instead of the generated function, so all three platforms register exactly one plugin.
C) Register nothing on the runners, and let the sub-engine tolerate a missing plugin channel (the
   installer's failure path already logs and continues), accepting that always-on-top silently does
   not work on any platform until a later fix.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 2
Where does `window_manager` get declared, and what happens to `screen_retriever` in `zip_broadcast`?

A) `window_manager` in `zip_core` only; `desktop_multi_window` in `zip_core` + both apps (an app's
   runner compiles against the plugin, and `zip_broadcast` already declares it); remove
   `screen_retriever` from `zip_broadcast` once its last import moves. Lockfile fence: root
   `pubspec.lock` gains `window_manager` (+ `path` if not already present) with no version movement
   of existing entries; `zip_broadcast/macos/Podfile.lock` loses `screen_retriever_macos` and gains
   `window_manager_macos`; `zip_captions/macos/Podfile.lock` gains `desktop_multi_window` and
   `window_manager_macos`. Anything else moving is reported, not committed.
B) Declare all three in all three packages (each app states what it uses), accepting unused
   declarations in `zip_captions` for `screen_retriever` and `window_manager`.
C) Declare `window_manager` in both apps as well as `zip_core`, because the runner code lives in the
   apps and the native registration needs the plugin resolvable from the app.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 3
How is `OverlayMethodRouter` tested, given that a mistake silently breaks the shipped external
display?

A) Three layers: (i) unit tests on the router itself with fake handlers — registration order,
   first-recogniser-wins, unregister-of-unknown-token is a no-op, last unregistration uninstalls,
   re-registration after full uninstall re-installs; (ii) an integration-style test with **two real
   controllers** on fake window services sharing one router and one recording
   `OverlayMethodHandlerInstaller`, proving an `overlayReady` addressed to window 7 reaches only the
   controller that created window 7 and never the other; (iii) the moved Unit 8 controller/PBT suite
   unchanged, which would fail if the router misrouted `'-1'` or dropped a call.
B) Unit tests only; the two-controller case is left to the moved Unit 8 suite plus code review.
C) Skip the router: restore the shipped one-installer-per-controller shape and instead have the
   second controller (pop-out) never install a handler, routing its readiness through a separate
   channel it owns.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 4
What can the suite honestly assert about always-on-top, and what is deliberately left to Unit 9?

A) Assert only the seam: `OverlayWindowEntry` awaits the injected installer **exactly once, before**
   `overlayReady`, for `PopOutMode` and **never** for `ExternalDisplayMode`; an installer that throws
   still results in ready being sent; the production installer is a no-op under the test platform and
   its call is recorded by a fake. The actual floating behaviour is a Unit 9 manual check on real
   desktops (§8.8 item 15), and the Linux "the WM is the enforcer" caveat is recorded alongside it.
B) Also assert the call arguments and sequencing at the plugin boundary with a mock method channel
   (`window_manager`'s channel), proving `setAlwaysOnTop` with `true` is invoked on the pop-out
   engine.
C) Nothing in the suite; the installer is a three-line wrapper and Unit 9 covers it entirely.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 5
How is per-app evidence organised so §8.8's "passing in one app does not satisfy the criterion for
the other" is enforced rather than remembered?

A) Every claimed §8.8 item gets a test **in each app's** `test/` tree (Zip Broadcast and Zip
   Captions), even where the implementation is shared: the shells' toggle wiring, the availability
   rendering, the hint, the ≥1-instance rule, the OS-close coherence and the redaction audit are
   app-level by nature, so duplicating the test bodies 2x is the honest cost. The code summary
   carries an 18-row table with two columns (`zip_broadcast`, `zip_captions`) plus a third for the
   Unit 9 / Phase 8 rows.
B) One shared test suite in `zip_core` exercising the shared widgets, plus a thin per-app smoke test
   that only proves the widget is mounted.
C) Vendored shared test helpers but a single copy of each test, run once, with the app dimension
   recorded in the plan rather than in the test tree.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 6
Two apps duplicate the ~60-line `PopOutCaptionTarget` (Q5 A). Which quality stance does this take?

A) Accept the duplication as the app-local bus adapter; constrain it structurally — the two files
   differ only in imports and logger name, both are covered by their own app's tests, and a shared
   test fixture asserts the same behaviour matrix in each app so they cannot drift silently.
B) Extract one `PopOutCaptionTarget` into `zip_core` taking an injected
   `List<CaptionDisplayEntry> Function()` buffer reader, so there is exactly one implementation; each
   app passes its own reader (which is what `CaptionOverlayTarget` already does inline).
C) Leave the duplication unconstrained; it is small and app-local by definition.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 7
Performance: what concrete targets apply to the pop-out, beyond Unit 8's existing ones?

A) Inherit Unit 8's exactly and add nothing numeric beyond them: ≤1 `captionUpdate` per 16 ms frame
   with payloads under `maxEncodedBytes` (16 KiB); open bounded by `overlayReadyTimeout` (10 s); ≤1
   `getAllDisplays()` per platform event and zero polls; window creation completes or fails within
   the ready timeout on every platform. New to this unit, stated as targets: the toggle's press-to-
   `Opening` transition is synchronous in the same frame (no await before `createWindow`), and
   always-on-top is applied before the window is shown (so it never flashes un-topmost).
B) Same, plus a startup budget for the pop-out engine (e.g. first frame within 500 ms) measured on
   macOS only.
C) Same, plus per-frame cost caps on the pop-out's own widget tree distinct from the main window's.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 8
Reliability: what happens when the pop-out cannot be shown (handler missing, plugin missing, window
manager failing, VM refusing always-on-top)?

A) Fail closed and explain, with one exception: a missing handler or a failed `createWindow`/ready
   handshake is `OpenFailed` → the shell clears the flag and shows `popOutOpenFailed`; a failing
   `window_manager` call is **not** a failure (the window is still usable, it just may not float) and
   logs a fixed string. No retries anywhere; the next toggle is the retry (Unit 8's rule). The user is
   never told a window opened on top when the installer failed.
B) Treat a failing `window_manager` call as `OpenFailed` too, so the user knows the pop-out is not
   actually floating.
C) Retry the install once before giving up, then continue without always-on-top.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 9
Observability and the redaction audit, in both apps:

A) Reuse Unit 8's pattern in each app: one record-level test capturing `Logger.root.onRecord` with a
   sentinel caption string, asserting no `LogRecord.message`, `error`, `stackTrace` or `OpenFailed`
   reason contains it, driving toggle-on, toggle-off, OS-close, `create_failed`, ready timeout and a
   caption update. One such test per app; the promoted controller's own logs keep their fixed
   strings, and the only new log sites (installer failure, pop-out toggle) are audited by the same
   test. No new logging infrastructure, no telemetry.
B) A single audit in `zip_core` plus an assertion that neither app adds its own logger in the
   pop-out path.
C) Rely on code review for the app-level paths; keep only the promoted controller's shipped audit.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 10
PBT: which framework and which subsets of POP-1..POP-8 are mandatory?

A) The in-tree `test/helpers/pbt.dart` shim (the project's standing Dart PBT decision from Unit 7,
   re-confirmed by Unit 8 — no `glados`), duplicated into `zip_core/test/helpers/` per the FD.
   Mandatory properties: POP-1 (launch round-trip), POP-2 (decode totality), POP-3 (size bound),
   POP-4 (geometry invariants), POP-5 (both modes' stateful suite), POP-6 (mode token round-trip),
   POP-8 (frame conversion, moved as-is). POP-7 is an exhaustive table test, not generated.
   `resolveOpenDisplay`'s and the codec's existing properties move and run in `zip_core`.
B) Same, but drop POP-3 and POP-4 to example-based tests as low value.
C) Same, plus a new stateful property suite covering the two controllers sharing a router.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 11
Maintainability: how is the "no behaviour change" claim about the moved Unit 8 code checked, beyond
tests passing?

A) Three mechanical checks recorded in the code summary: (i) `git diff -M --find-renames` on the move
   commit shows every moved file as a pure rename (R100) except the files listed in the FD's
   additive-change table; (ii) any file with a non-rename diff must map to a row in that table;
   (iii) the removed-dependency/listener greps from FD §7 produce the expected result set. No
   formatter-only or import-sort-only churn inside moved files beyond the path rewrite.
B) Tests passing is sufficient; the move is mechanical and reviewed by the compiler.
C) A generated API-compatibility report comparing the shipped public surface to the promoted one.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

## Question 12
Usability and accessibility for the new controls:

A) Both toggles carry a visible text label plus a `Semantics(button, enabled, label, hint)` node with
   the disabled reason as `hint` and as adjacent visible text; the banner's return action is a normal
   focusable button; the in-surface toggle's minimum hit area is 44x44 logical pixels in the
   two-line window; no colour-only state (icon and label both change). No screen-reader announcement
   on pop-out open (nothing in §8 asks for one; recorded as not implemented rather than overlooked).
B) Same as A plus a live-region announcement when the pop-out opens or closes, mirroring Unit 7's
   `viewerAnnouncerProvider`.
C) Visible label only; semantics left to Flutter's defaults.
D) Other (please describe after [Answer]: tag below)

[Answer]: 

---

## Open questions carried from the FD handoff

These are answered by the questions above; listed so nothing is dropped:
- Test seam for `AlwaysOnTopInstaller` → Q4
- Whether the per-app `PopOutCaptionTarget` duplication is acceptable → Q6
- How `zip_captions`'s main-entry routing is proven without initialising Supabase → **not covered**
  above; it becomes a follow-up question in the clarification file if the answer is not derivable
  from Q9's pattern. Recorded here rather than assumed.