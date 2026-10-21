# NFR Design Plan — Unit 8.1: Pop-out Live Captions (S-21)

**Unit**: 8.1 — Pop-out Live Captions (PiP)
**Story**: S-21 (`pip-ux-parity.md` §8 binding; §8.8 evidenced per app)
**Stage**: NFR Design (Stage 3 of 6)
**Branch**: `feature/popout-live-captions` (off `develop` at `5e3bd3b`)
**Status**: **PROPOSED — answers recorded 2026-10-21; artifacts generated; awaiting approval.**

**Inputs** (read in this order):
1. `aidlc-docs/aidlc-state.md` — the Unit 8.1 entry and the current-stage line
2. `aidlc-docs/construction/plans/pop-out-pre-build-review.md` — R-B1..R-B5, R-M1..R-M10, R-m1..R-m7,
   owner answers RQ-1 A / RQ-2 A / RQ-3 A-amended, the `[Resolution]` lines, §3a
3. `aidlc-docs/construction/pop-out/functional-design/handoff-summary.md` (incl. Revision 1,
   Revision 2, the APPROVED block and the carried open item)
4. `aidlc-docs/construction/pop-out/nfr-requirements/handoff-summary.md`
5. the FD artifacts: `business-logic-model.md` §2, §3.2, §3.4, §4.1-§4.4; `domain-entities.md`
   §1.2-§1.4, §3.1, §3.3, §5; `business-rules.md` BR-PIP-01..14, BR-U8.1-01..12;
   `tech-stack-decisions.md` §1-§4; `nfr-requirements.md` §1.2, §2, §3, §10.1-§10.5
6. `.aidlc-rule-details/construction/nfr-design.md`,
   `.aidlc-rule-details/extensions/security/baseline/security-baseline.md`,
   `.aidlc-rule-details/extensions/testing/property-based/property-based-testing.md`,
   `.aidlc-rule-details/common/question-format-guide.md`

---

## What this stage is, and what it is not

NFR Design turns the approved non-functional requirements into patterns and logical components. For
this unit it is **mostly a carrying stage**: the pre-build review already settled the mechanisms,
and re-deriving any of them would reopen approved decisions. The list below is binding input, not a
menu.

### Carried decisions — must appear in the NFR Design artifacts, unchanged in substance

| # | Decision | Source | NFR Design section that must carry it |
|---|---|---|---|
| 1 | Six `_isPopOut` guards on every display-consulting path; the mode is fixed at **construction** and `open()`'s config mode is validated against it (mismatch → `create_failed`) | FD BLM §2; R-M2; NFR-R §10.2 | Resilience |
| 2 | Router shape: `int? get windowId`; token-bound installer installed at `_bootstrap` as today (`overlay_window_controller.dart:191`); dispatch **only** when `windowIdOf() != null && windowIdOf() == fromWindowId`, so **null never matches** | FD BLM §4.1; R-M3 Revision 2 item 2 | Logical components |
| 3 | The **shell** computes the frame and passes it to `open(config, frame:)`; `_runReady` uses it verbatim via `setFrame`; per-platform chrome allowance lives in `pop_out_geometry.dart` as named constants with a table test and is documented as *content*-size semantics | FD BLM §3.4; R-M5; NFR-R §10.3 | Performance |
| 4 | `WindowConfigurator.configure` runs in the sub-engine **before** ready for **both** modes; `ExternalDisplayMode` passes `floating: false, decorated: false` (pinned); a throwing configurator still sends ready | FD BLM §3.2 step 6; FD domain-entities §1.2.1; NFR-R §1.2 items 1-3 | Resilience |
| 5 | Close transport: a first-party `subWindowClosed {windowId}` channel on the **main** engine, fed through `SubWindowClosedChannel` to `controller.onNativeWindowClosed(int)`; id match → `CloseReason.windowClosed`, anything else dropped; `'-1'` stays the fallback; it does **not** travel through `OverlayMethodRouter` | FD BLM §3.2; RQ-3 A-amended; NFR-R §1.2 | Resilience |
| 6 | The overlay barrel is the separate library `package:zip_core/overlay.dart`, **not** re-exported from `zip_core.dart` | R-M7; NFR-R §5.2 | Logical components |
| 7 | The seven permitted `OverlayWindowController` deviations (six guards, `popOutToggle` case, `open({Rect? frame})`, mode at construction, token-bound installer, `int? get windowId`, `onNativeWindowClosed`) and nothing else | FD BLM §4.1; BR-U8.1-01 | Logical components |

