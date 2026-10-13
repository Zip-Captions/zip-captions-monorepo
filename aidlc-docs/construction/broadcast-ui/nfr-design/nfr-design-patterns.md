# NFR Design Patterns — Zip Broadcast Broadcast UI (Unit 6)

## Resilience

**Shared disposal pattern for the per-session resource bundle (Q1)**: `goLive()`'s
unwind (Rule 2) and `endBroadcast()`'s teardown (Rule 5) both dispose the same five
owned resources, each step individually caught and logged (NFR Requirements Q3).
Rather than writing that catch-and-continue logic twice, `BroadcastSessionNotifier`
introduces a private `_SessionResources` holder — a plain Dart class grouping the
`StatusChannel`, `ViewerAdmission`, the `BroadcastTransport` instance, the
`RemoteBroadcastTarget` instance, and the two owned stream subscriptions
(`activityChanges`, `transport.viewers`) — with a single
`Future<void> disposeAll(Logger log)` method:

1. Close the `StatusChannel` (if open).
2. `registry.remove(target)` (disposes the `RemoteBroadcastTarget`, closing
   `activityChanges`).
3. `transport.stop()`.
4. Cancel both owned subscriptions (defensive — steps 2 and 3 already close the
   streams they subscribe to).

Each step is wrapped individually: a thrown exception is caught, logged (`broadcastId`,
`sessionId`, the exception type and message — never caption content, never an
unvetted `toString()`, per `nfr-requirements.md` Q4), and execution continues to the
next step regardless. `disposeAll()` itself never throws. `goLive()`'s failure unwind
and `endBroadcast()` both call this **one** method; the only difference between the
two call sites is which terminal state they set immediately afterward
(`BroadcastFailedState(reason)` vs `OfflineState`).

The notifier holds at most one `_SessionResources?` field at a time — set (non-null)
the instant `goLive()`'s F2-9 step constructs the initial `LiveBroadcast` and
transitions to `LiveState`, and nulled out immediately after `disposeAll()` runs on
either path. This makes "no session resources exist" (the precondition Rules 1 and 5
both rely on for `BroadcastFailedState`/`OfflineState` being legal retry/sign-out
points) a directly checkable invariant rather than an informal claim: every non-idle
state (`StartingState`/`LiveState`/`EndingState`) has a non-null
`_SessionResources`, every idle state (`OfflineState`/`BroadcastFailedState`) has
`null`.

## Scalability / Performance (restated from NFR Requirements, no new pattern)

Nothing new to design — NFR Requirements already fixed this unit's scalability and
performance posture as N/A. `LiveBroadcast.viewers`/`maxViewers` are consumed as-is
from Unit 5's `BroadcastTransport`/`defaultBroadcastLimits`; NFR-1.3's targets remain
Unit 5/9's responsibility.

## Security

**No-await-between rule for `requestSignOut()` (Q2)**: `ZbAppShell`'s
`requestSignOut()` reads `broadcastSessionNotifierProvider`'s current state and then
either calls `authNotifierProvider.notifier.signOut()` or refuses with the "End the
live broadcast before signing out" feedback — the identical check-then-act shape Rule
1 already protects for `goLive()` ("state → `StartingState`, synchronously, before the
first await"). This stage makes the same discipline an explicit, documented
implementation rule for `requestSignOut()`, carried into Code Generation:

> The `ref.read(broadcastSessionNotifierProvider)` state check and the subsequent
> `signOut()` call (or the refusal branch) MUST execute in the same synchronous span —
> no `await` of any kind between the read and the act. Dart's single-threaded event
> loop already makes two back-to-back synchronous statements atomic with respect to
> any other code (no `goLive()` call can be interleaved between them regardless), so
> this introduces no new mechanism — but stating it explicitly guards against a future
> edit (e.g. inserting a confirmation dialog's `await` before the state check) silently
> reopening the mid-`goLive()` sign-out race that Rule 9 exists to close.

This is a documentation-only addition — no seam, no new type — and applies to
`requestSignOut()` specifically; it does not change anything about `goLive()`'s own
already-fixed synchronous-state-transition discipline.

No other security pattern is new at this stage — Rule 9's guard mechanism
(`InheritedWidget`, sole call path) and Rule 10's logging restriction were already
fully specified at Functional Design and NFR Requirements; this stage adds only the
one correctness detail above.
