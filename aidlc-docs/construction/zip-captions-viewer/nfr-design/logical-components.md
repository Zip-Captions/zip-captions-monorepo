# Logical Components — Zip Captions Viewer (Unit 7)

## Component List (Design Q8)

| Component | Location | Notes |
|---|---|---|
| `ViewerSessionNotifier` | `zip_core`, `lib/src/services/broadcast/viewer_session_notifier.dart` (+ `.g.dart`) | `@Riverpod(keepAlive: true)`, extends `_$ViewerSessionNotifier`. Fixed shape `build()`/`join(String)`/`leave()`/`viewerBus`; three added read-only getters `viewerCaptionTarget`, `sessionName`, `currentBroadcastId`. `_setState` is the only state writer; `_sessionEpoch` suppresses stale resumes; `build()` registers `ref.onDispose(leave)`. |
| `ViewerSessionResources` | `zip_core`, `lib/src/services/broadcast/viewer_session_resources.dart` | New this unit (Design Q1). Package-internal, not exported. Holds the twelve fields listed in `nfr-design-patterns.md`; exposes `disposeAll(Logger log, {bool releaseTransport = true})`, the single teardown implementation. |
| `ViewerSessionState` (10 variants) | `zip_core`, `lib/src/models/viewer_session_state.dart` (+ `.freezed.dart`, `.g.dart`) | `IdleState`, `ResolvingState`, `ConnectingState`, `LiveViewState(CaptionActivity captionActivity, ConnectionType connectionType)`, `ReconnectingState`, `NotBroadcastingState`, `EndedState`, `FullState`, `CannotConnectState(ConnectFailure reason)`, `InvalidInputState`. Fixed shape from Application Design; `LiveViewState` named to avoid Unit 6's `LiveState`. |
| `ReconnectPolicy` | `zip_core`, `lib/src/models/reconnect_policy.dart` | Pure object: `Duration? nextDelay(int attempt, Duration elapsed)`. No clock, no timer, no I/O. |
| `ConnectFailure` (7 variants) | `zip_core`, `lib/src/models/connect_failure.dart` — additive edit | Three new `final class`es only (`RateLimited`, `ResolutionFailed`, `NotFound`); the shipped four are untouched. |
| `broadcastBaseUrl` | `zip_core`, `lib/src/constants/broadcast_link_config.dart` (new) | `String.fromEnvironment('BROADCAST_BASE_URL', ...)`, mirrors `supabase_config.dart`. |
| `BroadcastLink` | `zip_core`, `lib/src/models/broadcast_link.dart` — edit | `toUrl` interpolates `broadcastBaseUrl`; `baseUrl` removed; `parseInput` unchanged. |
| `viewerTransportFactoryProvider` | `zip_core`, `lib/src/providers/viewer_transport_factory_provider.dart` (+ `.g.dart`) | `@Riverpod(keepAlive: true) ViewerTransport Function()`, body `() => const TransportSelector().viewerTransport()`; mirrors `broadcast_transport_factory_provider.dart`. |
| `JoinBroadcastScreen` | `zip_captions`, `lib/src/screens/join_broadcast_screen.dart` | Pure form; `BroadcastLink.parseInput` locally before navigating to `/b/{id}`; invalid -> inline error, no navigation, no `join()` call. |
| `BroadcastViewerScreen` | `zip_captions`, `lib/src/screens/broadcast_viewer_screen.dart` | Outside the shell. Route-reentry `join()` in a post-frame callback; body switches on `ViewerSessionState`; Leave control and `BackButtonListener` with the Rule 9 confirm dialog in the four active states; reads `displaySettingsProvider` (Rule 10) and `notifier.viewerCaptionTarget`. |
| `ViewerStatusRegion` (+ notice widgets) | `zip_captions`, `lib/src/widgets/viewer_status_region.dart` | New this unit (Design Q5). Renders the current status text in a `Semantics` container and calls `viewerAnnouncerProvider` only when the text changes (`_lastAnnounced`). Owns the paused/inactive and reconnect notices. |
| `ViewerAnnouncer` + `viewerAnnouncerProvider` | `zip_captions`, `lib/src/providers/viewer_announcer_provider.dart` (+ `.g.dart`) | `typedef ViewerAnnouncer = void Function(String)`; default `SemanticsService.announce(message, TextDirection.ltr)`. Overridden in widget tests. |
| `ZcStrings` | `zip_captions`, `lib/src/l10n/zc_strings.dart` | New this unit (Design Q6). Only reader of `l10n/arb/app_en.arb`; one getter per viewer key; no `intl`, no `gen-l10n`. |
| `zc_router.dart` | `zip_captions` — edit | `/join` inside the existing `ShellRoute`; `/b/:broadcastId` top-level outside it. Plain paths only. |
| `ZcNavDrawer` / `HomeScreen` | `zip_captions` — edit | "Join a broadcast" drawer item and home-screen affordance. `ZcAppShell._screenTitle` maps `/join` -> "Join". |
| `app_en.arb` | `zip_captions/l10n/arb/app_en.arb` — edit | Every viewer string (state titles, copies, notices, dialog, buttons, field label/error). |