Also carried without restatement: `controls` renders outside the scrolling list (R-M4); failure copy
renders next to the chrome toggle while `Failed` (R-M8); `popOutAvailability` tests the three concrete
states, not the `ActiveSessionState` mixin (R-m3); `_bootstrap` must not require a display for
`PopOutMode`; no `window_manager` anywhere (RQ-1 A).

### The one carried open item

> Where the `SubWindowClosedChannel` listener is registered relative to
> `WidgetsFlutterBinding.ensureInitialized()` and the app's startup work; who owns its lifetime; and
> that it is listening before any sub-window can be created.

This is **question D1**. It is the only genuinely open point the handoff carries.

### What NFR-R §10.5 and the two handoffs explicitly leave to NFR Design

- the router's provider wiring shape (§10.1 fixes that a keepAlive provider in `zip_core` owns the
  router and the single enumerator and exposes `createController(...)`; the wiring detail is
  **question L2**);
- the exact `configure` channel name per platform (**question L6**);
- the per-platform chrome-allowance constants (**question P3** — the constants are NFR Design's to
  name; their *values* are verified in Infrastructure Design and measured in Unit 9).

---

## Verified against source before writing the questions

Every native claim below was re-checked against the pub-cache sources named in the session brief, not
taken from any document.

| Claim | Evidence |
|---|---|
| Windows callback is one argument, a `flutter::FlutterViewController*` | `~/.pub-cache/hosted/pub.dev/desktop_multi_window-0.2.1/windows/include/desktop_multi_window/desktop_multi_window_plugin.h` (`typedef void (*WindowCreatedCallback)(void *flutter_view_controller);`); invoked at `windows/flutter_window.cc:116-117` as `_g_window_created_callback(flutter_controller_.get())`; example form at `example/windows/runner/flutter_window.cpp:32-38` |
| Linux callback is one argument, an `FlPluginRegistry*` **of the sub-window** | `.../linux/include/.../desktop_multi_window_plugin.h` (`typedef void (*WindowCreatedCallback)(FlPluginRegistry *registry);`); invoked at `linux/flutter_window.cc:52-53` as `_g_window_created_callback(FL_PLUGIN_REGISTRY(fl_view))` — not the main view, which is why Unit 8's shipped two-argument call could not compile (R-B4) |
| The callback is **mode-blind**: it receives no launch arguments | the two signatures above carry only the view controller / registry; the launch args reach Dart (`["multi_window", id, args]`), not the native callback — the reason RQ-1 A has the Dart side call `configure` |
| Sending to another window works from the sub-engine | shipped `packages/zip_broadcast/lib/src/output/overlay/overlay_window_bridge_io.dart` calls `DesktopMultiWindow.invokeMethod(0, 'overlayReady', …)`; the same mechanism carries `popOutToggle` |
| `DesktopMultiWindow.setMethodHandler` is one static slot, `null` unregisters | verified in Unit 8's NFR Design; still the reason the router exists |
| The shipped controller installs its handler in `_bootstrap` before any window exists | `packages/zip_broadcast/lib/src/output/overlay/overlay_window_controller.dart:191`; `_bootstrap` returns early on `!isSupported` (`:184-188`) |
| The main app's `main` is the only place both integers are available at process start | `packages/zip_broadcast/lib/main.dart:32-36` and `packages/zip_captions/lib/main.dart:31` call `WidgetsFlutterBinding.ensureInitialized()` first |
| Neither app has a production method-channel seam today | `rg "MethodChannel" packages/*/lib` → no hits; the new `SubWindowClosedChannel` is the first |
| `OutputTargetSettings.externalDisplayId` is **persisted** (so a pop-out flag must not live there) | `packages/zip_broadcast/lib/src/models/output_target_settings.dart` (`ExternalDisplayId` field); `broadcast_providers.dart:98-105` writes every field key-by-key — FD domain-entities §1.3 says why `popOutEnabled` is in-memory only |
| `OutputTargetSettingsNotifier.build()` returns defaults synchronously and loads asynchronously | `packages/zip_broadcast/lib/src/providers/broadcast_providers.dart:107-111` |
| The shipped shell opens the overlay inside `_syncOverlay`, after `registry.add` | `packages/zip_broadcast/lib/src/shell/zb_app_shell.dart:156-200` |
| CI runs the whole suite on Linux (`melos run test:coverage --no-select`) with Flutter 3.38.7, while this machine has 3.41.7 | `.github/workflows/ci.yml:29-72`; `flutter --version` locally |

