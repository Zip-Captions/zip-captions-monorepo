# Phase 2 Services — Broadcasting & Transport

The service layer, orchestration patterns and main flows. Following the Phase 1 pattern, services are plain Dart classes held by Riverpod providers, and notifiers orchestrate them through **explicit calls** (project Riverpod side-effect convention). There are no reactive watchers that trigger side effects.

---

## Service Layers

| Layer | Services | Held by |
|---|---|---|
| Platform / SDK seams | `SupabaseClient` (app-injected), `PeerConnectionFactory` (flutter_webrtc), `DisplayEnumerator` (screen_retriever) | Providers, overridable in tests |
| Backend access | `AuthService`, `BroadcastIdentityRepository`, `BroadcastResolver`, `SignalingService`, `TurnCredentialService` | keepAlive providers |
| Transport | `TransportSelector`, `WebRtcBroadcastTransport`, `WebRtcViewerTransport`, `IceServerProvider`, `ViewerAdmission` | Created per session by the orchestrating notifier |
| Caption pipeline | Broadcaster: app-wide `CaptionBus` + registry (Phase 1) plus `RemoteBroadcastTarget`. Viewer: per-session `CaptionBus` + registry + `OnScreenCaptionTarget` + `RemoteCaptionReceiver` | Registry (broadcaster); `ViewerSessionNotifier` (viewer) |
| Orchestration | `AuthNotifier`, `BroadcastSessionNotifier`, `ViewerSessionNotifier`, `BroadcastSettingsNotifier` | Riverpod notifiers |

---

## Orchestration Flows

### F1. Sign in (S-15)
1. The UI calls `AuthNotifier.signIn(providerId)`.
2. `AuthService` runs the approved OAuth flow (SR-01). The state becomes `signingIn`, then `signedIn(userId)` or `failed(reason)`.
3. On success, the UI returns to broadcast setup if sign-in was prompted by go-live (FR-1.5).

### F2. Go live (S-17, plan Q3)
1. The UI calls `BroadcastSessionNotifier.goLive()`. If signed out, the state becomes `failed(signedOut)` and the UI shows the sign-in prompt.
2. `BroadcastIdentityRepository.getOrCreateMine()` returns the `BroadcastId`.
3. A new `sessionId` is generated, and `IceServerProvider.iceServersFor(sessionId)` is called (TURN credentials via `TurnCredentialService`).
4. `SignalingService.sessionChannel(sessionId, broadcaster).open()`.
5. `TransportSelector.broadcastTransport().start(context with ViewerAdmission)`.
6. `RemoteBroadcastTarget` is created with its initial activity from the current recording state, then **registered** on the app `CaptionOutputTargetRegistry`.
7. `StatusChannel.publishLive(sessionId, sessionName)`.
8. **Only if `autoStartCaptioning` is on and recording is idle:** explicit call to start the recording notifier.
9. The state becomes `live(LiveBroadcast)`. If `captionActivity != active`, the dashboard shows the **captions-inactive banner**.

On failure at any step, completed steps are unwound in reverse order, the state becomes `failed(reason)`, and local captioning is unaffected.

### F3. Captioning changes while live (plan Q3)
1. `RecordingStateNotifier` publishes `SessionStateEvent`s on the app bus as it does in Phase 1. Nothing changes there.
2. `RemoteBroadcastTarget.onCaptionEvent` maps each event to a `CaptionActivity`, calls `sendToAll(captionActivityChanged)` and emits on `activityChanges`.
3. `BroadcastSessionNotifier` listens to `activityChanges` (a stream subscription it owns, not a provider watcher) and updates `LiveBroadcast.captionActivity`, which shows or hides the banner.
4. Viewers show "captions paused by the broadcaster" while the activity is `paused` or `inactive`.
5. Stopping captioning **never** ends the broadcast.

