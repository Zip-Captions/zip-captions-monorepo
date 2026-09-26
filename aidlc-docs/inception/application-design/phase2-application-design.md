# Application Design — Phase 2: Broadcasting & Transport

## Summary

Phase 2 adds the first networked layer to the Phase 1 architecture. A signed-in broadcaster goes live with a permanent broadcast ID. Viewers resolve that ID anonymously, negotiate a WebRTC data channel over Supabase Realtime signaling (with self-hosted Coturn for STUN and TURN), and receive captions into their own viewer-scoped caption bus, which the Phase 1 rendering pipeline displays unchanged. External display completes the Phase 1 caption overlay.

### Key Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Package placement | All protocol, transport and session components in zip_core, both sides (Q1:A) | Both protocol sides live and are tested together; reusable by the Phase 3 P2P key transfer |
| Transport abstraction | Role-specific `BroadcastTransport` / `ViewerTransport` + `TransportSelector` (Q2:A) | Fan-out stays inside the broadcaster transport; the Phase 3 and 5 transports plug in behind the selector (FR-4.7) |
| Broadcast vs captioning lifecycle | **Independent by default; optional coupled start** via `BroadcastSettings.autoStartCaptioning` (default off) (Q3:X) | The broadcaster can go live before captioning. Stopping captioning never ends the broadcast. Viewers see "captions paused by the broadcaster", and the broadcaster sees a prominent captions-inactive banner |
| Viewer pipeline | `ViewerSessionNotifier` with a viewer-scoped `CaptionBus`, registry and `OnScreenCaptionTarget` (Q4:A) | Viewing never mixes with self-captioning; the Phase 1 renderer and transcript writer are reused |
| Supabase client | App-initialized and injected via a provider override (Q5:A) | Matches the `sharedPreferencesProvider` pattern; zip_core stays testable without a network |
| Display enumeration | `screen_retriever` behind `DisplayEnumerator` (Q6:A) | Covers macOS, Windows and Linux with no native code; the dependency approval is recorded in Unit 8 |
| Caption activity signal | New `CaptionActivity` (active, paused, inactive) derived from the existing `SessionStateEvent`; sent as a snapshot on join | Needs no new bus event type and no change to stable contracts |
| Deferred mechanisms | Resolution (SR-02), TURN credentials (Spike 2.3 / SR-03), OAuth flow (SR-01) | Interfaces are fixed now; implementations are chosen under their security reviews |

---

## Architecture Overview

```
Broadcaster (Zip Broadcast)                          Viewer (Zip Captions)
+----------------------------------+                 +----------------------------------+
| RecordingStateNotifier (Phase 1) |                 | ViewerSessionNotifier            |
|   -> app CaptionBus -> Registry  |                 |   owns viewer CaptionBus+Registry|
|        -> OnScreen / Transcript  |                 |   <- RemoteCaptionReceiver       |
|        -> OBS / BrowserSource    |                 |   -> OnScreenCaptionTarget       |
|        -> CaptionOverlay (S-20)  |                 |   -> BroadcastViewerScreen       |
|        -> RemoteBroadcastTarget  |                 |                                  |
| BroadcastSessionNotifier         |                 | BroadcastResolver                |
|   AuthService, IdentityRepo      |                 |                                  |
+----------------+-----------------+                 +----------------+-----------------+
                 | BroadcastTransport                                 | ViewerTransport
                 v                                                    v
        +-----------------------------------------------------------------------+
        | WebRTC data channels (DTLS)  <---- P2P direct or via Coturn TURN ---->  |
        +-----------------------------------------------------------------------+
                 |  signaling / status / presence (no captions)       |
                 v                                                    v
        +-----------------------------------------------------------------------+
        | Supabase: GoTrue | Postgres registry + RLS | Realtime channels         |
        +-----------------------------------------------------------------------+
```

**Text alternative:** On the broadcaster, the Phase 1 recording pipeline publishes to the app caption bus. The registry fans out to the existing targets plus the new `RemoteBroadcastTarget`, which sends through `BroadcastTransport`. On the viewer, `ViewerSessionNotifier` owns a separate caption bus fed by `RemoteCaptionReceiver` from `ViewerTransport`. The two sides exchange captions over DTLS WebRTC data channels, either direct or relayed by Coturn. Supabase provides auth, the broadcast-ID registry, and Realtime signaling, status and presence, never captions.

---

## Component Summary

### New Components

