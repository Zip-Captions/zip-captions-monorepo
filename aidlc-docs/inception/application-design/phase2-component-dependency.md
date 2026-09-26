# Phase 2 Component Dependencies — Broadcasting & Transport

## Package Dependency Rules (unchanged)

- `zip_captions` and `zip_broadcast` depend on `zip_core` only, never on each other.
- New third-party dependencies: `supabase_flutter` and `flutter_webrtc` in zip_core (both pre-approved), and `screen_retriever` in zip_broadcast (approved in plan Q6:A; SECURITY-10 record in Unit 8). Each app adds `supabase_flutter` for initialization (plan Q5:A).

## Dependency Matrix

Rows depend on columns. "C" means constructor injection, "S" a stream subscription it owns, and "R" registration on the registry.

| Component | AuthService | IdentityRepo | Resolver | SignalingService | TransportSelector / transports | IceServerProvider | ViewerAdmission | CaptionBus / Registry | RemoteBroadcastTarget | RemoteCaptionReceiver | RecordingStateNotifier | DisplayEnumerator |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| AuthNotifier | C | | | | | | | | | | | |
| SupabaseBroadcastIdentityRepository | C (user id) | | | | | | | | | | | |
| BroadcastResolver impl | | | | C (status) | | | | | | | | |
| BroadcastSessionNotifier | C | C | | C | C | C | C | R (app registry) | C, S | | explicit start call (only if auto-start) | |
| RemoteBroadcastTarget | | | | | C (BroadcastTransport) | | | receives events via R | | | | |
| WebRtcBroadcastTransport | | | | C (session channel) | | C | C | | | | | |
| WebRtcViewerTransport | | | | C (session channel) | | C | | | | | | |
| IceServerProvider | | | | | | | | | | | | |
| ViewerSessionNotifier | | | C | C | C | C | | owns viewer-scoped bus + registry | | C, S | | |
| RemoteCaptionReceiver | | | | | C (ViewerTransport) | | | publishes to viewer bus | | | | |
| CaptionOverlayTarget | | | | | | | | R (app registry) | | | | S |
| ZbAppShell | | | | | | | | R | | | | |

`IceServerProvider` depends on `TurnCredentialService`. `SupabaseSignalingService`, `SupabaseAuthService`, `SupabaseBroadcastIdentityRepository` and the resolver all depend on the injected `SupabaseClient`.

## Layered View

```
+---------------------------------------------------------------+
| UI: zip_broadcast screens          | UI: zip_captions screens |
| (sign-in, setup, dashboard,        | (join, viewer, /b/:id)   |
|  external display controls)        |                          |
+-------------------+----------------+-------------+------------+
                    | ref.read / ref.watch (state) |
+-------------------v------------------------------v------------+
| Notifiers: AuthNotifier, BroadcastSessionNotifier,            |
|            ViewerSessionNotifier, BroadcastSettingsNotifier   |
|            (existing) RecordingStateNotifier                  |
+----------+-------------------+---------------------+----------+
           | explicit calls    | registers           | owns
+----------v--------+  +-------v-----------------+  +v------------------------+
| Backend access    |  | Broadcaster pipeline    |  | Viewer pipeline         |
| AuthService       |  | app CaptionBus          |  | viewer CaptionBus       |
| IdentityRepo      |  |  -> Registry            |  |  <- RemoteCaption-      |
| Resolver          |  |     -> RemoteBroadcast- |  |     Receiver            |
| SignalingService  |  |        Target           |  |  -> Registry            |
| TurnCredential-   |  |     -> OBS / Browser /  |  |     -> OnScreenCaption- |
|   Service         |  |        Overlay (Ph 1)   |  |        Target           |
+----------+--------+  +-------+-----------------+  +-----------+-------------+
           |                   |                                |
+----------v-------------------v--------------------------------v-------------+
| Transport: TransportSelector -> WebRtcBroadcastTransport / WebRtcViewer-    |
|            Transport -> PeerConnectionFactory (flutter_webrtc)              |
|            IceServerProvider (Coturn only), ViewerAdmission                 |
+----------+------------------------------------------------------------------+
           |
+----------v------------------------------------------------------------------+
| External: Supabase GoTrue, Postgres (registry + RLS), Realtime (status,     |
|           signaling, presence; never captions), Coturn (STUN/TURN)          |
+-----------------------------------------------------------------------------+
```

**Text alternative:** The UI in both apps reads notifier state. Notifiers make explicit calls to backend-access services and own the pipelines. The broadcaster pipeline is the Phase 1 app bus and registry, with `RemoteBroadcastTarget` added beside the OBS, browser source and overlay targets. The viewer pipeline is a per-session bus fed by `RemoteCaptionReceiver` and rendered through `OnScreenCaptionTarget`. Both pipelines sit on the transport layer, which uses `flutter_webrtc` with ICE servers from Coturn only. External systems are GoTrue, Postgres, Realtime (signaling and presence only) and Coturn.

## Communication Patterns

| From | To | Channel | Payload | Encryption |
|---|---|---|---|---|
| Broadcaster app | Postgres | Supabase REST (RLS) | Registry get-or-create | TLS |
| Viewer app | Resolution path | RPC/view or Edge Fn (SR-02) | Broadcast ID lookup (ID, status, session name) | TLS |
| Broadcaster app | Viewers | Realtime `status:{broadcast_id}` | Live or offline, session ID and name | TLS |
| Broadcaster and viewers | each other | Realtime `signaling:{session_id}` | Join, SDP, ICE, leave, ended (no captions) | TLS |
| Broadcaster | Each viewer | WebRTC data channel | `CaptionWireMessage` (captions, activity, ended) | DTLS |
| Either app | Coturn | STUN/TURN | ICE; relayed DTLS data | TURN (TLS where configured) + DTLS end-to-end |
| Broadcaster app | Overlay sub-window | desktop_multi_window `invokeMethod` | Caption text and config (local process) | n/a (in-process IPC) |

## Data Flow — Caption from Speech to Remote Viewer

```
Mic -> SttEngine -> RecordingStateNotifier -> app CaptionBus
    -> CaptionOutputTargetRegistry -> RemoteBroadcastTarget
    -> CaptionWireCodec.encode -> BroadcastTransport.sendToAll
    -> [DTLS data channel, P2P or via Coturn TURN]
    -> ViewerTransport.messages -> CaptionWireCodec.decode
    -> RemoteCaptionReceiver -> viewer CaptionBus
    -> viewer Registry -> OnScreenCaptionTarget -> CaptionDisplayWidget
       (viewer's own DisplaySettings)
```

## Coupling Notes

- `RemoteBroadcastTarget` knows only `BroadcastTransport`, not WebRTC. The Phase 3 relay and Phase 5 transports slot in behind `TransportSelector` (FR-4.7).
- `ViewerSessionNotifier` never touches the app-wide `CaptionBus`, so self-captioning and viewing are isolated (plan Q4:A).
- `BroadcastSessionNotifier` couples to `RecordingStateNotifier` only through the optional auto-start call. Caption activity flows back through the bus that already exists, not through a dependency on the recording notifier (plan Q3).
- External display (Unit 8) has no dependency on any broadcast component.
