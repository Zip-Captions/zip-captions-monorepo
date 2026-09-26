# Phase 2 Components — Broadcasting & Transport

Component definitions and responsibilities. Method signatures are in `phase2-component-methods.md`, and orchestration is in `phase2-services.md`. Detailed business rules are defined per unit in Functional Design.

Per plan Q1:A, all protocol, transport and session components live in **zip_core** (both broadcaster and viewer sides). The apps hold UI, routing and wiring only. The one exception is external display (S-20), which extends the existing zip_broadcast overlay.

---

## 1. Authentication (S-15, Unit 2)

| Component | Type | Responsibility |
|---|---|---|
| `supabaseClientProvider` | provider (keepAlive) | Holds the `SupabaseClient`. Throws unless overridden; each app overrides it in `main()` after `Supabase.initialize` (plan Q5:A, same pattern as `sharedPreferencesProvider`). |
| `AuthService` | interface | Sign in with a configured provider, sign out, expose auth state changes and the current user ID. No tokens cross this interface. |
| `SupabaseAuthService` | service | GoTrue implementation via `supabase_flutter`. Token storage and refresh are delegated to the SDK. The per-platform OAuth flow is defined under SR-01. |
| `AuthProviderConfig` | model | The enabled OAuth providers (identifier and display label), loaded from configuration, so adding a provider needs no code change (FR-1.2). |
| `AuthState` | sealed model | `signedOut`, `signingIn`, `signedIn(userId)`, `failed(AuthFailure)`. |
| `AuthNotifier` | notifier (keepAlive) | Exposes `AuthState` to the UI. `signIn(providerId)` and `signOut()` call `AuthService` explicitly. |

## 2. Broadcast Identity (S-11, Unit 3)

| Component | Type | Responsibility |
|---|---|---|
| `BroadcastId` | value object | Validated short ID from the unambiguous alphabet. `parse` and `tryParse` reject bad length or characters before any network call (FR-2.3, SECURITY-05). |
| `BroadcastLink` | utility | Parses a pasted URL (`zipcaptions.app/b/{id}`, with or without scheme) or a bare ID into a `BroadcastId`, and formats the stable URL (FR-2.4, FR-7.1). |
| `BroadcastIdentityRepository` | interface | `getOrCreateMine()`: returns the signed-in broadcaster's permanent ID, creating it on first use (FR-2.1). |
| `SupabaseBroadcastIdentityRepository` | service | Implementation against the registry table. Retries on a uniqueness collision. The table and RLS are defined under SR-02. |
| `BroadcastResolver` | interface | `resolve(BroadcastId)` gives `notFound`, `offline`, or `live(sessionId, sessionName)`. The mechanism (restricted RPC/view plus the status channel, or an Edge Function) is decided in Unit 3 Functional Design under SR-02 (FR-2.5). |
| `BroadcastResolution` | sealed model | Result of `resolve`. It carries no account identifiers (NFR-3.5). |

## 3. Signaling (S-13, Unit 3)

| Component | Type | Responsibility |
|---|---|---|
| `SignalingService` | interface | Factory for the two channel types per Section 9: `status:{broadcast_id}` and `signaling:{session_id}`. |
| `StatusChannel` | interface | The broadcaster publishes live or offline status (with `sessionId` and `sessionName`). Viewers and resolvers watch it. Presence expiry means offline (FR-2.6, FR-6.6). |
| `SessionSignalingChannel` | interface | Role-scoped: send and receive `SignalingMessage`s, plus a presence stream for viewer count (FR-3.4). |
| `SupabaseSignalingService` | service | Supabase Realtime implementation. Channel authorization is enforced server-side (SR-02). |
| `SignalingMessage` | sealed model | Versioned, `type`-discriminated JSON: `joinRequest` (with a nullable `viewerIdentity`, FR-3.5), `joinAccepted`, `joinRejected(reason)`, `sdpOffer`, `sdpAnswer`, `iceCandidate`, `iceRestart`, `leave`, `broadcastEnded`. |
| `SignalingCodec` | utility | Encode and decode with schema and size validation. Invalid, unknown and oversized messages decode to a rejection and are never logged by content (FR-3.2, NFR-3.6). |
| `PresenceSnapshot` | model | Current viewer peer IDs in a session, with no identity. |

## 4. Transport (S-12 client side, S-14, Units 4-5)

Per plan Q2:A, the interfaces are role-specific.

