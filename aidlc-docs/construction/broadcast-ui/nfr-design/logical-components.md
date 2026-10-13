# Logical Components — Zip Broadcast Broadcast UI (Unit 6)

## Component List (Q3)

| Component | Location | Notes |
|---|---|---|
| `BroadcastSessionNotifier` | `zip_core`, `lib/src/services/broadcast/` | Fixed shape (`build()`/`goLive()`/`endBroadcast()`). Owns at most one `_SessionResources?` at a time (Q1). |
| `_SessionResources` (private) | same file as `BroadcastSessionNotifier` | New this unit (Q1) — holds `StatusChannel`, `ViewerAdmission`, `BroadcastTransport`, `RemoteBroadcastTarget`, and the two owned stream subscriptions; exposes `disposeAll(Logger log)`, the single shared teardown path for both Rule 2's unwind and Rule 5's teardown. |
| `BroadcastSettingsNotifier` | `zip_core`, `lib/src/services/broadcast/` | New this unit. Loads/persists `BroadcastSettings` via `sharedPreferencesProvider` (Phase 1 pattern). |
| `CaptioningStarter` (interface) + default impl | `zip_core`, alongside `RecordingStateNotifier` | New seam (Functional Design Q1). `zip_broadcast`'s `main.dart` overrides `captioningStarterProvider` with a `BroadcastRecordingNotifier`-backed implementation. |
| `BroadcastSettings` | `zip_core`, `lib/src/models/` | Fixed fields + `validateSessionName` (Rule 7). |
| `BroadcasterSessionState` (5 variants) | `zip_core`, `lib/src/models/` | Renamed from Application Design's `BroadcastSessionState` (Functional Design Q2, approved deviation). |
| `LiveBroadcast` (8 fields) | `zip_core`, `lib/src/models/` | `startedAt` added (Functional Design Q3, approved deviation). |
| `BroadcastFailure` | `zip_core`, `lib/src/models/` | Unchanged, fixed at Application Design. |
| `RemoteBroadcastTarget.primeActivity()` | `zip_core` — Unit 5's existing file, additive method | Functional Design Q4. No new file. |
| `BroadcastTransport.sendBroadcastEnded()` | `zip_core` — Unit 5's existing `BroadcastTransport` interface + `WebRtcBroadcastTransport` impl, additive method | Functional Design Q5. No new file. |
| `BroadcastSetupScreen` | `zip_broadcast`, `lib/src/screens/` | New this unit. Reads `broadcastSettingsNotifierProvider`, `broadcastSessionNotifierProvider`, `authNotifierProvider`, `outputTargetSettingsNotifierProvider`. |
| Live dashboard screen | `zip_broadcast`, `lib/src/screens/` | New this unit (naming decided at Code Generation — one route per Functional Design Q8, content switches on `BroadcasterSessionState`). |
| `ZbAppShell`'s `InheritedWidget` + `requestSignOut()` | `zip_broadcast` — `ZbAppShell`'s existing file | New this unit (Functional Design Q6). Sole call path to `authNotifierProvider.notifier.signOut()`. No-await-between rule applies (Q2). |
| `AccountSection` sign-out button | `zip_broadcast`, `SettingsScreen`'s existing file | Call site switched from the direct `signOut()` call (Unit 2, unguarded) to `scope.requestSignOut()`. |

## Dependency Diagram

```
BroadcastSetupScreen / Live dashboard screen
        │
        ▼
BroadcastSessionNotifier ──┬──> authNotifierProvider (Unit 2, unchanged)
   (+ _SessionResources)   ├──> broadcastIdentityRepositoryProvider (Unit 3, unchanged)
        │                  ├──> signalingServiceProvider (Units 3/3.1, unchanged)
        │                  ├──> iceServerProviderProvider (Unit 4, unchanged)
        │                  ├──> TransportSelector / BroadcastTransport (Unit 5, unchanged
        │                  │     except the two additive methods)
        │                  ├──> captioningStarterProvider (this unit, new seam)
        │                  └──> ViewerAdmission(defaultBroadcastLimits) (Unit 5, unchanged)
        │
        ▼
RemoteBroadcastTarget (Unit 5, + primeActivity() this unit)

BroadcastSettingsNotifier ──> sharedPreferencesProvider (Phase 1, unchanged)

ZbAppShell.requestSignOut() ──> authNotifierProvider.notifier.signOut() (Unit 2, unchanged)
   (sole call path within zip_broadcast)

AccountSection ──> ZbAppShell's InheritedWidget.requestSignOut() (no longer calls
                   signOut() directly)
```

Dependency direction is one-way throughout: this unit depends on Units 2/3/3.1/4/5's
already-built interfaces (`AuthNotifier`, `BroadcastIdentityRepository`,
`SignalingService`, `IceServerProvider`, `BroadcastTransport`,
`RemoteBroadcastTarget`). No file in any of those units is modified by this unit
except the two additive, non-breaking methods on Unit 5's `RemoteBroadcastTarget` and
`BroadcastTransport`/`WebRtcBroadcastTransport` (Functional Design Q4/Q5) — neither
changes an existing method's signature or behavior.

## Resource Lifecycle Summary (Q1)

| State | `_SessionResources?` |
|---|---|
| `OfflineState` | `null` |
| `StartingState` | `null` until F2-5 creates the transport; set once all of F2-5–F2-9 succeed |
| `LiveState` | non-null (the single source backing `transport.viewers`/`target.activityChanges` subscriptions) |
| `EndingState` | non-null until `disposeAll()` completes, then `null` immediately before the `OfflineState` transition |
| `BroadcastFailedState` | `null` (guaranteed by `disposeAll()` having run during the unwind) |
