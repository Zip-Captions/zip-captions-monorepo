# Code Generation Plan — Unit 8.1: Pop-out Live Captions (S-21)

**Stage**: Code Generation, **Part 1 — planning only**. This document is the deliverable. **Part 2**
(implementation, tests, l10n, runners, gates) executes it step by step.

**Branch**: `feature/popout-live-captions` (local only; no push, no PR in this stage).
**Packages**: `zip_core` (promotion target), `zip_broadcast`, `zip_captions`.

**Run mode**: unattended per `.agent/overnight-pipeline.md` (2026-10-21). This plan is
self-approved on write:
`approved by: run configuration (.agent/overnight-pipeline.md, 2026-10-21) — subject to morning review`.

---

## 0. Prior stages, and what was re-read

| Stage | Status | Artifact |
|---|---|---|
| Functional Design (revision 2) | APPROVED 2026-10-21 by James Petersen | `../pop-out/functional-design/` |
| NFR Requirements (revision 2) | APPROVED 2026-10-21 by James Petersen | `../pop-out/nfr-requirements/` |
| NFR Design | APPROVED 2026-10-21 by James Petersen | `../pop-out/nfr-design/` |
| Infrastructure Design | COMPLETE 2026-10-21 by the run configuration, subject to morning review | `../pop-out/infrastructure-design/` |

Loaded per `aidlc-project-rules/construction/stage-handoff.md` Rule 2 (handoffs first), then in full
because the plan must be a strict transcription and the handoffs do not carry the rule text, the
transition table, the property table or the per-file tables:

| Artifact | Why it was read in full |
|---|---|
| `pop-out/functional-design/business-logic-model.md` | §1 the 23-file inventory, §2 the state machine and the six guards, §3.2 the sub-engine sequence, §3.4 geometry, §4.1 the router and the **seven** deviations, §7 the five permitted test-shape changes |
| `pop-out/functional-design/business-rules.md` | BR-PIP-01..14 verbatim, BR-U8.1-01..12 verbatim |
| `pop-out/functional-design/domain-entities.md` | §1 promotions, §1.3 new types, §3.1 availability matrix, §3.2 the seven strings, §3.3 geometry, §5 POP-1..POP-8 |
| `pop-out/functional-design/frontend-components.md` | §2 `controls`, §3 the chrome toggle, §4 the in-surface toggle, §5 the banner, §6 the matrix, §7 the body |
| `pop-out/nfr-requirements/{nfr-requirements,tech-stack-decisions}.md` | §1 testability and the four configure assertions, §3.1 failure policy, §5.1 refactor proof, §8 PBT, §10.1-10.5; tech-stack §1-§6 |
| `pop-out/nfr-design/{nfr-design-patterns,logical-components}.md` | the host/lease/router shapes, the lease tests, the chrome-constant table, the test seams |
| `pop-out/infrastructure-design/infrastructure-design.md` | §2 verify items, §3 the close map, §4 the per-runner code, §6 the registrant movement, §7 the dependency delta, §9 the insertion points |
| `plans/pop-out-pre-build-review.md` | R-B1..R-B5, R-M1..R-M10, R-m1..R-m7, RQ-1 A/RQ-2 A/RQ-3 A-amended, and the §3a re-verification |
| `plans/pop-out-{functional-design,nfr-requirements,nfr-design}-*` and the two clarification files | the answer records the design cites |
| `pip-ux-parity.md` §8 | the binding UX contract, §8.8's 18 items and its own tested/Unit 9/deferred partition |
| `inception/user-stories/phase2-stories.md` S-21 | acceptance criteria |
| `inception/application-design/phase2-unit-of-work.md` Unit 8.1 | scope, stages, blocks |
| `plans/external-display-code-generation-plan.md` | the shape precedent (Unit 8's 26-step plan) |

**Verified against source before writing** (not against the handoffs): every shipped overlay file
and its line count, the controller's `dispose()` and the six display-consulting sites, the codec's
`_modeExternalDisplay` constant and its `'popOut'` rejection cases in the moved tests,
`CaptionDisplayWidget`'s `ListView` and `reverse:` (the R-M4 finding), `DesktopWindowService`'s
current five methods (R-m1: `setBounds` is absent, as the review's V-2 correction says),
`zip_captions`' `main()` signature and startup body, `ZcAppShell` being a `ConsumerWidget`,
`ZcNavRail`'s trailing settings button (no header row), `sttEngineProvider` existing in `zip_core`
and appearing nowhere in `zip_captions/lib` (R-M1's own consequence), `audioInputConfigNotifierProvider`
being `zip_broadcast`'s Start-Captioning gate (`home_screen.dart:30`), the three `ip_captions`
(wrong: **six**) runner files, the tracked registrants, `pubspec.yaml` ×3, the two `Podfile.lock`
files, and `pubspec.lock`.

---

## 1. Unit context

### 1.1 Story and scope

S-21 (`phase2-stories.md:553`) and `pip-ux-parity.md` §8, which is binding. The pop-out is desktop
only in Phase 2 (macOS, Windows, Linux), in **both** apps, and its acceptance criteria are evidenced
**per app** (§8.8's per-app clause). Items 8-10 are deferred to Phase 8 (translation); items 4, 12,
13, 15, 16 and 17 are Unit 9 platform checks. The unit promotes Unit 8's window machinery from
`zip_broadcast` into `zip_core` and must not regress the external display (BR-U8.1-01).

### 1.2 Dependency delta (exactly this, nothing else)

| Package | Change | Version | Source |
|---|---|---|---|
| `zip_core` | **add** `desktop_multi_window`, with a SECURITY-10 comment | `^0.2.1` | A5 constraint floor; tech-stack §1; ID §7 |
| `zip_core` | **add** `screen_retriever`, with a SECURITY-10 comment | `^0.2.2` | tech-stack §1 |
| `zip_broadcast` | **remove** `screen_retriever` (its SECURITY-10 comment block goes with it) | — | A5; tech-stack §1 |
| `zip_broadcast` | `desktop_multi_window` unchanged | `^0.2.1` | already shipped (PR #40) |
| `zip_captions` | **add** `desktop_multi_window`, with a SECURITY-10 comment | `^0.2.1` | A5; tech-stack §1 |
| any | `window_manager` | **never** | RQ-1 A |

No dev-dependency change anywhere (A7). `zip_captions` has no `fake_async` and no `mocktail`; adding
either is BLOCKED (unit exception 4).

The two new `zip_core` entries carry the SECURITY-10 justification inline, following
`zip_broadcast`'s existing comment style: the record is
`../external-display/functional-design/screen-retriever-security-10.md` (16 releases, MIT, federated,
read-only display metadata) for `screen_retriever`; for `desktop_multi_window` the justification is
that it is already an approved, shipped dependency of `zip_broadcast` (Phase 1) and now needs to sit
behind `zip_core`'s fence, with the outcome re-declared by `zip_captions` because its runners include
the plugin headers directly (ID §7).

### 1.3 Lockfile and generated-file fence (exact expected movement)

| File | Expected movement | Why |
|---|---|---|
| root `pubspec.lock` | **none** | `desktop_multi_window` 0.2.1 and `screen_retriever` 0.2.2 with all four federated entries are already resolved (verified in `pubspec.lock` and `.dart_tool/package_config.json`) |
| `packages/zip_broadcast/macos/Podfile.lock` | **none** | `screen_retriever_macos` stays: the plugin still reaches the app through `zip_core` (R-M10) |
| `packages/zip_captions/macos/Podfile.lock` | **gains** `desktop_multi_window` and `screen_retriever_macos` (and the `PODFILE CHECKSUM` change a pod addition implies) | new direct + new transitive plugin |
| `zip_broadcast/{macos/Flutter/GeneratedPluginRegistrant.swift, windows/flutter/generated_plugin_registrant.cc, windows/flutter/generated_plugins.cmake, linux/flutter/generated_plugin_registrant.cc, linux/flutter/generated_plugins.cmake}` | **lose** `screen_retriever_*` (macOS: `import` + `register`; Windows: `include` + register call + cmake entry; Linux: `include` + register block + cmake entry) | the app drops its own declaration (ID §6) |
| `zip_captions/{same five}` | **gain** `desktop_multi_window` + `screen_retriever_*` (both includes/imports, both register calls, both cmake entries, alphabetical position as the tool emits it) | new direct + new transitive plugin |
| the `.h` registrants (`windows/flutter/generated_plugin_registrant.h`, `linux/flutter/generated_plugin_registrant.h`) | **none expected** | they carry no plugin list |

Rules (ID §6, A5):

1. These files are **tool-produced** (`flutter pub get` plus a build), never hand-edited. A hand edit
   is a defect even when the content matches.
2. Any movement **not** in the table above is reported in the Part 2 summary and the PR body, never
   staged silently.
3. `desktop_multi_window` is **not** removed from `zip_broadcast`'s registrants.
4. Ordering inside `FLUTTER_PLUGIN_LIST` is the tool's; reviews must not alphabetise it.
5. Generated Dart (`*.freezed.dart`, `*.g.dart`, `lib/src/l10n/*.dart`) is regenerated by the tool at
   its new path; it is never hand-authored and is **not** counted in §2's file table (see §2.3).

### 1.4 Assumptions carried from the binding stages (not new questions)

| # | Assumption | Source |
|---|---|---|
| A-1 | `chromeAllowance`'s three values (28 macOS / 39 Windows / 38 Linux, plus 8 and 1 border insets) are **documented estimates**, unverified until Unit 9 check 3. The code comment says exactly that. | NFR Design P3 correction |
| A-2 | The pop-out's `mainWindowCentre` is `null` in production, so the geometry falls back to the primary display. Multi-monitor placement is Unit 9 check 6. | NFR-R §10.3 (Q2 C) |
| A-3 | `popOutSize`'s toggle-row height is the constant `PopOutGeometry.toggleRowHeight = 44` (the NFR-R §6 44x44 hit target); content size, chrome added separately. | FD domain-entities §3.3 + NFR-R §6 |
| A-4 | `zip_broadcast`'s engine gate is `audioInputConfigNotifierProvider.isNotEmpty` — the exact expression `home_screen.dart:30` uses for Start Captioning (`canStart = isIdle && configs.isNotEmpty`). | RQ-2 A; R-M1; FD domain-entities §3.1 |
| A-5 | `flake`-free timing: the controller's ready timeout and 16 ms coalescer tests stay in `zip_core` (which has `fake_async`); `zip_captions` asserts "same frame" with `tester.pump()` only. | A7; tech-stack §4 |
| A-6 | `OverlayWindowUnavailableApp`'s parameter is `required String message`; `zip_broadcast` passes `l10n.externalDisplayUnavailable` (the existing key), `zip_captions` passes `strings.overlayWindowUnavailable` (new key). | FD §7 item 1; NFR-R §5.3 |
| A-7 | `/recording` and `/b/:broadcastId` already run on desktop and both resolve `displayListProvider` today, so `screen_retriever` registering on those routes is **not** a behaviour change; on web it registers nothing (`registerWith` on `linux/windows/macos` only). Recorded, not a defect. | verified: `pubspec.lock`, `screen_retriever` 0.2.2 `registerWith` |

None of the seven is a new design decision: each transcribes a decision the approved stages already
recorded, or a value they named without fixing a number (A-3, A-1). No open question remains.

---

## 2. File table

All paths relative to the repository root. **C** = created, **M** = modified, **D** = deleted, **MV**
= moved (source → target; the source is deleted). `zip_*` paths are under `packages/`.

### 2.1 `zip_core` production (`packages/zip_core/lib/`)

Barrel: `overlay.dart` is a **separate library**; `zip_core.dart` does not export it (R-M7 — exporting
it would collide with `ConnectionStatus.Failed`).

| # | Path | C/M/MV/D | Source | Source (stage) |
|---|---|---|---|---|
| C01 | `src/output/overlay/caption_overlay_codec.dart` | MV | `zip_broadcast/lib/src/output/overlay/caption_overlay_codec.dart` | FD BLM §1, §7; BR-U8.1-08 (mode token added → M row below) |
| C02 | `src/output/overlay/caption_overlay_snapshot.dart` | MV | `zip_broadcast/lib/src/output/overlay/caption_overlay_snapshot.dart` | FD §1.1, §1.3 (`contentMode` field added → M row) |
| C03 | `src/output/overlay/caption_position.dart` | MV | `zip_broadcast/lib/src/output/overlay/caption_position.dart` | FD BLM §1 (stays in the app first, then moves — see §2.2 note) |
| C04 | `src/output/overlay/desktop_multi_window_service.dart` | MV | `zip_broadcast/lib/src/output/overlay/desktop_multi_window_service.dart` | FD §1.1 |
| C05 | `src/output/overlay/desktop_multi_window_service_io.dart` | MV | `zip_broadcast/lib/src/output/overlay/desktop_multi_window_service_io.dart` | FD §1.1; ID §5.1 |
| C06 | `src/output/overlay/desktop_multi_window_service_stub.dart` | MV | `zip_broadcast/lib/src/output/overlay/desktop_multi_window_service_stub.dart` | FD §1.1 |
| C07 | `src/output/overlay/desktop_window_service.dart` | MV | `zip_broadcast/lib/src/output/overlay/desktop_window_service.dart` | FD §1.2 (no change — R-m1) |
| C08 | `src/output/overlay/display_enumerator.dart` | MV | `zip_broadcast/lib/src/output/overlay/display_enumerator.dart` | FD §1.1 |
| C09 | `src/output/overlay/display_info.dart` | MV | `zip_broadcast/lib/src/output/overlay/display_info.dart` | FD §1.1 |
| C10 | `src/output/overlay/external_display_status.dart` | MV | `zip_broadcast/lib/src/output/overlay/external_display_status.dart` | FD §1.1 (name kept) |
| C11 | `src/output/overlay/overlay_activity.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_activity.dart` | FD §1.1 |
| C12 | `src/output/overlay/overlay_event.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_event.dart` | FD §1.1 (+ `PopOutToggled` → M row) |
| C13 | `src/output/overlay/overlay_window_bridge.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_window_bridge.dart` | FD §1.1 (+ `sendPopOutToggle` → M row) |
| C14 | `src/output/overlay/overlay_window_bridge_io.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_window_bridge_io.dart` | FD §1.1 (+ M row) |
| C15 | `src/output/overlay/overlay_window_bridge_stub.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_window_bridge_stub.dart` | FD §1.1 (+ M row) |
| C16 | `src/output/overlay/overlay_window_controller.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_window_controller.dart` | FD BLM §1, §2, §4.1, §7 (seven deviations = M row) |
| C17 | `src/output/overlay/overlay_window_entry.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_window_entry.dart` | FD §1.2 (`windowConfigurator`, `popOutHost` → M row) |
| C18 | `src/output/overlay/overlay_window_mode.dart` | MV | `zip_broadcast/lib/src/output/overlay/overlay_window_mode.dart` | FD §1.3 (+ `PopOutMode` → M row) |
| C19 | `src/output/overlay/screen_retriever_display_enumerator.dart` | MV | `zip_broadcast/lib/src/output/overlay/screen_retriever_display_enumerator.dart` | FD §1.1; SECURITY-10 fence |
| C20 | `src/output/overlay/screen_retriever_display_enumerator_io.dart` | MV | `zip_broadcast/lib/src/output/overlay/screen_retriever_display_enumerator_io.dart` | FD §1.1; **the only `package:screen_retriever` import in `zip_core`** |
| C21 | `src/output/overlay/screen_retriever_display_enumerator_stub.dart` | MV | `zip_broadcast/lib/src/output/overlay/screen_retriever_display_enumerator_stub.dart` | FD §1.1 |
| C22 | `src/models/overlay_config.dart` | MV | `zip_broadcast/lib/src/models/overlay_config.dart` | FD §1.1 (Q3 A) |
| C23 | `src/models/overlay_position.dart` | MV | `zip_broadcast/lib/src/models/overlay_position.dart` | FD §1.1 (Q3 A) |
| C24 | `src/output/overlay/display_info.freezed.dart` | MV (tool) | `zip_broadcast/lib/src/output/overlay/display_info.freezed.dart` | FD BLM §1 (regenerated at the new path) |
| C25 | `src/models/overlay_config.freezed.dart` | MV (tool) | `zip_broadcast/lib/src/models/overlay_config.freezed.dart` | FD BLM §1 (regenerated) |
| C26 | `src/output/overlay/overlay_method_router.dart` | C | — | FD BLM §4.1; NFR-D logical-components §4; BR-U8.1-04 |
| C27 | `src/output/overlay/display_enumerator_lease.dart` | C | — | NFR-D logical-components §2-§3; NFR-R §3.2 |
| C28 | `src/output/overlay/sub_window_closed_channel.dart` | C | — | NFR-D logical-components §5.2; RQ-3 A amended |
| C29 | `src/output/overlay/sub_window_closed_channel_io.dart` | C | — | NFR-D §5.2 (validation, silent drop) |
| C30 | `src/output/overlay/sub_window_closed_channel_stub.dart` | C | — | NFR-D §5.2 (`const Stream<int>.empty()`) |
| C31 | `src/output/overlay/window_configurator.dart` | C | — | FD §1.2.1; RQ-1 A |
| C32 | `src/output/overlay/window_configurator_io.dart` | C | — | FD §1.2.1; ID §4a (channel `zip_core/overlay_window_configure`) |
| C33 | `src/output/overlay/window_configurator_stub.dart` | C | — | FD §1.2.1 |
| C34 | `src/models/overlay_window_config.dart` | C | — | FD §1.2.1 (`floating`, `decorated`, `minWidth`, `minHeight`) |
| C35 | `src/output/overlay/overlay_window_host.dart` | C | — | NFR-D logical-components §2 (router + enumerator + channel; `createController`) |
| C36 | `src/output/overlay/providers/overlay_window_host_provider.dart` | C | — | NFR-D §2; NFR-R §10.1 (keepAlive, `ref.onDispose`) |
| C37 | `src/output/overlay/pop_out_geometry.dart` | C | — | FD BLM §3.4; FD §1.3; NFR-D §2.3 (chrome constants) |
| C38 | `src/output/overlay/pop_out_availability.dart` | C | — | FD frontend-components §6; FD §3.1 |
| C39 | `src/widgets/pop_out_window_body.dart` | C | — | FD frontend-components §7; FD §1.3 |
| C40 | `src/widgets/overlay_window_app.dart` | MV | `zip_broadcast/lib/src/widgets/overlay_window_app.dart` | FD BLM §1 note; NFR-D logical-components §1 (injected copy → M row) |
| C41 | `src/widgets/caption_display_widget.dart` | M | (existing) | FD frontend-components §2 (`Widget? controls`, outside the list — R-M4) |
| C42 | `overlay.dart` | C | — | NFR-R §5.2; R-M7 (separate library) |

### 2.2 `zip_core` production — moved files that carry one of the approved additive changes

These are the same files as their C rows above; they are listed separately because they are the ones
`git diff -M` will show as **R<100**, and BR-U8.1-01 requires each to map to exactly one permitted
change (§4). Nothing else in the moved set changes.

| # | Path | Change | Permitted by |
|---|---|---|---|
| M01 | `src/output/overlay/overlay_window_controller.dart` | the seven deviations (six `_isPopOut` guards; `'popOutToggle'` case; `open({Rect? frame})`; mode fixed at construction; token-bound installer; `int? get windowId`; `onNativeWindowClosed(int)`), the `_closeChannel` subscription in `_bootstrap`, and — required for both — `dispose()` unchanged | FD BLM §4.1 (deviation 7); NFR-D §3; test shape change 5 |
| M02 | `src/output/overlay/overlay_window_mode.dart` | `final class PopOutMode extends OverlayWindowMode` | FD §1.3; BR-U8.1-08 |
| M03 | `src/output/overlay/caption_overlay_codec.dart` | mode token `'popOut'` encodes/decodes; `contentMode` in the payload; `_modeExternalDisplay` becomes a two-token switch; **no version bump** | FD §1.3; BR-U8.1-08; FD §7 shape change 2 |
| M04 | `src/output/overlay/caption_overlay_snapshot.dart` | `PopOutContentMode contentMode` (default `originalOnly`) included in `==`/`hashCode` | FD §1.3 |
| M05 | `src/output/overlay/overlay_config.dart` (+ `.freezed.dart`) | imports only: the mode type now resolves inside `zip_core` | FD BLM §1 (Q3 A) |
| M06 | `src/output/overlay/overlay_window_entry.dart` | `overlayWindowMain(..., {WindowConfigurator? windowConfigurator})` awaits `configure` before installing the bridge; `OverlayWindowEntry(..., PopOutWindowHost? popOutHost)`; builds `PopOutWindowBody` for `PopOutMode`; `OverlayWindowUnavailableApp(message:)` | FD §1.2; FD §7 shape changes 1 and 5; R-M9 |
| M07 | `src/widgets/overlay_window_app.dart` | `OverlayWindowUnavailableApp` takes `required String message`; `_themeModeOf` becomes a shared helper used by both bodies; `OverlayWindowApp` accepts `Widget? controls` pass-through | FD §7 shape change 1; NFR-R §5.3 |
| M08 | `src/output/overlay/overlay_event.dart` | new variant `PopOutToggled()` | FD BLM §3.3 |
| M09 | `src/output/overlay/overlay_window_bridge.dart` / `_io.dart` / `_stub.dart` | `void sendPopOutToggle()` → `invokeMethod(0, 'popOutToggle', null)`; stub no-op | FD BLM §3.3 |
| M10 | `src/output/overlay/desktop_multi_window_service.dart` / `_io.dart` / `_stub.dart` | imports only, plus the io file's `overlayMethodHandlerInstaller` keeps its const (the router wraps it) | FD §1.1; NFR-D §4 |
| M11 | `src/output/overlay/display_info.freezed.dart` | regenerated: import path only | tool output |

`caption_position.dart`, `desktop_window_service.dart`, `display_enumerator.dart`,
`overlay_activity.dart`, `external_display_status.dart`, `screen_retriever_display_enumerator*.dart`,
`overlay_position.dart` are **R100** (import path only). `desktop_window_service.dart` gains nothing
(R-m1's V-2 correction: `setBounds` does not exist and is not added).

### 2.3 `zip_core` tests

`test/helpers/pbt.dart` is byte-identical in shape to `zip_broadcast`'s; the copy in `zip_core`
**already exists** (verified), so no `pbt.dart` work is needed — the shim is the tool, not a moved
file (PBT-09).

| # | Path | C/M/MV/D | Source | Source (stage) |
|---|---|---|---|---|
| T01 | `test/output/overlay/caption_overlay_codec_test.dart` | MV | `zip_broadcast/test/output/overlay/caption_overlay_codec_test.dart` | FD BLM §7 (shape change 2) |
| T02 | `test/output/overlay/caption_overlay_codec_properties_test.dart` | MV | idem | FD §5 POP-1/2/3 |
| T03 | `test/output/overlay/display_enumerator_contract_test.dart` | MV | idem | FD BLM §7 (R100) |
| T04 | `test/output/overlay/display_info_test.dart` | MV | idem | R100 |
| T05 | `test/output/overlay/display_state_machine_properties_test.dart` | MV | idem | FD §5 POP-5 (extended) |
| T06 | `test/output/overlay/external_display_status_test.dart` | MV | idem | R100 |
| T07 | `test/output/overlay/overlay_window_controller_test.dart` | MV | idem | FD BLM §7 (R100 — the `dispose`/`isDisposed` assertions at `:721-749` must pass verbatim) |
| T08 | `test/output/overlay/overlay_window_entry_test.dart` | MV | idem | FD BLM §7 shape changes 1 and 5 |
| T09 | `test/output/overlay/resolve_open_display_test.dart` | MV | idem | R100 |
| T10 | `test/output/overlay/resolve_open_display_properties_test.dart` | MV | idem | R100 |
| T11 | `test/output/overlay/to_platform_frame_test.dart` | MV | idem | R100 |
| T12 | `test/output/overlay/to_platform_frame_properties_test.dart` | MV | idem | R100 (POP-8) |
| T13 | `test/output/overlay/desktop_window_service_io_test.dart` | MV | idem | R100 |
| T14 | `test/helpers/fake_display_enumerator.dart` | MV | `zip_broadcast/test/helpers/fake_display_enumerator.dart` | FD BLM §7 (R100) |
| T15 | `test/helpers/overlay_generators.dart` | C | (duplicated from `zip_broadcast/test/helpers/generators.dart`) | FD BLM §7 shape change 4 |
| T16 | `test/output/overlay/overlay_method_router_test.dart` | C | — | NFR-R §10.4 layer 1 |
| T17 | `test/output/overlay/two_controller_routing_test.dart` | C | — | NFR-R §10.4 layer 2 (negative assertions) |
| T18 | `test/output/overlay/display_enumerator_lease_test.dart` | C | — | NFR-D §3, the four lease tests |
| T19 | `test/output/overlay/sub_window_closed_channel_test.dart` | C | — | NFR-D §5.2 (method/shape validation, silent drop) |
| T20 | `test/output/overlay/window_configurator_test.dart` | C | — | FD §1.2.1 (stub export no-op; test build `on Object`) |
| T21 | `test/output/overlay/pop_out_window_config_test.dart` | C | — | FD §1.2.1 (`OverlayWindowConfig` equality, `freezed`) |
| T22 | `test/output/overlay/pop_out_mode_codec_test.dart` | C | — | FD §5 POP-6 |
| T23 | `test/output/overlay/pop_out_geometry_test.dart` | C | — | FD §5 POP-4 named examples + A-1 table |
| T24 | `test/output/overlay/pop_out_geometry_properties_test.dart` | C | — | FD §5 POP-4 property |
| T25 | `test/output/overlay/pop_out_availability_test.dart` | C | — | FD §5 POP-7 table test (exhaustive 7x5x2) |
| T26 | `test/output/overlay/pop_out_controller_test.dart` | C | — | FD BLM §2 (six guards), §3.2 (close channel), §3.3 (toggle), §3.4 (framing) |
| T27 | `test/output/overlay/pop_out_state_machine_properties_test.dart` | C | — | FD §5 POP-5 pop-out commands |
| T28 | `test/widgets/pop_out_window_body_test.dart` | C | — | FD frontend-components §7 |
| T29 | `test/widgets/caption_display_controls_test.dart` | C | — | FD frontend-components §2 (returns are unaffected by `controls`) |
| T30 | `test/helpers/fake_window_configurator.dart` | C | — | NFR-R §1.4 |
| T31 | `test/helpers/fake_sub_window_closed_channel.dart` | C | — | NFR-R §1.4 |
| T32 | `test/helpers/fake_pop_out_bridge.dart` | C | — | NFR-R §1.4 |
| T33 | `test/helpers/fake_overlay_method_handler_installer.dart` | C | — | NFR-R §1.4 |
| T34 | `test/output/overlay/refactor_fence_test.dart` | C | — | NFR-R §5.1 (the three greps as a test: no app imports the plugins; `window_manager` absent; the barrel is not re-exported) |

### 2.4 `zip_broadcast` production and tests

| # | Path | C/M/MV/D | Source | Source (stage) |
|---|---|---|---|---|
| B01 | `lib/src/output/overlay/caption_overlay_target.dart` | M | (stays) | imports only (FD §1.1, BR-U8.1-03) |
| B02 | `lib/src/output/overlay/caption_position.dart` | D | → C03 | Q12 A. **Note**: `external_display_controls.dart` and `zb_app_shell.dart` import `CaptionPosition` from here; both are re-pointed to `package:zip_core/overlay.dart` in the same commit. FD BLM §1 says `CaptionPosition` "stays"; the unit keeps the **type** in the app's dependency graph — it now lives in `zip_core` and the app reads it through the barrel. The type has no app-specific behaviour and the alternative (two `CaptionPosition` types) contradicts BR-U8.1-03. Recorded for morning review: FD BLM §1's "stays" meant "not a pop-out concern", not "duplicate the enum". |
| B03 | `lib/src/output/overlay/{caption_overlay_codec,caption_overlay_snapshot,desktop_multi_window_service*,desktop_window_service,display_enumerator,display_info*,external_display_status,overlay_activity,overlay_event,overlay_window_bridge*,overlay_window_controller,overlay_window_entry,overlay_window_mode,screen_retriever_display_enumerator*}.dart` (23 file paths) | D | → C01-C21, C24 | Q12 A |
| B04 | `lib/src/models/overlay_config.dart` | M | (stays) | becomes the one-line re-export shim: `export 'package:zip_core/src/models/overlay_config.dart';` | FD BLM §1 (Q3 A) |
| B05 | `lib/src/models/overlay_position.dart` | M | (stays) | one-line re-export shim | FD BLM §1 |
| B06 | `lib/src/models/overlay_config.freezed.dart` | D | → C25 | the generated part moves with its source |
| B07 | `lib/src/providers/overlay_window_controller_provider.dart` | M | (stays) | `overlayWindowControllerProvider` → `host.createController(mode: ExternalDisplayMode(), logPrefix: 'zip_broadcast.OverlayWindowController')`; **adds** `popOutWindowControllerProvider`; `displayList` → `host.displays`; `externalDisplayStatus` unchanged | NFR-D §2 |
| B08 | `lib/src/providers/broadcast_engine_available_provider.dart` | C | — | FD §3.1 (RQ-2 A; A-4) |
| B09 | `lib/src/providers/pop_out_event_provider.dart` | C | — | FD BLM §5 (the shell's `popOutEnabled` field stays, but the `PopOutToggled` route and the state need one provider so the in-window toggle can be wired without a second owner) |
| B10 | `lib/src/output/overlay/pop_out_caption_target.dart` | C | — | FD §1.3, §2.1; Q5 A |
| B11 | `lib/src/widgets/pop_out_controls.dart` | C | — | FD frontend-components §3 |
| B12 | `lib/src/widgets/pop_out_in_surface_toggle.dart` | C | — | FD frontend-components §4 |
| B13 | `lib/src/widgets/pop_out_banner.dart` | C | — | FD frontend-components §5 |
| B14 | `lib/src/shell/zb_app_shell.dart` | M | (stays) | `_popOutTarget`, `_popOutRegistered`, `_popOutEnabled`, `_onPopOutEvent`, `_syncPopOut`, `_togglePopOut`; a second `events` subscription; the chrome toggle in `AppBar.actions` and in the rail's trailing column; `_syncOverlay` untouched | FD §2.1; FD BLM §5 |
| B15 | `lib/src/shell/zb_nav_rail.dart` | M | (stays) | a `Widget? headerAction` slot rendered above the trailing settings button (Q7 A's "wide-rail header action"; the rail has **no** header row today — verified — so the slot is additive and its position is fixed here) | FD frontend-components §3 |
| B16 | `lib/src/screens/recording_screen.dart` | M | (stays) | `PopOutBanner` above the surface; `CaptionDisplayWidget(controls: …)` | FD frontend-components §1 |
| B17 | `lib/src/widgets/external_display_controls.dart` | M | (stays) | imports only (`CaptionPosition`, overlay types now from `package:zip_core/overlay.dart`) | FD §2.1 |
| B18 | `lib/main.dart` | M | (stays) | `overlayWindowMain(args)` unchanged in shape (the pop-out path is the same predicate); no `runZipCaptions` here (ID-1: the asymmetry is deliberate) | ID §5 |
| B19 | `l10n/arb/app_en.arb` + generated `lib/src/l10n/zip_broadcast_localizations{,_en}.dart` | M | (stays) | the seven keys of §5.1 (generated files by `flutter gen-l10n`, never hand-edited) |
| B20 | `macos/Runner/MainFlutterWindow.swift` | M | (stays) | ID §4a/§4b/§4c macOS: `configure` handler, `willClose` observer, main-engine close channel | ID §9 |
| B21 | `windows/runner/flutter_window.cpp` | M | (stays) | ID §4: `configure` handler, top-level-proc delegate, main-engine channel in `OnCreate`. **`.h` unchanged** (the delegate and the map live in the .cpp as function-local statics; nothing is added to the class) | ID §9 |
| B22 | `linux/runner/my_application.cc` | M | (stays) | ID §4: `configure` handler, `"destroy"` hook, main-engine channel | ID §9 |
| B23 | `test/helpers/generators.dart` | M | (stays) | stops carrying the overlay generators (now in `zip_core`'s `overlay_generators.dart`); keeps the app's own generators | FD BLM §7 shape change 4 |
| B24 | `test/helpers/pbt.dart` | — | (unchanged) | byte-identical to `zip_core`'s copy already |
| B25 | `test/output/overlay/external_display_redaction_test.dart` | M | (stays) | imports only (the redaction audit stays in the app that owns the shell) |
| B26 | `test/output/caption_overlay_target_test.dart` | M | (stays) | FD BLM §7 shape change 2: import paths only |
| B27 | `test/widgets/overlay_window_app_test.dart` | M | → T08 sibling | FD BLM §7 shape change 1/2: the unavailable-frame assertion now injects the copy; the external-display render assertions stay in the app |
| B28 | `test/widgets/external_display_controls_test.dart` | M | (stays) | imports only |
| B29 | `test/shell/zb_app_shell_test.dart` | M | (stays) | imports only + the pop-out wiring cases are added in B30 |
| B30 | `test/shell/pop_out_shell_test.dart` | C | — | FD §2.1; §8.8 items 1, 2, 7, 11, 14 per app |
| B31 | `test/widgets/pop_out_controls_test.dart` | C | — | FD frontend-components §3, §6; §8.8 items 1, 3, 5, 6 |
| B32 | `test/widgets/pop_out_banner_test.dart` | C | — | FD frontend-components §5; §8.8 item 7 |
| B33 | `test/output/overlay/pop_out_caption_target_test.dart` | C | — | FD BLM §3.1; BR-PIP-04/05 |
| B34 | `test/providers/broadcast_engine_available_test.dart` | C | — | FD §3.1; A-4 (parity with `home_screen.dart:30`) |
| B35 | `test/helpers/fake_overlay_host.dart` | C | — | the app-side test seam: a fake host returning controllers on fakes |

### 2.5 `zip_captions` production and tests

| # | Path | C/M/MV/D | Source | Source (stage) |
|---|---|---|---|---|
| Z01 | `lib/src/bootstrap.dart` | C | — | ID §5; BR-U8.1-06 (`runZipCaptions(args, {runApp, isWeb})`) |
| Z02 | `lib/main.dart` | M | (stays) | `Future<void> main(List<String> args)` delegating in one line | ID §5 |
| Z03 | `lib/src/providers/captions_engine_available_provider.dart` | C | — | FD §3.1 (`ref.watch(sttEngineProvider) != null`) |
| Z04 | `lib/src/providers/pop_out_notifier.dart` | C | — | NFR-D §4.3 (keepAlive `Notifier<bool>`) |
| Z05 | `lib/src/providers/overlay_window_controller_provider.dart` | C | — | NFR-D §2 (same shape as B07) |
| Z06 | `lib/src/output/overlay/pop_out_caption_target.dart` | C | — | FD §2.2; Q5 A |
| Z07 | `lib/src/widgets/pop_out_controls.dart` | C | — | FD frontend-components §3 (Zc copy, through `ZcStrings`) |
| Z08 | `lib/src/widgets/pop_out_in_surface_toggle.dart` | C | — | FD frontend-components §4 |
| Z09 | `lib/src/widgets/pop_out_banner.dart` | C | — | FD frontend-components §5 |
| Z10 | `lib/src/shell/zc_app_shell.dart` | M | (stays) | becomes a `ConsumerStatefulWidget`: owns the target and the events subscription; the flag stays in `popOutNotifierProvider` (NFR-D §4.3's correction to the FD row) | FD §2.2; NFR-D §4.3 |
| Z11 | `lib/src/shell/zc_nav_rail.dart` | M | (stays) | the additive `Widget? headerAction` slot (same shape as B15) | Q7 A |
| Z12 | `lib/src/screens/recording_screen.dart` | M | (stays) | banner + `controls:` | FD frontend-components §1 |
| Z13 | `lib/src/screens/viewer_screen.dart` | M | (stays) | `controls: null` made explicit with a comment naming the FD §7 scope note (viewer pop-out out of scope) | FD frontend-components §7 |
| Z14 | `lib/src/l10n/zc_strings.dart` | M | (stays) | seven getters (ARB reader, not gen-l10n) | FD §2.2; §3.2 |
| Z15 | `l10n/arb/app_en.arb` | M | (stays) | the seven keys + `overlayWindowUnavailable` (§5.2) |
| Z16 | `macos/Runner/MainFlutterWindow.swift` | M | (stays) | gains `import desktop_multi_window`, the callback, the close channel (ID §9) |
| Z17 | `windows/runner/flutter_window.cpp` | M | (stays) | gains the include, the callback, the close channel. **`.h` unchanged** | ID §8, §9 |
| Z18 | `linux/runner/my_application.cc` | M | (stays) | gains the include, the callback (with **no** styling strip — the callback is mode-blind and `configure` decides), the close channel | ID §8, §9 |
| Z19 | `test/helpers/fake_pop_out_collaborators.dart` | C | — | controllers on fakes, a recording `runApp` | NFR-R §1.4; A5 |
| Z20 | `test/bootstrap_test.dart` | C | — | BR-U8.1-06 (overlay path never reaches Supabase/prefs/logging/GoogleFonts/container) |
| Z21 | `test/output/overlay/pop_out_caption_target_test.dart` | C | — | BR-PIP-04/05 (matching test with B33) |
| Z22 | `test/widgets/pop_out_controls_test.dart` | C | — | §8.8 items 1, 3, 5, 6 per app |
| Z23 | `test/widgets/pop_out_banner_test.dart` | C | — | §8.8 item 7 per app |
| Z24 | `test/widgets/pop_out_shell_test.dart` | C | — | §8.8 items 1, 2, 7, 11, 14 per app |
| Z25 | `test/widgets/pop_out_redaction_test.dart` | C | — | BR-PIP-11; §8.8 item 18 |
| Z26 | `test/widgets/viewer_screen_test.dart` | M | (stays) | a case asserting `controls: null` (no pop-out control in the viewer) | FD frontend-components §7 |

### 2.6 Counts

| Group | Created | Moved | Modified | Deleted |
|---|---|---|---|---|
| `zip_core` production (§2.1/§2.2) | 15 (C26-C38, C42) | 26 (C01-C23 = 23 source files + C24/C25/C40 = 3 regenerated-or-moved tool/widget files) | 1 (`caption_display_widget`, C41) + the 11 M rows in §2.2 (all inside the moved set, not additional files) | 0 |
| `zip_core` tests (§2.3) | 20 (T15-T34) | 14 (T01-T14) | 0 | 0 |
| `zip_broadcast` (§2.4) | 12 (B08-B13, B30-B35) | 0 | 19 (B01, B04, B05, B07, B14-B23, B25-B29) | 24 paths (B02's 1 + B03's 23) |
| `zip_captions` (§2.5) | 15 (Z01, Z03-Z09, Z19-Z25) | 0 | 11 (Z02, Z10-Z18, Z26) | 0 |
| **Total** | **62** | **40** | **31 owned changes (+1 no-op row B24)** | **24** |

**Row-count identity.** §2.1-§2.5 contain 42 + 11 + 34 + 35 + 26 = 148 table rows; 62 created + 40
moved + 31 modified + 3 `zip_broadcast` delete rows (`B02`, `B03`'s 23 paths, `B06`) + the one
cross-reference row `B24` ("unchanged", `—`) + §2.2's 11 M rows (the same files as their C rows,
listed again by design) = 148.

**Note on tool-generated files.** C24/C25, C40 and B06 are moved or regenerated, and the
`l10n`/registrant outputs are generated too. §2.1 lists them as moved because `git diff -M` will show
them as renames; §2.6's "Created" count is the hand-authored set only (C26-C38 + C42 = 15, plus the
`caption_display_widget` edit which is Modified). Generated files are produced by the step that
regenerates them and are **not** authored, so they are excluded from the authored counts and reported
separately in the Part 2 summary as `git status --short` evidence.

**The moved set, for the `git diff -M` R100 proof (§4.4).** Twenty-three app files move
(`caption_overlay_codec`, `caption_overlay_snapshot`, `caption_position`, `desktop_multi_window_service`,
`desktop_multi_window_service_io`, `desktop_multi_window_service_stub`, `desktop_window_service`,
`display_enumerator`, `display_info`, `external_display_status`, `overlay_activity`, `overlay_event`,
`overlay_window_bridge`, `overlay_window_bridge_io`, `overlay_window_bridge_stub`,
`overlay_window_controller`, `overlay_window_entry`, `overlay_window_mode`,
`screen_retriever_display_enumerator`, `screen_retriever_display_enumerator_io`,
`screen_retriever_display_enumerator_stub`, `overlay_config`, `overlay_position`), with
`display_info.freezed.dart` and `overlay_config.freezed.dart` following their sources, and one file
moving across directories (`widgets/overlay_window_app.dart`). Of the 23 source files, **13** are
allowed a non-R100 diff (they are the ones named in §2.2: `overlay_window_controller`,
`overlay_window_mode`, `caption_overlay_codec`, `caption_overlay_snapshot`, `overlay_config`,
`overlay_window_entry`, `overlay_window_app`, `overlay_event`, `overlay_window_bridge`, `..._io`,
`..._stub`, `desktop_multi_window_service`, `..._io`), and **10** must be R100 (`caption_position`,
`desktop_window_service`, `display_enumerator`, `display_info`, `external_display_status`,
`overlay_activity`, `screen_retriever_display_enumerator`, `..._io`, `..._stub`,
`desktop_multi_window_service_stub`,
`overlay_position` — where `desktop_multi_window_service_stub` is import-path-only, since §2.2 lists
only the `_io` half of that triplet as changed). `overlay_config.freezed.dart` and
`display_info.freezed.dart` are regenerated and are therefore **not** required to be R100, but their
diff must be import-path-only. The
thirteen test files (T01-T14) move with import-path edits only except T01, T02, T05, T08 (the four
shape changes of §4.2).

---

## 3. Test list

### 3.1 The moved suite (BR-U8.1-01)

Every `zip_broadcast` overlay test moves to `zip_core` and must pass with **import-path edits only**,
except the five permitted shape changes of FD BLM §7 (mapped to steps in §4.2). T01-T14 above; the
controller suite is the load-bearing one because it asserts `harness.enumerator.isDisposed` at
`:736`/`:749` and therefore proves `dispose()` is unchanged.

### 3.2 The explicit new test list (unit / widget / property)

| # | Test | Kind | Source | Assertion summary |
|---|---|---|---|---|
| N-01 | `overlay_method_router_test.dart` | unit | NFR-R §10.4 layer 1 | each id reaches its own handler; unregister-one leaves the other; first register installs, last unregister clears; duplicate unregister is a no-op; a null `windowIdOf()` never matches |
| N-02 | `two_controller_routing_test.dart` | unit (two real controllers) | NFR-R §10.4 layer 2 | `(m, 7)` → A only; `(m, 9)` → B only; after A closes `(m, 7)` is seen by **neither**; `(m, 9)` still reaches B |
| N-03 | `display_enumerator_lease_test.dart` | unit | NFR-D §3 | last release disposes the shared instance; an earlier release does not; double release is a no-op; `host.dispose()` disposes regardless and a later release is then a no-op |
| N-04 | `sub_window_closed_channel_test.dart` | unit | NFR-D §5.2 | wrong method / non-map / non-int / negative id → dropped, nothing emitted; valid → one id, in arrival order; `dispose()` closes the stream |
| N-05 | `window_configurator_test.dart` | unit | FD §1.2.1; NFR-R §1.2 items 3-4 | the test build is a no-op stub; a throwing fake never escapes; the io class catches and logs a fixed string |
| N-06 | `pop_out_mode_codec_test.dart` | unit + property | FD §5 POP-6 | each mode's token decodes to its own type; the other token decodes to the other type; an unknown token is `null` |
| N-07 | `pop_out_geometry_test.dart` | unit (table) | FD §5 POP-4; NFR-D §2.3 | the chrome-allowance table per platform + the unknown-platform zero; content height unchanged by the allowance; the clamp cases; `minWidth`/`minHeight` |
| N-08 | `pop_out_geometry_properties_test.dart` | property | FD §5 POP-4 | width in `[minWidth, workArea.width]`; height `>= minHeight`; width monotone non-decreasing in work-area width; height monotone non-decreasing in text scale |
| N-09 | `pop_out_availability_test.dart` | unit (exhaustive table) | FD §5 POP-7 | for every `(status × 5 recording states × engine bool)`: `visible == status is! Unsupported`, `enabled == sessionActive && enginePresent`, `reason` precedence (engine over session); the three concrete states, never the `ActiveSessionState` mixin |
| N-10 | `pop_out_controller_test.dart` | unit | FD BLM §2/§3.2/§3.3/§3.4 | six guards: display event while open keeps the frame; empty list while open does not close; empty list while opening does not fail; `_runReady` uses the supplied `frame`; `open()`/`_runOpen` never report `NoDisplays`; `_bootstrap` needs no display. Close channel: matching id → `WindowClosed` + `Off`; unknown id → dropped; late event after `_takeWindow()` → dropped. Toggle: `'popOutToggle'` → `PopOutToggled`. Mode fixed at construction: `open()` with the other mode's config → `create_failed`. Missing frame + pop-out → no `setFrame`, one `FINE` log, still `Open` |
| N-11 | `pop_out_state_machine_properties_test.dart` | property (stateful) | FD §5 POP-5 | `openPopOut`/`toggleAgain`/`toggleOff`/`windowGone`/`displayEvent`/`elapse`: at most one window, one state, no second `createWindow` while `Opening`/`Open`, declared variants only |
| N-12 | `pop_out_window_body_test.dart` | widget | FD frontend-components §7 | standby = empty surface; live/paused render through `CaptionDisplayWidget`; the injected toggle is present and its callback fires; no caption text in any key/semantics label; theme swap changes the surface colour |
| N-13 | `caption_display_controls_test.dart` | widget | FD frontend-components §2; R-M4 | `controls: null` renders identically to today (list only); `controls: w` renders `w` **outside** the `ListView` and it stays visible after ten entries and after scrolling; `reverse: true` likewise |
| N-14 | `refactor_fence_test.dart` | static | NFR-R §5.1; BR-U8.1-02 | no app `lib/` file imports `package:desktop_multi_window` or `package:screen_retriever`; `window_manager` appears nowhere; `zip_core.dart` does not export `overlay.dart`. **Same file as T34** (N-14 is its §3.2 test-list name; T34 is its §2.3 file-table id); one file, one step (18) |

Per-app (§8.8's clause), each asserted in **both** apps' trees:

| # | App-level test | Items | Both apps |
|---|---|---|---|
| A-01 | `pop_out_controls_test.dart` | 1 (chrome toggle, two labels, state), 3 (visibility), 5 (no session), 6 (no engine) | B31 + Z22 |
| A-02 | `pop_out_banner_test.dart` | 7 (hint + return, clears on close) | B32 + Z23 |
| A-03 | `pop_out_shell_test.dart` | 1, 2 (in-surface toggle drives the same path; the pop-out's own toggle routes through the bridge), 7, 11 (drawer closes), 14 (double toggle) | B30 + Z24 |
| A-04 | `pop_out_caption_target_test.dart` | 4 (recognition continues), 5 (content is live) | B33 + Z21 |
| A-05 | redaction audit | 18 | B25 (existing) + Z25 (new) |
| A-06 | `bootstrap_test.dart` (captions only) | BR-U8.1-06 | Z20 |

### 3.3 Property list (POP-1..POP-8) and where each lives

| Property | File | Step |
|---|---|---|
| POP-1 launch round-trip (both modes) | `caption_overlay_codec_properties_test.dart` (moved) + `pop_out_mode_codec_test.dart` | 11, 14 |
| POP-2 decode total-on-error | `caption_overlay_codec_properties_test.dart` (moved) | 11 |
| POP-3 size bound | idem | 11 |
| POP-4 `popOutSize` invariants | `pop_out_geometry_properties_test.dart` | 8 |
| POP-5 state-machine closure (Unit 8 `_World` moved + pop-out commands) | `display_state_machine_properties_test.dart` (moved, extended) + `pop_out_state_machine_properties_test.dart` | 11, 13 |
| POP-6 mode-token round-trip, no cross-talk | `pop_out_mode_codec_test.dart` | 14 |
| POP-7 availability matrix — **table test, not generated** (finite 7x5x2 domain, 70 cells) | `pop_out_availability_test.dart` | 9 |
| POP-8 `toPlatformFrame` invariants (unchanged, moved) | `to_platform_frame_properties_test.dart` (moved) | 11 |

**Framework**: the in-tree shim `packages/zip_core/test/helpers/pbt.dart` — `Generator<T>`, the `any`
generators, `Glados<T>(gen).test(...)`, 100 fixed seeds `0..99`, async bodies, **no shrinking**, seed
printed on failure. There is no `glados` dependency and none is added (PBT-09). Counterexamples are
hand-reduced and pinned as example tests (PBT-10). `fake_async` and `mocktail` are used in `zip_core`
and `zip_broadcast` only; `zip_captions` uses `testWidgets` + `tester.pump` + hand-written fakes.

**Hand-written fakes** (NFR-R §1.4), all in `zip_core/test/helpers/`: `FakeWindowConfigurator`
(records `(windowId, config)` into a shared ordering log, can throw), `FakeSubWindowClosedChannel`
(broadcast controller + recorded `install`/`dispose`), `FakePopOutBridge` (records `send`/
`sendPopOutToggle`, can push a `captionUpdate`), `FakeOverlayMethodHandlerInstaller` (records
install/uninstall, exposes the handler), plus the moved `FakeDisplayEnumerator`. `zip_broadcast` and
`zip_captions` get their own app-side fakes only (`fake_overlay_host.dart`,
`fake_pop_out_collaborators.dart`).

---

## 4. The five permitted shape changes (FD BLM §7) mapped to steps and tests

BR-U8.1-01: a moved test may change shape for these five reasons only. Each is mapped here so Part 2
can prove it mechanically.

| # | Shape change (FD BLM §7) | Files | Step | Test that proves it |
|---|---|---|---|---|
| 1 | `zip_core` has no ARB, so `OverlayWindowUnavailableApp` takes the copy (`required String message`) and the entry/window tests assert on the injected string | `overlay_window_entry.dart`, `overlay_window_app.dart`, `overlay_window_entry_test.dart`, `overlay_window_app_test.dart` | 9, 10 | T08, B27: the assertion still proves the frame renders and ready is never sent |
| 2 | `caption_overlay_target_test.dart` and `overlay_window_app_test.dart` stay in `zip_broadcast` where the target/app is app-level; `OverlayWindowApp` moves with its unavailable-copy assertions | `test/output/caption_overlay_target_test.dart`, `test/widgets/overlay_window_app_test.dart` | 4, 10 | B26, B27 |
| 3 | `helpers/mock_desktop_window_service.dart` needs no new stubs (`DesktopWindowService` gains nothing); an unused stub, if surfaced, is deleted rather than added | `zip_broadcast/test/helpers/mock_desktop_window_service.dart` | 4 | B26's suite compiles with the class unchanged |
| 4 | the overlay generators are **duplicated** into `zip_core/test/helpers/overlay_generators.dart` (an app cannot import another package's `test/`), and `zip_broadcast`'s copy shrinks to what its own tests need | `zip_core/test/helpers/overlay_generators.dart`, `zip_broadcast/test/helpers/generators.dart` | 3, 4 | T15; B23; both suites green |
| 5 | injecting a `WindowConfigurator` fake into `overlayWindowMain`/`OverlayWindowEntry` — an additive call-site change in the test, not a change to what it asserts | `overlay_window_entry_test.dart`, `test/helpers/fake_window_configurator.dart` | 9, 12 | T08, T30 |

Any other diff in a moved file is BLOCKED. Part 2 checks this with `git diff -M --summary` (§4.4) and
records the mapping in the code summary.

### 4.1 What must be byte-for-byte unchanged in the moved controller

`dispose()` (its `_enumerator.dispose()`, `_handlerInstaller?.call(null)` and `closeWindow` order),
`_release`, `_windowCall`, `_setState`, `_takeWindow`, the T1-T17 transitions, the coalescer, the
ready timer, `resolveOpenDisplay` and the constants. The seven deviations are additive branches or
new members, listed in §2.2's M01. The lease and the token-bound installer are what make `dispose()`
literally unchanged (NFR-D §3).

### 4.2 Order of the move (why the steps are sequenced this way)

The promotion is done in **four** commits so each intermediate tree compiles:

1. **P1** add the new `zip_core` contracts that do not depend on the moved code (router, lease,
   channel, configurator, config model, geometry, availability) with their tests (steps 11-17
   partially — see the step list for the exact split).
2. **P2** `git mv` the machinery + its tests into `zip_core`, fix import paths, add the seven
   deviations on top, and keep `zip_broadcast` compiling by adding the one-line shims where a
   consumer still needs the old path (`overlay_config`, `overlay_position`) — at the end of P2 the
   app no longer owns any machinery (BR-U8.1-03).
3. **P3** the new `zip_core` features (pop-out mode, geometry wiring, entry/body changes) and the
   host provider.
4. **P4** the two apps: providers, targets, widgets, shells, shells' chrome, l10n, runners.

### 4.3 The router / host / lease wiring (pinned for Part 2)

```
overlayWindowHostProvider  (@Riverpod(keepAlive: true), zip_core)
  -> OverlayWindowHost(router, enumerator, channel)
       .createController({required OverlayWindowMode mode, required String logPrefix})
          -> OverlayWindowController(
               windowService: DesktopMultiWindowService.withEnumerator(lease),
               enumerator: lease,
               handlerInstaller: router.installerFor(token),
               log: Logger(logPrefix),
               configurator: ...,        // not on the controller: see note
             )
```

The controller does **not** take a `WindowConfigurator`: the configurator lives in the **sub-engine**
(`overlayWindowMain`), which is the only place it runs (FD BLM §3.2 step 6; R-M9). The host passes
the router's token-bound installer and the lease; the controller subscribes to the host's close
channel in `_bootstrap` and cancels in `dispose()`.

**`open()`'s signature**: `Future<void> open(OverlayConfig config, {String? persistedDisplayId, Rect? frame})`.
`persistedDisplayId` is required by the moved tests verbatim; the pop-out ignores it.

### 4.4 The R100 proof

Part 2 runs, on the move commit:

```
git diff -M --summary HEAD~1 HEAD -- packages/zip_broadcast packages/zip_core | grep -E 'rename|similarity'
```

and records one of two verdicts per moved path: `R100` (identical) or "R<100, mapping to §2.2 M-row
N". The 13 test files' import-only moves and the 10 R100 production files must come out `R100`; of
the 14 moved test entries, `fake_display_enumerator.dart` is a helper (T14), and T01, T02, T05, T08
are allowed the shape changes of §4.2.
Any moved file with a diff that is not in §2.2 is BLOCKED.

---

## 5. Strings

### 5.1 `zip_broadcast` — `l10n/arb/app_en.arb` (seven keys, `flutter gen-l10n`)

| Key | Value | Source |
|---|---|---|
| `popOutEnter` | `Picture in Picture` | UX-PIP-01 |
| `popOutExit` | `Exit Picture in Picture` | UX-PIP-01 |
| `popOutHint` | `Captions are displaying in Picture-in-Picture` | UX-PIP-05 |
| `popOutReturn` | `Return to Window` | UX-PIP-05 |
| `popOutUnavailableNoSession` | `Start captioning to pop captions out` | BR-PIP-12 |
| `popOutUnavailableNoEngine` | `No speech recognition engine is available on this device` | BR-PIP-13 |
| `popOutOpenFailed` | `The pop-out window could not be opened` | BR-PIP-03 |

The generated `lib/src/l10n/zip_broadcast_localizations{,_en}.dart` is written by the tool only.

### 5.2 `zip_captions` — `l10n/arb/app_en.arb` (eight keys, read through `ZcStrings`)

The same seven, plus:

| Key | Value | Source |
|---|---|---|
| `overlayWindowUnavailable` | `Window unavailable` | FD §7 shape change 1 (A-6) |

`ZcStrings` gains one getter per key (the app's established mechanism; there is no `gen-l10n` in this
app). `zip_core` has **no** ARB: `OverlayWindowUnavailableApp` takes `message` (A-6).

### 5.3 Copy rules

No key is renamed or removed. No string contains caption text (BR-U8.1-09, BR-PIP-11). Failure copy
is generic; the raw `Failed` reason is never rendered (SECURITY-09).

---

## 6. Numbered, ordered steps (TDD-first)

Each step: **write the failing test first**, confirm it fails for the expected reason, implement,
re-run. One commit per step unless stated. Conventional Commits with the package scope
(`docs/04-technical-specification.md` §7). Steps 1-10 bring the contracts into `zip_core`; 11-18 the
move and its deviations; 19-24 the apps; 25-30 the runners, gates and lockfile review.

### Group A — dependency and new contracts in `zip_core`

- [ ] **1. Dependencies.** Edit `packages/zip_core/pubspec.yaml` (add the two entries + SECURITY-10
  comments), `packages/zip_broadcast/pubspec.yaml` (remove `screen_retriever` and its comment),
  `packages/zip_captions/pubspec.yaml` (add `desktop_multi_window`). Run `flutter pub get` at the
  workspace root and in each package. *Test*: none; the resolution must leave `pubspec.lock` unchanged
  (§1.3) and every package's `flutter test` result unchanged. *Commit*:
  `feat(zip_core): add the window machinery dependencies; zip_captions gains desktop_multi_window`.
- [ ] **2. `OverlayWindowConfig`** (`src/models/overlay_window_config.dart`, freezed). *Test first*:
  T21 (equality, `copyWith`, defaults). *Commit*: `feat(zip_core): add OverlayWindowConfig`.
- [ ] **3. Overlay generators.** Create `zip_core/test/helpers/overlay_generators.dart` by moving the
  overlay half of `zip_broadcast/test/helpers/generators.dart` (display info/list, snapshot, launch,
  malformed JSON, logical frame, command sequence) and adding
  `arbitraryPopOutGeometryInput` and `arbitraryPopOutModeLaunch`. Shrink the app's copy. *Test*: T15's
  generators compile and produce the documented shapes; both packages still analyze clean.
  *Commit*: `test(zip_core): duplicate the overlay generators ahead of the move`.
- [ ] **4. `OverlayMethodRouter` + `OverlayHandlerToken`.** *Test first*: N-01, then N-02 (two real
  controllers are not possible yet, so N-02 lands at step 13 — record the deferral in the commit
  body). *Commit*: `feat(zip_core): add OverlayMethodRouter`.
- [ ] **5. `DisplayEnumeratorLease`.** *Test first*: N-03 (four cases). *Commit*:
  `feat(zip_core): add the reference-counted DisplayEnumeratorLease`.
- [ ] **6. `SubWindowClosedChannel` triplet.** *Test first*: N-04 (validation, silent drop, stream
  order, `dispose`). *Commit*: `feat(zip_core): add the main-engine sub-window close channel`.
- [ ] **7. `WindowConfigurator` triplet.** *Test first*: N-05 (stub no-op, throwing fake never
  escapes, the io class's `on Object` catch). *Commit*: `feat(zip_core): add WindowConfigurator`.
- [ ] **8. `pop_out_geometry.dart`.** *Test first*: N-07 (the allowance table + clamps), then N-08
  (POP-4). Implement `PopOutGeometry`, `popOutSize`, `chromeAllowance`, `computePopOutFrame`.
  *Commit*: `feat(zip_core): add pop-out geometry and chrome allowance`.
- [ ] **9. `pop_out_availability.dart`.** *Test first*: N-09 (the exhaustive table). *Commit*:
  `feat(zip_core): add popOutAvailability`.
- [ ] **10. `overlay.dart` barrel.** Create the barrel exporting the public surface and **not**
  `desktop_multi_window`; do not touch `zip_core.dart` (R-M7). *Test*: T34's third assertion; a
  compile-only test importing the barrel and `zip_core.dart` together (proves no `Failed` collision).
  *Commit*: `feat(zip_core): add the overlay library barrel`.

### Group B — the promotion (the move)

- [ ] **11. `git mv` the 23 production files + 13 test files + `fake_display_enumerator.dart` + the two `.freezed.dart` files.** Rewrite
  imports to `package:zip_core/...`; keep `display_enumerator.dart`'s re-export of `DisplayInfo`;
  delete the sources from `zip_broadcast`; add the two one-line model shims (B04/B05); regenerate
  `build_runner` output. Verify `git diff -M --summary` gives R100 for the 13 R100 files (§4.4).
  *Test*: T01-T14 pass. T01/T02/T05/T08 are allowed their shape changes at steps 12-13; the rest must
  pass **unmodified**. *Commit*: `refactor(zip_core): promote the Unit 8 window machinery (BR-U8.1-01)`.
- [ ] **12. Shape changes 1, 4 and 5 on the moved tests and their subjects.** `OverlayWindowUnavailableApp`
  gains `required String message`; `OverlayWindowApp` gains the injected copy and the shared
  `_themeModeOf`; `overlayWindowMain` gains the optional `windowConfigurator`; `OverlayWindowEntry`
  gains the optional `popOutHost`. *Test first*: T08 with `FakeWindowConfigurator` (ordering) and B27.
  *Commit*: `refactor(zip_core): decouple the window copy and inject the configurator`.
- [ ] **13. The seven controller deviations.** Apply M01 on top of the moved controller: `_isPopOut`
  plus the six guards, the `PopOutToggled` case, `open({Rect? frame})` with (P1) the null-frame
  fallback (`FINE` log, no `setFrame`, still `Open`), mode at construction with the mismatch →
  `create_failed` validation, `router.installerFor(token)` (no signature change), `int? get windowId`,
  `onNativeWindowClosed(int)` and the `_closeChannel` subscription in `_bootstrap` / cancel in
  `dispose()`. *Test first*: N-10, N-11, then N-02 (both controllers now exist). *Commit*:
  `feat(zip_core): add PopOutMode and the seven permitted controller deviations`.

### Group C — the pop-out's `zip_core` pieces

- [ ] **14. `PopOutMode`, `PopOutContentMode`, the codec's `'popOut'` token and `contentMode`.**
  *Test first*: N-06 and T01/T02 updated for both modes. *Commit*:
  `feat(zip_core): encode and decode the pop-out mode`.
- [ ] **15. `PopOutWindowBody` and `CaptionDisplayWidget.controls`.** *Test first*: N-13 (the R-M4
  ordering assertion), then N-12. *Commit*: `feat(zip_core): add the pop-out window body and the controls slot`.
- [ ] **16. The host and its provider.** `overlay_window_host.dart` + `providers/overlay_window_host_provider.dart`
  with `createController`, `Stream<List<DisplayInfo>> get displays`, `dispose()`. *Test first*: N-03's
  host cases move here; a test asserting `createController` wires the lease + token-bound installer +
  the channel. *Commit*: `feat(zip_core): add OverlayWindowHost and its provider`.
- [ ] **17. `OverlayWindowHost`-shaped `_bootstrap` for `PopOutMode`.** The capability rule becomes
  `isSupported && (mode is PopOutMode || displaysAvailable)`; assert with a display-less fake.
  *Test first*: N-10's bootstrap case. *Commit*: `feat(zip_core): let a display-less machine pop out`.
- [ ] **18. `refactor_fence_test.dart`.** *Test*: T34. *Commit*: `test(zip_core): assert the package fence`.

### Group D — `zip_broadcast`

- [ ] **19. Providers.** `broadcast_engine_available_provider.dart` (A-4), the controller providers
  re-based on the host, `pop_out_event_provider.dart`. *Test first*: B34, then B30's provider
  prerequisites. *Commit*: `feat(zip_broadcast): expose the engine gate and the pop-out providers`.
- [ ] **20. `PopOutCaptionTarget`** (copy of `caption_overlay_target.dart:94-102`'s read, L4 B).
  *Test first*: B33. *Commit*: `feat(zip_broadcast): add PopOutCaptionTarget`.
- [ ] **21. Widgets.** `PopOutControls`, `PopOutInSurfaceToggle`, `PopOutBanner`. *Test first*: B31,
  B32. *Commit*: `feat(zip_broadcast): add the pop-out controls and banner`.
- [ ] **22. Shell and rail.** `zb_app_shell.dart`'s members + the chrome toggle in both layouts;
  `zb_nav_rail.dart`'s `headerAction`; `recording_screen.dart`'s banner and `controls:`. *Test first*:
  B30. *Commit*: `feat(zip_broadcast): wire the pop-out into the shell, the rail and the recording screen`.
- [ ] **23. ARB + `flutter gen-l10n`** (§5.1). *Test*: B31/B32 read the generated localizations.
  *Commit*: `feat(zip_broadcast): add the pop-out ARB strings`.

### Group E — `zip_captions`

- [ ] **24. `runZipCaptions` seam + `main`.** `lib/src/bootstrap.dart`: `ensureInitialized`, the
  overlay branch returning before GoogleFonts/logging/SharedPreferences/Supabase/`ProviderContainer`/
  the debug `FakeSttEngine`/the transcript pre-warm; `isWeb` and `runApp` as parameters. `main.dart`
  becomes one line. *Test first*: Z20 (a recording `runApp`, a counting Supabase fake, a throwing
  prefs/pre-warm). *Commit*: `feat(zip_captions): add the runZipCaptions bootstrap seam`.
- [ ] **25. Providers.** `captionsEngineAvailableProvider`, `popOutNotifierProvider`, the controller
  providers. *Test*: Z22/Z24's prerequisites. *Commit*:
  `feat(zip_captions): add the pop-out providers`.
- [ ] **26. Target + widgets.** `PopOutCaptionTarget`, `PopOutControls`, `PopOutInSurfaceToggle`,
  `PopOutBanner`. *Test first*: Z21, Z22, Z23. *Commit*:
  `feat(zip_captions): add the pop-out target, controls and banner`.
- [ ] **27. Shell, rail, screens, strings.** `ZcAppShell` → `ConsumerStatefulWidget` with the target,
  the events subscription and the flag in the notifier; `ZcNavRail`'s slot; `RecordingScreen`'s banner
  and `controls:`; `ViewerScreen`'s explicit `controls: null`; the eight ARB keys and seven
  `ZcStrings` getters. *Test first*: Z24, Z25, Z26. *Commit*:
  `feat(zip_captions): wire the pop-out into the shell and the recording screen`.

### Group F — the six runners

- [ ] **28. `zip_broadcast`'s three runners** (B20-B22) exactly as ID §4a/§4b/§4c/§9 (macOS
  `configure` + `willClose` + main channel; Windows `configure` + `GetRegistrarForPlugin` +
  `RegisterTopLevelWindowProcDelegate` + main channel; Linux `configure` + `"destroy"` + main
  channel). Keep every existing registration and the `WM_FONTCHANGE` branches. No
  `RegisterGeneratedPlugins` inside any callback (R-B1); never replace `window.delegate` or the
  plugin's `WndProc` (R-B2). *Test*: none in Dart; macOS compiles in step 30; Windows/Linux compile in
  CI only. *Commit*: `feat(zip_broadcast): move window styling into the configure channel and add the native close channel`.
- [ ] **29. `zip_captions`' three runners** (Z16-Z18) with the whole callback **new** and the same two
  channels. *Test*: as step 28. *Commit*:
  `feat(zip_captions): add the window-created callback and the overlay channels`.

### Group G — gates

- [ ] **30. Gates, fence greps, move proof, lockfile review, build.**
  1. The three gate pairs from package roots (§7.1).
  2. `rg -l "package:desktop_multi_window|package:screen_retriever" packages/zip_core/lib` → exactly
     the four `_io`/export paths; the same over each app's `lib/` → nothing (except
     `MainFlutterWindow.swift`/`.cpp`/`.cc`, which are native and excluded by `-g '*.dart'`);
     `rg window_manager` over all three packages → nothing.
  3. `rg -l "overlay.dart" packages/zip_core/lib/zip_core.dart` → nothing; `git diff -M --summary` R100
     proof (§4.4).
  4. `git diff pubspec.lock` → empty; `git diff` on the three `Podfile.lock` files → §1.3 only; the ten
     registrants → §1.3 only.
  5. `flutter build macos --debug` in **both** apps (compile only, nothing launched).
  6. Record everything for the Part 2 summary and the PR body. Nothing outside the fence is staged.

---

## 6a. ARB keys per app (summary)

- `zip_broadcast`: seven keys (§5.1) in `l10n/arb/app_en.arb` → `flutter gen-l10n`.
- `zip_captions`: the same seven + `overlayWindowUnavailable` (§5.2) in `l10n/arb/app_en.arb` → read
  through `ZcStrings` (no `gen-l10n`).
- `zip_core`: **none** — `OverlayWindowUnavailableApp` takes `message`.

---

## 6b. Non-goals (hard fences)

- **No `window_manager`** anywhere — not a dependency, not an import, not a file.
- **No change outside**: `packages/zip_core/{lib,test,pubspec.yaml}`,
  `packages/zip_broadcast/{lib,test,l10n,pubspec.yaml}`,
  `packages/zip_captions/{lib,test,l10n,pubspec.yaml}`, the six runner files, and the generated
  outputs/lockfiles of §1.3.
- **Forbidden**: `packages/zip_supabase/`, `window_manager`, any dependency not in §1.2, `.github/`,
  `docs/`, `pip-ux-parity.md`, `aidlc-docs/v1-parity/`, `spikes/`, `opencode.json`, `.agent/`.
- **No eighth controller deviation** and no other change to the moved controller beyond the seven
  (BR-U8.1-01). If Part 2 needs one, **stop and report**.
- **No new dev dependency**; `zip_captions` gets none (`fake_async`/`mocktail` would be BLOCKED).
- **The caption bus and `CaptionOutputTargetRegistry` are untouched** (NFR-D L4 B): no membership
  signal is added; each target copies the shipped read.
- **No `// ignore` anywhere** (applies to generated files' neighbours too — generated files are left
  alone).
- **No persistence of pop-out state, size or position** (Q10 B, BR-PIP-10).
- **No content-setting picker and no orientation/pane-swap/translation controls** in either app
  (§8.8 items 8-10, deferred to Phase 8).
- **No viewer pop-out** (FD frontend-components §7): the viewer keeps `controls: null`.
- **Web is excluded by `DesktopWindowService.isSupported`**, never `kIsWeb` (BR-U8.1-11).
- **No caption text in logs, keys, semantics labels or the window title** (BR-PIP-11, BR-U8.1-09).
- **No native source file added**; no CMake/manifest/Podfile/entitlement edit.
- **Unit 9 manual checks are recorded, never claimed** (§7.3).

---

## 7. Verification

### 7.1 Gates (from package roots — melos is not assumed on PATH)

| Package | Command | Must |
|---|---|---|
| `packages/zip_core` | `dart analyze --fatal-infos && flutter test` | clean; every test passes (the moved suite included) |
| `packages/zip_broadcast` | `dart analyze --fatal-infos && flutter test` | clean; green, including the external-display suite's app-level remainder |
| `packages/zip_captions` | `dart analyze --fatal-infos && flutter test` | clean; green |

Part 2 adds `flutter build macos --debug` in **both** apps (compile only). Windows and Linux runner
code is compiled by CI's `build-verify.yml`, which builds both apps on all three desktops since PR
#40. **CI must be green** before the run hands off (that is Stage 3's push, not this stage's).

### 7.2 What this stage can and cannot verify

| Claim | How | Status |
|---|---|---|
| The plan is a strict transcription | §8 self-check tables, zero open questions | **this stage** |
| The move is mechanical | `git diff -M --summary` (§4.4) | Part 2 |
| `dispose()` is unchanged | the moved controller test (`:721-749`) passes verbatim | Part 2 |
| The fence holds | T34 + the step-30 greps | Part 2 |
| macOS native code compiles | `flutter build macos --debug`, both apps | Part 2 |
| Windows/Linux native code compiles | CI `build-verify.yml` | after the push |
| The window floats, is decorated, honours its minimum, clears on OS close | Unit 9 manual checks | **never claimed here** |

### 7.3 Unit 9 manual checks (recorded, never claimed) — eight

1. The pop-out floats above other apps per platform, including the macOS full-screen limitation and
   Linux WM behaviour (A7 item 1 / §8.8 item 15).
2. Decorated, resizable, movable, minimum size honoured (A7 item 2 / item 13).
3. The chrome-allowance constants measured against two rendered lines plus the toggle row (A7 item 3;
   A-1).
4. An OS close clears the banner and toggle in the same frame — **no Linux `'-1'` degradation
   recorded** (A7 item 4; ID §2.4).
5. The external display is still borderless after the `configure` move (A7 item 5).
6. Pop-out placement on a multi-monitor desk (primary, bottom-centre) (A7 item 6; A-2).
7. The in-surface toggle works from inside the pop-out window (A7 item 7).
8. Windows and Linux runner behaviour generally (compile-verified only) (A7 item 8).

---

## 8. Self-check

### 8.1 S-21 acceptance criteria → steps/tests

| AC (S-21) | Applies | Steps | Evidence |
|---|---|---|---|
| Toggling the chrome control opens a small window showing live captions; the control reads "Exit Picture in Picture" | both | 19-23, 25-27, 28-29 | A-01, A-03, N-10 (`Opening` same-frame target) |
| The window remains above other applications and keeps updating | both | 13, 28-29 | **Unit 9 check 1** (not claimed); updating: A-04, N-10's coalescer (moved) |
| The in-surface toggle inside the pop-out returns captions and closes the window | both | 14, 21, 26, 28-29 | A-03 (bridge → `popOutToggle` → shell), N-10 |
| OS close leaves the main window coherent and the caption controls working | both | 13, 22, 27, 28-29 | N-10 (matching id → `WindowClosed`), A-03; same-frame is **Unit 9 check 4** |
| Theme, layout and text-appearance changes reach the window live, no reopen | both | 14, 15 | N-12 (theme swap), the snapshot carries `DisplaySettings` (moved codec) |
| A second toggle creates no second window | both | 13 | N-10, N-11, A-03 |
| After the promotion the external display behaves exactly as before | broadcast | 11-13 | T01-T14 pass; B26, B27, B28 unchanged in behaviour |
| Web: the pop-out control is not offered | both | 9, 21, 26 | N-09 (`Unsupported`), the stub exports |
| No caption text in the logs on any pop-out path | both | 22, 27 | A-05 (B25 existing + Z25 new), N-10's fixed-string logs |

### 8.2 BR-PIP / BR-U8.1 → steps/tests

| Rule | Steps | Tests |
|---|---|---|
| BR-PIP-01 one pop-out window, one per mode | 13, 16 | N-10, N-11, N-02 |
| BR-PIP-02 toggle idempotent (no UI flag) | 13, 22 | N-10, A-03 |
| BR-PIP-03 closing by any means leaves a coherent state | 13, 22, 27 | N-10 (three close paths), A-02, A-03 |
| BR-PIP-04 recognition continues | 20, 26 | A-04 |
| BR-PIP-05 content is live, not copied | 20, 26 | A-04 |
| BR-PIP-06/07/08 deferred (Phase 8) | — | recorded in §8.5, not claimed |
| BR-PIP-09 live update on setting change | 14, 15 | N-12, the snapshot carrying `DisplaySettings` |
| BR-PIP-10 no persistence | 19, 25, 27 | no settings write in any pop-out step (asserted by A-03's "no prefs write" case) |
| BR-PIP-11 no caption text in logs | 20, 22, 26, 27 | A-05 |
| BR-PIP-12 capability and recognition are separate gates | 9, 19, 25 | N-09, B34, Z22 |
| BR-PIP-13 engine-unavailable is disabled with a reason | 19, 25 | B34, A-01 |
| BR-PIP-14 restated, no implementation | — | no manual-text-entry source is added (§6 fence) |
| BR-U8.1-01 external display unchanged; five shape changes only | 11-13 | §4's table, §4.4's proof |
| BR-U8.1-02 `zip_core` platform-agnostic | 1, 11, 18 | T34 + step-30 greps |
| BR-U8.1-03 one implementation | 11, 19, 25 | the app's machinery files are deleted (B03); only adapters/toggles/ARB stay |
| BR-U8.1-04 one handler owner per engine | 4, 13, 16 | N-01, N-02 |
| BR-U8.1-05 a window's own settings applied in its own engine | 7, 12, 28-29 | T08's ordering assertion, N-05 |
| BR-U8.1-06 the sub-engine never initialises app services | 24 | Z20 |
| BR-U8.1-07 both apps or not done | 19-29 | A-01..A-05 in both trees |
| BR-U8.1-08 codec total and versioned, no bump | 14 | N-06, T01, T02 |
| BR-U8.1-09 no caption text in the title or error pages | 12, 15 | T08, N-12 (`_themeModeOf`, no `title`) |
| BR-U8.1-10 deferred items recorded, not claimed | — | §8.5's table |
| BR-U8.1-11 desktop only | 9, 21, 26 | N-09, the `_stub` exports |
| BR-U8.1-12 Linux keep-above is the WM's to honour | 28 | recorded; N-05's throw path; **Unit 9 check 1** |

### 8.3 `pip-ux-parity.md` §8.8, one row per item, per app

`tested` / `platform-check (Unit 9)` / `deferred (Phase 8)`. §8.8's own partition is binding
("items 1-3, 5-11, 14, and 18 are unit- or widget-testable. Items 4, 12, 13, 15, 16, and 17 require
platform-level verification").

| Item | Zip Broadcast | Zip Captions |
|---|---|---|
| 1 chrome toggle, two labels, reflects state | `tested` (B31, B30) | `tested` (Z22, Z24) |
| 2 in-surface toggle usable from the pop-out | `tested` (A-03: bridge → shell) | `tested` (A-03) |
| 3 visibility rule in all combinations | `tested` (N-09 + B31) | `tested` (N-09 + Z22) |
| 4 control absent (not disabled) when the platform cannot | `platform-check (Unit 9)` — asserted at the `popOutAvailability` level (`Unsupported` → not visible), the platform-level absence is the check | same |
| 5 disabled + reason, no active session | `tested` (A-01) | `tested` (A-01) |
| 6 disabled + reason, no engine | `tested` (B34 + A-01) | `tested` (Z03 + A-01) |
| 7 hint + return, clears on close | `tested` (A-02) | `tested` (A-02) |
| 8 content setting offers three options, applies only with translation | `deferred (Phase 8)` | `deferred (Phase 8)` |
| 9 content setting updates the live pop-out | `deferred (Phase 8)` | `deferred (Phase 8)` |
| 10 orientation/pane swap/translation/download inside the pop-out | `deferred (Phase 8)` | `deferred (Phase 8)` |
| 11 opening closes the drawer | `tested` (B30) | `tested` (Z24) |
| 12 theme matches on open, updates live | `platform-check (Unit 9)` (the widget-level swap is N-12; cross-engine is the check) | same |
| 13 opens at the Q9-amended geometry and is resizable | `platform-check (Unit 9)` (geometry is N-07/N-08; the rendered size is the check) | same |
| 14 only one pop-out; double toggle | `tested` (N-10, N-11, B30) | `tested` (N-10, N-11, Z24) |
| 15 stays above other application windows | `platform-check (Unit 9)` | `platform-check (Unit 9)` |
| 16 OS close leaves the main window coherent | `platform-check (Unit 9)` (the synchronous channel is N-10; the real close is the check) | same |
| 17 recognition continues across pop-out and return | `platform-check (Unit 9)` (A-04 asserts the state is untouched; a live session is the check) | same |
| 18 no caption text in logs | `tested` (B25) | `tested` (Z25) |

**Note on items 4, 12, 13, 16, 17.** Each has both a unit-level assertion (the rule's mechanism) and a
platform check (the visible result). Both are recorded; only the unit-level half is claimed here.
This is stricter than §8.8's partition, not looser.

### 8.4 NFR-R / NFR-D obligations → steps

| Obligation | Step |
|---|---|
| NFR-R §1.2 items 1-3 (configure ordering, both modes' arguments, throwing still ready) | 12, 28-29 |
| NFR-R §1.2 close-notification assertions (match, unknown id, late event) | 13 |
| NFR-R §2's two ordering targets (`Opening` same frame; configure before show) | 22, 27, 12 |
| NFR-R §3.1 failure policy rows | 13, 14 |
| NFR-R §5.1 the three refactor checks | 11, 18, 30 |
| NFR-R §5.2 the barrel | 10 |
| NFR-R §6 accessibility (visible label, `Semantics`, 44x44, no colour-only state) | 21, 26 |
| NFR-R §8 PBT-01..PBT-10 | §3.3 |
| NFR-D §3 the four lease tests | 5 |
| NFR-D §4 the router's two layers + the token-bound installer | 4, 13 |
| NFR-D §4.3 the flag's two writers | 19, 27 |
| NFR-D §5.1/§5.2 both channels' validation | 6, 7, 28-29 |
| NFR-D §7 resource lifetimes | 5, 13, 16, 22, 27 |

### 8.5 Deferred, and not claimed

| Item | Status | Reason |
|---|---|---|
| §8.8 8, 9, 10 | deferred | translation is Phase 8 |
| `PopOutContentMode` picker | deferred | same (the wire field ships; the UI does not) |
| Size/position memory | not implemented | Q10 B; §8.9 "permitted, not required" |
| Web Document PiP | Phase 5 | §8.6 |
| Screen-reader announcement on open | not implemented | not required by §8 |
| Viewer pop-out | out of scope for S-21 | FD frontend-components §7 |

### 8.6 Strict-transcription statement, and the four recordable deviations

This plan is a strict transcription of the approved design plus Infrastructure Design. Every file,
step, test, constant and string cites the artifact that fixes it. **Zero open questions, zero TBD,
zero "to be decided".** §1.4's seven items are transcriptions of decisions already made (or of a
number a stage left to Code Generation to name: A-1, A-3); none is a design choice.

Four items are recorded rather than silently resolved, because each is the kind of thing the
`External Display` precedent logged in its own plan:

1. **`CaptionPosition` (B02).** FD BLM §1 lists it as "stays" (i.e. not a pop-out concept). It has no
   app-specific behaviour, and leaving a copy in `zip_broadcast` would create two `CaptionPosition`
   types while the codec in `zip_core` encodes its own. It moves; `zip_broadcast`'s
   `external_display_controls.dart` and `zb_app_shell.dart` read it from `package:zip_core/overlay.dart`.
   This is BR-U8.1-03's requirement, and is flagged for morning review as a documentation-level
   wording correction (FD BLM §1), not a design change. **No rule, state, wire shape or test changes.**
2. **`PopOutGeometry.toggleRowHeight = 44` (A-3).** A named constant, from NFR-R §6's 44x44 target.
3. **`PopOutWindowHost` (C35).** NFR-D logical-components §2 names the object but not its file path;
   the path here is `src/output/overlay/overlay_window_host.dart` with its provider beside it under
   `providers/`, matching the package's existing layout (`src/providers/`).
4. **`PopOutToggled` (M08).** FD BLM §3.3 says the controller "emits a `PopOutToggled` `OverlayEvent`
   that the shell listens for" but §1.1's event list does not enumerate it; adding the variant is the
   only way to satisfy §3.3, and it is additive to a sealed type the apps only switch on exhaustively
   in the shell (which gains the case in step 22).

**Schema/interface change check.** `OverlayEvent` (an existing sealed type) gains a variant: every
exhaustive switch over it must gain a case. Grep before step 22: `zb_app_shell.dart`'s
`_onOverlayEvent` is the only one; the pop-out's listener is new. Recorded so the change is
intentional and complete.

---

## 9. Handoff to Part 2

Part 2 executes steps 1-30 in order, ticking each box, writing the failing test before the
implementation within each step, and recording: the `git diff -M --summary` verdicts, the gate output,
the lockfile/registrant diffs, the Part 2 summary at
`aidlc-docs/construction/pop-out/code/unit8.1-summary.md` (with the BR-U8.1-10 table per app and the
NFR-R §5.1 refactor proof) and the stage handoff at
`aidlc-docs/construction/pop-out/code/handoff-summary.md`.

**If any step hits a moved test that fails for a reason outside the five shape changes: stop, do not
patch the test, report BLOCKED** (BR-U8.1-01).