---

## Plan steps

- [x] Step 1: Read the state file, the pre-build review, both handoff summaries and the FD/NFR-R
      artifacts; verify every native claim above against the pub-cache sources
- [x] Step 2: Write this plan
- [x] Step 3: Write `pop-out-nfr-design-questions.md` (D1, R1, P1-P3, L1-L5; recommendations
      recorded, nothing answered on the owner's behalf)
- [x] Step 4: Question gate answered 2026-10-21 (D1 B-corrected, R1 A, P1 A-corrected, P2 A,
      P3 A-corrected, L1 A, L2 A, L3 A, L4 B, L5 Other)
- [x] Step 5: Collect and validate the answers; raise a clarification file if any answer is
      ambiguous or contradicts another (question-format-guide §"Contradiction and Ambiguity")
- [x] Step 6: Generate `nfr-design/nfr-design-patterns.md` (resilience, performance, security,
      scalability-as-N/A, with the Security Baseline and PBT compliance sections)
- [x] Step 7: Generate `nfr-design/logical-components.md` (component list with constructor seams,
      dependency direction, provider graph, resource-lifetime table, the state→pattern map)
- [x] Step 8: Generate `nfr-design/handoff-summary.md` (NFR Design → Infrastructure Design), with
      every verify-not-assume item the FD hands to Infrastructure Design
- [ ] Step 9: Deferred to the owner's approval. `audit.md` and `aidlc-state.md` are **not** updated
      and the work is **not** committed: this session stops at the approval gate by instruction, so the
      stage is not recorded complete until the owner approves.

---

## Question domains, and why each is asked

The rule file requires every domain to be evaluated or explicitly justified as inapplicable.

| Domain | Applicability | Carried by |
|---|---|---|
| **Resilience** | Applies. Two new failure surfaces (the close channel, the configurator) sit next to the settled no-retry policy, and the carried open item is a lifetime/ordering problem. | D1, R1 |
| **Performance** | Applies. R-M5 splits frame ownership between shell and controller and adds a chrome allowance; the toggle-to-`Opening` target interacts with the shell's async settings read. | P1, P2, P3 |
| **Security** | Applies. Two first-party method channels are new native boundaries. SECURITY-05 (input validation), SECURITY-13 (deserialisation allowlist) and SECURITY-15 (fail-closed) apply directly; SECURITY-03 constrains what may be logged. | L1, L5 (in Security) |
| **Scalability** | **N/A — restated, not re-derived.** NFR-R §7: no queue, pool, cache or concurrency axis; at most two windows per engine, at most two handlers in the router, one enumerator, one 16 ms timer per open window. The router adds an upper bound of two, verified statically rather than scaled. Not asked as a question because there is no growth axis to decide. | — |
| **Logical components** | Applies. Provider graph, ownership, channel naming, and the move's package/wiring shape. | L1-L4 |

---

## Deliverable shapes this stage will produce (after the gate)

- `aidlc-docs/construction/pop-out/nfr-design/nfr-design-patterns.md`
- `aidlc-docs/construction/pop-out/nfr-design/logical-components.md`
- `aidlc-docs/construction/pop-out/nfr-design/handoff-summary.md`

---

## Open items NFR Design will hand to Infrastructure Design (not settle here)

These come from the FD's verify-not-assume list and are restated so they are not lost:

1. That a Dart message from the sub-engine at close time is lost (RQ-3's premise).
2. macOS: the notification's delivery point relative to `deinit`.
3. Windows: the window-proc delegate's ordering against `HandleTopLevelWindowProc`.
4. Linux: `delete-event` vs `"destroy"`, given the plugin's handler returns `TRUE` after destroying
   (`linux/flutter_window.cc:34-40`) — and whether the close notification can be connected at all
   given that ordering.
5. Every runner callback signature and the sub-engine `argv` delivery (`["multi_window", id, args]`).
6. Flutter SDK version (CI pins 3.38.7, Unit 8's ID cited 3.41.7 — R-m6).
7. The three chrome-allowance values, measured on real windows.

Item 4 is the one most likely to change a decision made in this stage; question R1 and D1 are
written so that a Linux-only ordering failure degrades to "the `'-1'` fallback covers Linux" rather
than forcing a redesign.