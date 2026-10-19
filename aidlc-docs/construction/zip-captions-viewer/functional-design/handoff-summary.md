# Handoff: Functional Design -> NFR Requirements
**Unit**: zip-captions-viewer
**Date**: 2026-10-18 (artifacts written 2026-10-15; verified + approved 2026-10-18)

## Decisions Made
- Q1–Q10 answered 2026-10-15: additive `ConnectFailure` extension (+`RateLimited`, +`ResolutionFailed`, +`NotFound`); `resolutionFailed` renders as its own cannot-connect reason; notifier owns the reconnect give-up window (transport keeps its shipped retry loop, unchanged); "Try again" = full rejoin; `NotBroadcasting` keeps its status watch and auto-joins on a live event; `/join` in-shell + `/b/:broadcastId` out-of-shell; one app-lifetime `ViewerSessionNotifier`; leave requires a confirm dialog in active states; **web deferred to Phase 5** (native-only unit) with platform-neutrality + env-driven `BroadcastLink.baseUrl` guardrails; PiP pop-out deferred to Backlog.
- `LiveViewState` naming (avoids Unit 6's `LiveState` collision); notifier gains read-only `viewerCaptionTarget`/`sessionName`/`currentBroadcastId` getters (fixed state shape untouched).
- Viewer-scoped `CaptionBus`/registry/`OnScreenCaptionTarget` built with `repository: null` — remote captions never persisted.
- New `viewerTransportFactoryProvider` in zip_core (mirrors Unit 6's `broadcastTransportFactoryProvider`).
- Status-channel watch lifecycle: open from first confirmed existence; closed on leave/Ended/Full/CannotConnect; scoped event split (offline-while-Reconnecting = immediate NotBroadcasting; offline-while-Live = no-op).
- Status watch **first emission is the liveness source** at window expiry; three outcomes (offline → NotBroadcasting, live → IceFailed, no emission yet → ResolutionFailed), not two.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `ViewerSessionNotifier` | keepAlive notifier (zip_core) | 10 fixed states; single active session; `_ViewerResources` holder + `disposeAll` discipline |
| `ConnectFailure` | sealed (extended, 7 variants) | additive only; Rule 5's mapping table is exhaustive |
| `ReconnectPolicy` | service | window policy (single Timer per interruption); `nextDelay` null past `reconnectWindow` (120s interim) |
| `viewerTransportFactoryProvider` | provider | fake-seam for tests (NFR-7.3); default `const TransportSelector().viewerTransport()` |
| `JoinBroadcastScreen` / `BroadcastViewerScreen` | screens (zip_captions) | pure readers of notifier state; all copy via ARB; widget test per approved state |
| `broadcastBaseUrl` | const (fromEnvironment) | `BROADCAST_BASE_URL` dart-define; v1 apex default; no other domain literals in viewer path |

## Constraints
- No change to any shipped Unit 3/3.1/5 component behavior (transport retry loop, codecs, admission, resolver).
- No new dependencies (SECURITY-10); no `dart:io`/platform imports in the viewer path (Rule 12).
- No caption/transcript content in logs, state, or the `InvalidInputState` (Rules 2/8; NFR-3.3).
- The two S-19 web ACs (browser `/b/` route, SECURITY-04 headers) are deferred to Phase 5 — recorded in `aidlc-state.md`; NFR-4.1 (never crash) still applies to every native failure path.

## Open Questions for Next Stage
- NFR-1.3 timing targets (join-to-first-caption, reconnection) remain Spike 2.1 TBDs — document as carried-forward aspirational targets, not testable NFRs (same treatment as Unit 5).
- Accessibility: NFR-5.2's announcement mechanism is deferred to Code Generation as a Flutter-mechanism choice — NFR Requirements should fix the *testable* form (state-change announcement asserted in widget tests).
- Interim `BroadcastLimits` values (maxViewers=50 / presenceTimeout=60s / reconnectWindow=120s) — confirm they remain the only viewer-facing constants (no new ones).

## Verification-Pass Outcomes (2026-10-18) — carry into NFR Requirements
- Three in-place corrections made: `connect()` throw → `IceFailed`; F-7.4 window expiry with **no status emission** → `CannotConnect(ResolutionFailed)` (previously would have shown the reconnect-timeout copy); resource invariant #1 restated (holder non-null except `Idle`/`InvalidInput`). New Rule 14: no notifier-owned retry loop.
- PBT-09 reality check: **there is no `glados` dependency** — PBT-06's stateful suite must use the repo's in-tree `test/helpers/pbt.dart` shim (seeded `Random`, 100 trials, `Glados(gen).test(...)` accepting async bodies). NFR Requirements should record this as the framework decision, not re-select glados.
- `connect()` throws on a failed per-viewer channel open (the shipped transport awaits `channel.open()`), so NFR-4.1's never-crash requirement has a real, reachable test case — not just a theoretical one.
- Q9 guardrail 3 (`broadcastBaseUrl`) is unscheduled implementation work; NFR Requirements should decide whether it is a Code Generation step or its own small change.