### F4. Viewer join (S-19, S-18)
1. The UI (join screen or `/b/:broadcastId`) calls `ViewerSessionNotifier.join(input)`.
2. `BroadcastLink.parseInput`: invalid input gives `invalidInput`, with no network call.
3. `BroadcastResolver.resolve`: `notFound` or `offline` gives `notBroadcasting`, and `rateLimited` gives `cannotConnect(rateLimited)`.
4. The viewer-scoped `CaptionBus`, registry and `OnScreenCaptionTarget` are created.
5. `ViewerTransport.connect(sessionChannel, iceServers)` sends a `joinRequest` with a null `viewerIdentity`.
6. The broadcaster side runs `ViewerAdmission.tryAdmit(peerId)`. `Full` means a `joinRejected(full)` reply and the viewer state `full`. `Admitted` means `joinAccepted`, then SDP and ICE, then the data channel opens.
7. On `viewerJoined`, `RemoteBroadcastTarget` sends that viewer the current `captionActivity` snapshot. There is no caption backlog (FR-5.4).
8. `RemoteCaptionReceiver` publishes captions into the viewer bus, and the state becomes `live(activity, connectionType)`.

### F5. Viewer reconnection (FR-7.5)
1. `ViewerTransport.status` emits `interrupted`, and the state becomes `reconnecting`.
2. `ReconnectPolicy` schedules `restart()` (ICE restart or re-signal). The viewer bus and targets are kept.
3. On success, the state returns to `live`. When the window is exceeded, `StatusChannel` is checked: offline gives `notBroadcasting`, otherwise `cannotConnect(reason)`.
4. The broadcaster side releases the admission slot on `viewerLeft`. A reconnecting viewer is re-admitted like any join.

### F6. End broadcast (FR-6.5)
1. `BroadcastSessionNotifier.endBroadcast()` (idempotent) runs `sendToAll(ended)`, then a `broadcastEnded` signaling message.
2. The transport stops (all peers closed, native resources released), and `RemoteBroadcastTarget` is unregistered and disposed.
3. `StatusChannel.publishOffline()`, the channels close, and the state becomes `offline`. Local captioning continues.
4. Viewers receive `ended`, their state becomes `ended`, and their viewer-scoped bus is disposed on leave.

### F7. Broadcaster disappears (FR-6.6)
1. Presence expires after `BroadcastLimits.presenceTimeout`, so `StatusChannel.watch()` emits offline.
2. Viewers already in `reconnecting` go to `notBroadcasting` when the window closes.

### F8. External display (S-20)
1. Output target settings toggle the overlay on, with a selected `DisplayInfo.id`.
2. The shell calls `CaptionOverlayTarget.show(OverlayConfig(targetDisplayId))`, which runs `desktop_multi_window` to create the sub-window, and `main.dart` routes it to `OverlayWindowApp`.
3. Captions reach the sub-window through the existing `invokeMethod('captionUpdate', ...)`.
4. When `DisplayEnumerator.changes` no longer includes the selected display, the target hides the window and emits `DisplayLost`, and the UI notifies the broadcaster (FR-9.4).
5. This flow is independent of sign-in and of the broadcast.

---

## Cross-Cutting Patterns

- **Error isolation.** One viewer's failure never affects the others or the broadcaster's local pipeline. The registry's existing per-target error isolation also covers `RemoteBroadcastTarget`.
- **Idempotency.** `endBroadcast`, `leave`, duplicate `joinRequest`, `leave` and ICE messages are safe to repeat (PBT-04).
- **Validation at boundaries.** Every inbound signaling or wire message goes through a codec that returns null on invalid input. Callers drop nulls, so no exceptions cross the boundary (SECURITY-05, SECURITY-15).
- **Configuration over code.** Auth providers, `BroadcastLimits` values, the Supabase URL and key, and the Coturn endpoints are all configuration.
- **Testability.** Every SDK touchpoint is behind an interface (`SupabaseClient` injection, `PeerConnectionFactory`, `SignalingService`, `DisplayEnumerator`), so fakes can be used and both protocol sides can be tested together in zip_core (NFR-7.3).
