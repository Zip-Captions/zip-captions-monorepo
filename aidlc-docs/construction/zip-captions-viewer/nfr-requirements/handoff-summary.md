# Handoff: NFR Requirements -> NFR Design
**Unit**: zip-captions-viewer
**Date**: 2026-10-18 (unattended run; answers pre-approved per `.agent/overnight-pipeline.md` A2, subject to morning review)

## Decisions Made
- Q1=A testability: `ViewerSessionNotifier` tested entirely against hand-written fakes added to the existing `test/helpers/fake_broadcast_session_collaborators.dart` (`FakeBroadcastResolver`, `FakeViewerTransport`, status-channel signaling adapter); `RemoteCaptionReceiver` and the viewer bus/registry/target stay real.
- Q2=A widget tests: `FakeViewerSessionNotifier extends ViewerSessionNotifier` + `viewerSessionProvider.overrideWith`, mounted in a real `MaterialApp.router`; one test per Proto-14/15 state; invalid join asserts no navigation and no `join()` call; no goldens, no new test dep in `zip_captions`.
- Q3=A reliability: one `_ViewerResources.disposeAll(log)` (catch-and-continue, never throws, terminal transition last) shared by `leave()`, every terminal transition, and F-7.4 window expiry; holder non-null except `Idle`/`InvalidInput` is a directly asserted invariant.
- Q4=A windows: no clock seam — one `Timer(reconnectWindow)` driven by `fakeAsync`/`pump(Duration)`; `ReconnectPolicy` is a pure function with its own small suite (example + one invariant row).
- Q5=A logging: state/reason/ID/`runtimeType` only; never caption text, raw join input (even on failure), payloads, credentials, or exception messages.
- Q6=A no new dependency; Q7=A PBT-09 decision is the in-tree shim `test/helpers/pbt.dart` (100 fixed seeds, no shrinking — counterexamples hand-reduced and pinned), not `glados`.
- Q8=A accessibility: every status-text change announces through a single injectable `void Function(String)` provider (default `SemanticsService.announce`); status text findable via `find.bySemanticsLabel` under `ensureSemantics()`; all viewer copy in `l10n/arb/app_en.arb` via one `ZcStrings`-style class, no literals in widgets.
- Q9=A `broadcastBaseUrl` moves to `zip_core/lib/src/constants/broadcast_link_config.dart` (`String.fromEnvironment('BROADCAST_BASE_URL', defaultValue: 'https://zipcaptions.app/b/')`), `toUrl` interpolates it, `BroadcastLink.baseUrl` is removed, default behaviour unchanged.

## Key Entities / Components
| Name | Type | Constraint for NFR Design |
|---|---|---|
| `_ViewerResources.disposeAll(Logger)` | private method | The only writer that nulls the holder; async, per-step try/catch, mixed sync/async steps, never throws |
| `viewerTransportFactoryProvider` | provider | Fake seam; NFR Design confirms placement beside `broadcastTransportFactoryProvider` |
| Announcement seam | provider (`void Function(String)`) | Provided at app/route level, overridable in widget tests, not constructed inside the screen |
| `ReconnectPolicy` | pure object | No clock, no timer; window arithmetic only (one `Timer` lives in the notifier) |
| `ConnectFailure` | sealed (additive) | Three new variants only; four shipped variants untouched |
| `broadcastBaseUrl` | const | New constants file; `baseUrl` removed; `parseInput` unchanged |

## Constraints
- Security Baseline: 6 Compliant, 9 N/A (SECURITY-04 N/A this unit — web deferred to Phase 5), 0 non-compliant.
- PBT: 8 Compliant/planned, 2 N/A (PBT-05 no oracle; framework limit on shrinking recorded under PBT-08); Rule 5's seven-row mapping and the eight UI states stay example-based.
- No new dependency; no `dart:io`/platform import in the viewer path; no changes to `docs/`, `web/`, CI, or the Podfile.lock.
- No caption/transcript content in logs, state, or `InvalidInputState`; `OnScreenCaptionTarget(repository: null)` is by design.

## Open Questions for Next Stage
- Announcement seam placement and its exact provider kind (Notifier vs plain Provider) — Code Generation detail fixed at NFR Design if the component list names it.
- Q8 mechanism: `flutter gen-l10n` SDK wiring vs a plain ARB-backed lookup class — NFR Design should pick one, with the repository's existing "no l10n.yaml yet" state in mind.
- New Backlog item to add at approval: project-wide localization of `zip_captions`'s pre-existing hardcoded screens.