## Dependency Diagram

```
JoinBroadcastScreen ──> BroadcastLink.parseInput (zip_core, shipped; unchanged)
        │
        └─ go('/b/{id}')
                 │
                 ▼
BroadcastViewerScreen ──> ViewerSessionNotifier (state + 3 getters)
        │                       │
        ├─ displaySettingsProvider (zip_captions, existing; Rule 10)
        ├─ ViewerStatusRegion ──> viewerAnnouncerProvider (this unit)
        ├─ CaptionDisplayWidget ──> viewerCaptionTarget.visibleCaptions /
        │                           onVisibleCaptionsChanged (real target)
        └─ ZcStrings ──> l10n/arb/app_en.arb (this unit's only reader)

ViewerSessionNotifier ──┬──> broadcastResolverProvider        (Unit 5, unchanged)
   (+ ViewerSessionResources) ├──> signalingServiceProvider   (Units 3/3.1, unchanged;
                        │    │                                 statusChannel().watch())
                        │    ├──> iceServerProviderProvider    (Unit 4, unchanged)
                        │    ├──> viewerTransportFactoryProvider (this unit)
                        │    ├──> CaptionBus / CaptionOutputTargetRegistry /
                        │    │    OnScreenCaptionTarget(repository: null) (Phase 1, new
                        │    │    instances per session)
                        │    ├──> RemoteCaptionReceiver        (Unit 5, unchanged, real)
                        │    └──> ReconnectPolicy + Timer(defaultBroadcastLimits.reconnectWindow)
                        │
                        ▼
                 ViewerSessionState (10 variants)

viewerTransportFactoryProvider ──> TransportSelector.viewerTransport() (Unit 5, unchanged)

BroadcastLink.toUrl ──> broadcastBaseUrl (new constants file)
    consumed by BroadcastSessionNotifier / zip_broadcast (unchanged behaviour)
```

Dependency direction is one-way throughout. This unit adds no dependency to either
package and modifies no shipped component's behaviour: the only edits to existing files
are `connect_failure.dart` (three additive variants), `broadcast_link.dart` (constant
interpolation, `baseUrl` removed with default unchanged), the `zip_captions` router,
drawer, home screen and ARB, and additive barrel lines in `zip_core`. Nothing in Units
2/3/3.1/4/5 depends back on the viewer.

## Resource Lifecycle Summary (Design Q1/Q4)

| State | `_resources` | Transport | Status watch | Window timer | Bus/registry/target |
|---|---|---|---|---|---|
| `IdleState` | null | none | none | none | none |
| `ResolvingState` | null — F-7.2 sets `Resolving` before step 4 creates the holder | none | none | none | none |
| `ConnectingState` | non-null | connected in flight | open | none | alive |
| `LiveViewState` | non-null | live | open | none | alive |
| `ReconnectingState` | non-null | reconnecting | open | **active** | alive |
| `NotBroadcastingState` | non-null | none (never connected) | open (auto-join) | none | alive |
| `EndedState` / `FullState` / `CannotConnectState` | non-null | released | closed | none | alive until `leave()` |
| `InvalidInputState` | null | none | none | none | none |

Note on `ResolvingState`: NFR Requirements' invariant is stated as "holder non-null
except `IdleState`/`InvalidInputState`". Verified against FD F-7.2, resolution happens
*before* step 4 creates the holder, and a resolution failure must not have created one.
The implemented reading (recorded here, not a contradiction: NFR Requirements Q3's
wording is the terminal-state concern) is "holder non-null in every state **that has
passed F-7.2 step 4**", i.e. `Connecting`, `LiveView`, `Reconnecting`, `NotBroadcasting`
and the three terminal states; `Resolving` is a pre-resource state and the invariant
assertion exempts it. Code Generation must encode this exemption explicitly in the
stateful suite's invariant check.

## Cancellation Ownership

| Cancellable | Owner | Cancelled by |
|---|---|---|
| window `Timer` | `ViewerSessionResources.windowTimer` | `_setState` when leaving `Reconnecting`; `_enterReconnecting` before restarting; `disposeAll`; `ref.onDispose(leave)` |
| `statusWatch` | resource holder | `disposeAll` (terminal transitions and `leave()`) |
| `statusSub` (`transport.status`) | resource holder | `disposeAll` |
| `activitySub` / `endedSub` (`receiver`) | resource holder | `disposeAll` (before `receiver.dispose()`) |
| target debounce timer | `OnScreenCaptionTarget` (internal) | `registry.remove(target)` -> `target.dispose()` |
| Realtime presence topic | `StatusChannel` | `await statusChannel.close()` inside `disposeAll` |