| Component | Type | Responsibility |
|---|---|---|
| `BroadcastTransport` | interface | Broadcaster side: accept viewers admitted by capacity, send a wire message to all or to one viewer, report `ViewerConnectionInfo` per viewer, and emit viewer joined and left events. |
| `ViewerTransport` | interface | Viewer side: connect to a live session, expose a stream of `CaptionWireMessage`s and a `ConnectionStatus` stream, support restart after a network change, and disconnect. |
| `WebRtcBroadcastTransport` | service | Star topology, one peer connection per viewer (FR-4.2). Uses `SessionSignalingChannel` for SDP and ICE. Per-viewer isolation: one viewer's failure never affects others (NFR-4.2). |
| `WebRtcViewerTransport` | service | Single peer connection. ICE restart or re-signaling on network change (FR-7.5). |
| `PeerConnectionFactory` | interface | Thin seam over `flutter_webrtc` so transports are testable with fakes (NFR-7.3). |
| `IceServerProvider` | interface | Supplies ICE servers for a session: only the self-hosted Coturn, with short-lived TURN credentials (FR-4.3, FR-4.4). |
| `TurnCredentialService` | interface | Fetches ephemeral TURN credentials. The implementation mechanism comes from Spike 2.3 and Unit 4 Infrastructure Design under SR-03. |
| `TransportSelector` | service | ADR-011 negotiation entry point. Phase 2 always returns WebRTC. Later phases add the relay, local WebSocket and BLE GATT without changing callers (FR-4.7). |
| `ConnectionType` | enum | `p2pDirect`, `turnRelayed`, `connecting`, `disconnected` (FR-4.6). |
| `ViewerConnectionInfo` | model | `peerId`, `connectionType`, `connectedAt`. It has no viewer identity (NFR-6.2). |
| `ConnectionStatus` | sealed model | Viewer-side transport state: `connecting`, `connected(connectionType)`, `interrupted`, `failed(ConnectFailure)`. |

## 5. Caption Wire Format, Output Target and Receiver (S-16, S-18, Unit 5)

| Component | Type | Responsibility |
|---|---|---|
| `CaptionWireMessage` | sealed model | Data-channel messages, versioned JSON: `caption(SttResult fields)`, `captionActivity(CaptionActivity)`, `broadcastEnded`. |
| `CaptionActivity` | enum | `active`, `paused`, `inactive`. It tells viewers whether the broadcaster's captioning is running, supporting the independent lifecycles (plan Q3). |
| `CaptionWireCodec` | utility | Maps `SttResult` to and from the wire format without modifying ADR-005 fields (FR-5.2). Rejects unsupported versions. |
| `RemoteBroadcastTarget` | CaptionOutputTarget | Registered on the broadcaster's `CaptionOutputTargetRegistry`. Maps `SttResultEvent` to `caption` and `SessionStateEvent` to `captionActivity`. Tracks the latest activity and sends it to each newly joined viewer as a snapshot. It never sends caption backlog (FR-5.4). It exposes the current activity so the dashboard can show the captions-inactive notice. |
| `RemoteCaptionReceiver` | service | Viewer side: decodes transport messages and publishes `SttResultEvent`s into the viewer-scoped `CaptionBus` (FR-5.3). Forwards `captionActivity` and `broadcastEnded` to the viewer session. |
| `BroadcastLimits` | model | Viewer cap (value TBD from Spike 2.1), presence timeout and reconnection window. Configuration-backed, so spike results change values, not code. |
| `ViewerAdmission` | service | Decides whether to admit or refuse a join as full. The count can never exceed the cap under concurrent joins (FR-8, PBT-03). |

## 6. Session Orchestration (S-17, S-19, Units 5-7)

| Component | Type | Responsibility |
|---|---|---|
| `BroadcastSettings` | freezed model | `sessionName`, and `autoStartCaptioning` (default **false**, plan Q3: optional coupled start). Persisted per concern (Phase 1 settings pattern). |
| `BroadcastSettingsNotifier` | notifier | Loads and persists `BroadcastSettings`. |
| `BroadcastSessionState` | sealed model | `offline`, `starting`, `live(LiveBroadcast)`, `ending`, `failed(BroadcastFailure)`. `LiveBroadcast` carries the broadcast ID, URL, session ID and name, caption activity, viewer connections, count and cap. |
| `BroadcastSessionNotifier` | notifier (keepAlive) | Broadcaster orchestration: `goLive()` and `endBroadcast()`. It explicitly calls identity, signaling, transport and registry. It starts captioning only when `autoStartCaptioning` is on. Captioning stop, pause and resume never end the broadcast (plan Q3). |
| `ViewerSessionState` | sealed model | `idle`, `resolving`, `connecting`, `live(captionActivity, connectionType)`, `reconnecting`, `notBroadcasting`, `ended`, `full`, `cannotConnect(reason)`. |
| `ViewerSessionNotifier` | notifier | Viewer orchestration (plan Q4:A): `join(input)` and `leave()`. Owns a **viewer-scoped** `CaptionBus`, `CaptionOutputTargetRegistry` and `OnScreenCaptionTarget`, created per viewing session and disposed on leave, so viewing never mixes with self-captioning. Applies the reconnection policy. |
| `ReconnectPolicy` | service | Retry schedule and window for viewer reconnection (window TBD from Spike 2.1). |