| Component | Package | Type | Story |
|---|---|---|---|
| `supabaseClientProvider` | zip_core | provider | S-15 |
| `AuthService` / `SupabaseAuthService` | zip_core | interface / service | S-15 |
| `AuthProviderConfig`, `AuthState`, `AuthNotifier` | zip_core | model / model / notifier | S-15 |
| `BroadcastId`, `BroadcastLink` | zip_core | value object / utility | S-11, S-19 |
| `BroadcastIdentityRepository` + Supabase impl | zip_core | interface / service | S-11 |
| `BroadcastResolver`, `BroadcastResolution` | zip_core | interface / model | S-11 |
| `SignalingService`, `StatusChannel`, `SessionSignalingChannel` + Supabase impl | zip_core | interfaces / service | S-13 |
| `SignalingMessage`, `SignalingCodec`, `PresenceSnapshot` | zip_core | models / utility | S-13 |
| `BroadcastTransport`, `ViewerTransport` + WebRTC impls | zip_core | interfaces / services | S-14 |
| `PeerConnectionFactory`, `IceServerProvider`, `TurnCredentialService` | zip_core | interfaces | S-12, S-14 |
| `TransportSelector`, `ConnectionType`, `ConnectionStatus`, `ViewerConnectionInfo` | zip_core | service / models | S-14 |
| `CaptionWireMessage`, `CaptionActivity`, `CaptionWireCodec` | zip_core | models / utility | S-16 |
| `RemoteBroadcastTarget` | zip_core | CaptionOutputTarget | S-16 |
| `RemoteCaptionReceiver` | zip_core | service | S-16, S-19 |
| `BroadcastLimits`, `ViewerAdmission` | zip_core | model / service | S-18 |
| `BroadcastSettings` + notifier | zip_core | model / notifier | S-17 |
| `BroadcastSessionNotifier`, `BroadcastSessionState`, `LiveBroadcast` | zip_core | notifier / models | S-17 |
| `ViewerSessionNotifier`, `ViewerSessionState`, `ReconnectPolicy` | zip_core | notifier / model / service | S-19 |
| `DisplayEnumerator` + `ScreenRetrieverDisplayEnumerator`, `DisplayInfo` | zip_broadcast | interface / service / model | S-20 |
| `OverlayWindowEntry`, `OverlayWindowApp` | zip_broadcast | entry / widget | S-20 |
| Sign-in view, `BroadcastSetupScreen`, `LiveBroadcastDashboard`, `ExternalDisplayControls` | zip_broadcast | UI | S-15, S-17, S-20 |
| `JoinBroadcastScreen`, `BroadcastViewerScreen`, `/join` and `/b/:broadcastId` routes | zip_captions | UI / routing | S-19 |
| Registry migration, resolution path, Realtime authorization | zip_supabase | backend | S-11, S-13 |
| Coturn service, TURN credential issuer | local stack | infrastructure | S-12 |

### Modified Components

| Component | Package | Change |
|---|---|---|
| `CaptionOverlayTarget` | zip_broadcast | `show()` and `hide()` wired to settings; display selection; disconnect fallback |
| `OutputTargetSettings` | zip_broadcast | Adds the selected external display ID |
| `ZbAppShell` | zip_broadcast | Overlay show and hide wiring |
| `main.dart` | both apps | Supabase init and override; zip_broadcast sub-window routing |
| Router | zip_captions | New routes; path URL strategy on web |

---

## Security Design Notes (Phase 2 additions)

1. **No caption content in logs** (carried forward). This also covers the codecs, transports, receiver and signaling. Decode failures log only the failure category.
2. **Tokens and credentials.** Auth tokens stay inside `supabase_flutter` secure storage and never cross `AuthService`. TURN credentials are short-lived and never logged or persisted.
3. **Zero-retention.** Realtime carries no caption payloads in Phase 2. Coturn relays DTLS-encrypted data it cannot read, and its log configuration is set under SR-03.
4. **Authorization boundaries.** Only the owning broadcaster publishes on `status:` and broadcaster control messages. Viewers publish only their own join, SDP, ICE and leave messages (SR-02).
5. **Anonymous surface.** Resolution returns only the broadcast ID, status, session name and session ID, and applies enumeration controls (SR-02). Input is validated by `BroadcastId` before any network call.
6. **Viewer anonymity.** `viewerIdentity` is always null in Phase 2. `ViewerConnectionInfo` has no identity, and metrics carry neither identity nor content.
7. **Security-critical pre-approvals.** SR-01 (OAuth), SR-02 (RLS and Realtime authorization) and SR-03 (server logs) gate their units' Code Generation.

---

## Revisions to Earlier Artifacts (from plan Q3)

The Q3 answer (independent lifecycles with an optional coupled start) refines the approved requirements and stories:
- `phase2-requirements.md`: new FR-6.7 (independent lifecycles, auto-start option, captions-inactive banner) and FR-7.4 (live-with-captions-paused viewer state).
- `phase2-stories.md`: S-16, S-17 and S-19 criteria, plus Proto-11, Proto-12 and Proto-15, updated to match.

---

## Detailed Artifacts

- [phase2-components.md](phase2-components.md): component definitions and responsibilities
- [phase2-component-methods.md](phase2-component-methods.md): method signatures and models
- [phase2-services.md](phase2-services.md): service layers and orchestration flows F1-F8
- [phase2-component-dependency.md](phase2-component-dependency.md): dependency matrix, communication patterns and data flow
