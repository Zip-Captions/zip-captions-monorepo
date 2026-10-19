# Handoff: NFR Design -> Code Generation
**Unit**: zip-captions-viewer
**Date**: 2026-10-18 (unattended run; answers pre-approved per `.agent/overnight-pipeline.md` A2, subject to morning review)

## Decisions Made
- Design Q1: `ViewerSessionResources` (package-internal) holds 12 fields; `disposeAll(log, {releaseTransport = true})` runs F-7.7's order, per-step `on Object` + `${e.runtimeType}`; the **notifier** is the only writer of `_resources`.
- Design Q2: `windowTimer` lives in the holder; `_setState` cancels it whenever the next state is not `Reconnecting` (structural, not per-call-site).
- Design Q3: `int _sessionEpoch` incremented by every `join()` start, implicit leave and `leave()`; checked after each await; stale resumes return without state/resources changes.
- Design Q4: terminal transitions call `disposeAll(log, releaseTransport: true)` then `_setState` last; `leave()` calls `disposeAll(log)` for the rest. Released == null field, so a second call is a no-op.
- Design Q5: `typedef ViewerAnnouncer = void Function(String)`; `@Riverpod(keepAlive: true) viewerAnnouncerProvider`, default `SemanticsService.announce(msg, TextDirection.ltr)`; one `ViewerStatusRegion` widget announces only when the status text changes (`String? _lastAnnounced`).
- Design Q6: `ZcStrings` (`zip_captions/lib/src/l10n/zc_strings.dart`) is the only ARB reader; no `gen-l10n`, no `flutter_localizations`, no `intl`.
- Design Q7: fakes appended to `fake_broadcast_session_collaborators.dart`; stateful PBT wraps each Glados trial in `fakeAsync`.
- Design Q8: `ViewerSessionNotifier.build()` registers `ref.onDispose(leave)` — the one deliberate divergence from `BroadcastSessionNotifier`.

## Key Entities / Components
| Name | Type | Constraint for Next Stage |
|---|---|---|
| `ViewerSessionResources` | plain class, 12 fields | Not in the barrel. Only `disposeAll` touches resources; `_resources` nulled only by the notifier. |
| `ViewerSessionNotifier` | keepAlive notifier | `_setState` sole state writer; `_sessionEpoch`; `ref.onDispose(leave)`; 3 added getters. |
| `FakeViewerTransport` | test fake | Records `connect`/`restart`/`disconnect`; `restartCalls` must stay 0 (Rule 3/14). |
| `FakeBroadcastResolver` | test fake | Scripted result queue + default; `resolveCalls`. |
| `ViewerAnnouncer` provider | `void Function(String)` | Overridden in widget tests; default uses `TextDirection.ltr`. |
| `ZcStrings` | lookup class | One getter per ARB viewer key; screen renders ARB value, test uses a sentinel. |

## Constraints
- Holder invariant: non-null in `Connecting`/`LiveView`/`Reconnecting`/`NotBroadcasting`/terminal states; **null in `Idle`, `InvalidInput`, and `Resolving`** (F-7.2 step 4 creates it; encode this exemption in the stateful invariant check).
- Keep `ResolvingState` before allocation; a resolution failure must never have created resources.
- No new dependency; no `dart:io`/platform imports in the viewer path; web untouched; `docs/` untouched; Podfile.lock never staged.
- PBT-09 = in-tree `test/helpers/pbt.dart` shim (100 seeds, no shrinking); counterexamples hand-reduced and pinned.
- Rule 5's table, the eight widget states, and the three expiry outcomes stay example-based (PBT-10).

## Open Questions for Next Stage
- Exact widget count/naming for `BroadcastViewerScreen`'s state tests (one per state plus the two copy variants) — Code Generation Part 1 fixes the list.
- Whether `ZcStrings` is exposed via `InheritedWidget` or a provider — either satisfies NFR Q8; pick in Part 1 and keep the sentinel test.
- `ViewerSessionState` codegen mode (`freezed` vs hand-written sealed) — follow `broadcaster_session_state.dart`'s existing pattern when generating.