## 7. External Display (S-20, Unit 8) — zip_broadcast

| Component | Type | Responsibility |
|---|---|---|
| `DisplayEnumerator` | interface | Lists connected displays and emits change events (connect and disconnect). |
| `ScreenRetrieverDisplayEnumerator` | service | Implementation using `screen_retriever` (approved in plan Q6:A; SECURITY-10 pinning and justification are recorded in Unit 8). |
| `DisplayInfo` | model | Display ID, label, bounds, and whether it is primary. |
| `CaptionOverlayTarget` | CaptionOutputTarget (**modified**) | Its `show()` and `hide()` are now driven by output-target settings. It opens on the selected display, and falls back and notifies the broadcaster when that display disconnects (FR-9.4). |
| `OverlayWindowEntry` | entry point (**new**) | Secondary-window entry in `main.dart` (detects `desktop_multi_window` sub-window arguments) that runs the borderless caption window app. |
| `OverlayWindowApp` | widget (**new**) | Renders received captions with the broadcaster's display settings and WCAG AAA contrast. |
| `OutputTargetSettings` | model (**modified**) | Adds the selected external display ID. |

## 8. App UI and Wiring

### zip_broadcast
| Component | Type | Responsibility |
|---|---|---|
| `main.dart` | entry (**modified**) | `Supabase.initialize` and the `supabaseClientProvider` override. Routes sub-window launches to `OverlayWindowEntry`. |
| `AccountSection` / sign-in view | screen (**new**) | Provider buttons, signed-in state and sign-out, and auth failure messages (Proto-10). |
| `BroadcastSetupScreen` | screen (**new**) | Session name, output targets, the auto-start captioning toggle, and the stable URL with copy (Proto-11). |
| `LiveBroadcastDashboard` | screen (**new**) | Viewer count against cap, per-viewer connection type, caption preview, audio level, end broadcast. A **prominent captions-inactive banner** shows whenever the broadcast is live and caption activity is not `active` (plan Q3; Proto-12). |
| `ExternalDisplayControls` | widget (**new**) | Display list, enable and disable, status, and the disconnected notice (Proto-13). |

### zip_captions
| Component | Type | Responsibility |
|---|---|---|
| `main.dart` | entry (**modified**) | `Supabase.initialize` and the provider override. Path URL strategy on web. |
| Router | config (**modified**) | Adds `/join` and `/b/:broadcastId` (FR-7.2). |
| `JoinBroadcastScreen` | screen (**new**) | ID or URL entry and validation (Proto-14). |
| `BroadcastViewerScreen` | screen (**new**) | Renders the viewer bus through the Phase 1 caption display widget with the viewer's own display settings. It shows each `ViewerSessionState` distinctly, including a **"captions paused by the broadcaster"** message when live with activity `paused` or `inactive` (plan Q3). Every state is announced to screen readers (NFR-5.2; Proto-15). |

## 9. Backend and Infrastructure (Units 3-4)

| Component | Location | Responsibility |
|---|---|---|
| Broadcast ID registry migration | `packages/zip_supabase/migrations/` | Registry table following Section 9 conventions, with RLS (SR-02). |
| Resolution path | zip_supabase (RPC/view or Edge Function) | Anonymous-safe resolution with enumeration controls (SR-02). |
| Realtime channel authorization | zip_supabase | Only the broadcaster publishes status and control messages (SR-02). |
| Coturn service | local dev stack | STUN and TURN, ephemeral credentials, payload-free logs, private-range denial, metrics (SR-03). |
| TURN credential issuer | zip_supabase or stack (per Spike 2.3) | Backs `TurnCredentialService`. |

---

## Modified Phase 1 Components (summary)

| Component | Package | Change |
|---|---|---|
| `CaptionOverlayTarget` | zip_broadcast | Wired to settings; display selection; disconnect fallback |
| `OutputTargetSettings` | zip_broadcast | Adds the external display ID |
| `main.dart` (both apps) | apps | Supabase init and override; zip_broadcast sub-window routing |
| Zip Captions router | zip_captions | `/join` and `/b/:broadcastId` routes |
| `ZbAppShell` | zip_broadcast | Registers and unregisters `RemoteBroadcastTarget` through `BroadcastSessionNotifier`; overlay show and hide wiring |

Unchanged stable contracts: `SttResult`, `CaptionEvent`, `CaptionBus`, `CaptionOutputTarget`, `RecordingState`, `ObsWebSocketTarget`, `BrowserSourceTarget`.
