# Handoff: NFR Requirements -> NFR Design
**Unit**: external-display
**Date**: 2026-10-20 (unattended run; answers pre-approved per `.agent/overnight-pipeline.md` A2, subject to morning review)

## Decisions Made
- Q1=A testability: `OverlayWindowController` tested against fakes only — `MockDesktopWindowService` extended in place with `setFrame`/`show` (B-6), a new hand-written `FakeDisplayEnumerator` (scriptable `displays()` + pushable broadcast `changes`), the settings notifier by provider override; the state machine/open guard/handshake run real. No plugin, no runner, no device.
- Q2=A widget tests: one test per `ExternalDisplayStatus` (7, `Unsupported` renders nothing) plus the BR-U8-07 tap/Cancel writes; `OverlayWindowApp` gets standby/live/paused, "Window unavailable", position top/bottom, and the BR-U8-20 theme-wiring test. `zb_test_harness.dart` + `ProviderScope`; no goldens.
- Q3=A reliability: one shared private `_release(log)` on the controller (per-step catch-and-continue, fixed string + `runtimeType`, never throws; terminal transition last); the display-lost path releases then enters `WaitingForDisplay` with `overlayEnabled` still true (D-4); sub-engine decode failure is total (fixed frame, no `overlayReady`, no throw out of the method handler, BR-U8-19).
- Q4=A ready handshake: `overlayReadyTimeout = 10 s` named const (BR-U8-23's "~10 s"); expiry → `OpenFailed(ready_timeout)`, idempotent close, `overlayEnabled` back to false; late ready is a no-op; tested with `fakeAsync`, no clock seam.
- Q5=A performance: enumeration = ≤1 `getAllDisplays()` per platform event, 0 polls; open bounded by the 10 s constant, `createWindow`→`setFrame`→`show`, no snapshot before ready; cadence = ≤1 `captionUpdate` per animation frame (60/s), payloads under `maxEncodedBytes` = 16 KiB; state machine synchronous per event. Placement/borderless/hot-plug/OS-close/plugin-registration are Unit 9 manual checks, recorded, not claimed.
- Q6=A security: fixed string + error type at every new call site; never caption text/snapshot/raw launch argument (BR-U8-18); `OpenFailed.reason` is a fixed code; a redaction test (capturing `Logger.onRecord`) audits decode-failure, open-failure and release paths.
- Q7=A dependencies: exactly `screen_retriever: ^0.2.2` (+ its four federated lockfile entries) per the FD SECURITY-10 record; `desktop_multi_window` already shipped; `window_manager` dropped (D-13); any other need is BLOCKED.
- Q8=A PBT: framework = the in-tree shim `test/helpers/pbt.dart` (100 fixed seeds, no shrinking; counterexamples hand-reduced and pinned). FP-1..FP-5 all checked expressible; FP-5 is a `fakeAsync`-wrapped stateful suite in the `zip_core` state-machine property shape; FP-4 needs the BR-U8-07 resolution as a pure function.
- Q9=A accessibility: NFR-5.1 carried as two tests — the BR-U8-20 theme-wiring test (dark→light surface colour change; the AAA ratio stays owned by `zip_core/test/pbt/theme_contrast_test.dart`, not repeated) and an opaque-surface test (`OverlayConfig.opacity` 0.9 not applied, alpha 255, BR-U8-26). Statuses distinguishable by text/icon, never colour alone; all copy in `app_en.arb`.

## Key Entities / Components
| Name | Type | Constraint for NFR Design |
|---|---|---|
| `_release(Logger)` (Q3) | private controller method | The only writer of the released state; per-step try/catch; terminal transition last; shared by close, T6/T8 failure, and the T10 display-lost path |
| `overlayReadyTimeout` | named const Duration (10 s) | One timer, `fakeAsync`-driven; placed by NFR Design |
| `maxEncodedBytes` | named const int (16 KiB) | Mirrors `CaptionWireCodec`; full encoded payload incl. nested fields/multibyte |
| BR-U8-07 resolution (FP-4) | pure function (list + persisted id → target + keep) | Must be extracted pure before FP-4; NFR Design names it |
| `MockDesktopWindowService` + `FakeDisplayEnumerator` | test helpers | Extended/new in `test/helpers/`; land with the B-6 interface edit (one step) |
| `toPlatformFrame` | pure function (io adapter) | The only non-logical coordinate space; platform inputs as arguments; FP-3's subject |

## Constraints
- Security Baseline: 7 Compliant (03, 05, 08, 09, 10, 11, 15), 8 N/A (01, 02, 04, 06, 07, 12, 13, 14 — 04 with web deferred to Phase 5), 0 non-compliant.
- PBT: 10 Compliant/planned (01-10; PBT-08 with the recorded no-shrinking limit; PBT-04 rides in FP-5), 0 N/A.
- One new dependency only; single-file `screen_retriever` import fence; no `kIsWeb` (BR-U8-11); no Supabase surface; `zip_core` untouched.
- No caption text in logs/events/errors/widget keys/semantics/test messages (BR-U8-18) — implementation directive for every new call site; `sessionId`/`sourceId` never cross the window boundary (BR-U8-24).

## Open Questions for Next Stage
- Exact placement/naming of `overlayReadyTimeout`, `maxEncodedBytes`, and the pure BR-U8-07 resolution function (constants + function name are NFR Design's to fix; values are settled above).
- The FP-5 event-sequence generator's command set and the `fakeAsync` wrapping shape — follow the `zip_core` `viewer_session_state_machine_properties_test.dart` precedent.
- B-4's sub-engine plugin registration list (`google_fonts`/`path_provider` expected; confirm on macOS in Unit 9) carries forward to NFR Design/Infrastructure Design, not settled here.
