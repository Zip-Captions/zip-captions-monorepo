# Phase 2 Component Methods — Broadcasting & Transport

Method signatures and high-level purpose. Business rules (validation details, timeouts, retry schedules, state transition tables) are defined in each unit's Functional Design. Signatures are indicative Dart; final names may be refined in Functional Design without changing responsibilities.

**Security note (applies throughout):** any parameter or field carrying caption text (`SttResult.text`, `CaptionWireMessage.caption`) must never be logged (SECURITY-03). Tokens and TURN credentials must never be logged either.

---

## 1. Authentication

```dart
abstract interface class AuthService {
  /// Current auth state changes. Emits the current state on subscribe.
  Stream<AuthState> get authStateChanges;

  /// Signed-in user id, or null.
  String? get currentUserId;

  /// Starts the OAuth flow for a configured provider (flow per SR-01).
  Future<void> signIn(String providerId);

  /// Clears the session and tokens.
  Future<void> signOut();
}

final class AuthProviderConfig {
  final List<AuthProviderOption> providers; // id + displayLabel, configuration-driven
}

sealed class AuthState {}             // SignedOut | SigningIn | SignedIn(userId) | AuthFailed(AuthFailure)
enum AuthFailure { cancelled, denied, network, providerError, sessionExpired }

class AuthNotifier /* keepAlive */ {
  AuthState build();
  Future<void> signIn(String providerId);
  Future<void> signOut();
}
```

## 2. Broadcast Identity

```dart
final class BroadcastId {
  static BroadcastId parse(String raw);          // throws FormatException
  static BroadcastId? tryParse(String raw);
  String get value;
}

abstract final class BroadcastLink {
  /// Accepts `k7m9x2`, `zipcaptions.app/b/k7m9x2`, `https://zipcaptions.app/b/k7m9x2`.
  static BroadcastId? parseInput(String input);
  static Uri toUrl(BroadcastId id);              // https://zipcaptions.app/b/{id}
}

abstract interface class BroadcastIdentityRepository {
  /// Returns the signed-in broadcaster's permanent id, creating it on first use.
  /// Throws if signed out.
  Future<BroadcastId> getOrCreateMine();
}

abstract interface class BroadcastResolver {
  Future<BroadcastResolution> resolve(BroadcastId id);
}

sealed class BroadcastResolution {}  // NotFound | Offline | Live(sessionId, sessionName) | RateLimited
```

## 3. Signaling

```dart
abstract interface class SignalingService {
  StatusChannel statusChannel(BroadcastId id);
  SessionSignalingChannel sessionChannel(String sessionId, SignalingRole role);
}

enum SignalingRole { broadcaster, viewer }

abstract interface class StatusChannel {
  /// Broadcaster only (enforced server-side).
  Future<void> publishLive({required String sessionId, required String sessionName});
  Future<void> publishOffline();

  /// Live/offline updates, including presence-expiry offline.
  Stream<BroadcastStatus> watch();
  Future<void> close();
}

abstract interface class SessionSignalingChannel {
  Future<void> open();
  Future<void> send(SignalingMessage message);
  Stream<SignalingMessage> get messages;      // already validated; invalid messages are dropped
  Stream<PresenceSnapshot> get presence;      // broadcaster role only
  Future<void> close();
}

sealed class SignalingMessage {             // each has `type` + `version`, and from/to peer ids
  // JoinRequest(fromPeerId, viewerIdentity: null)
  // JoinAccepted(toPeerId) | JoinRejected(toPeerId, JoinRejection)
  // SdpOffer | SdpAnswer | IceCandidate | IceRestart
  // Leave(fromPeerId) | BroadcastEnded
}
enum JoinRejection { full, notLive }

abstract final class SignalingCodec {
  static Map<String, Object?> encode(SignalingMessage message);
  /// Returns null for malformed, unknown-type, unsupported-version or oversized input.
  static SignalingMessage? decode(Object? json);
}
```

## 4. Transport

```dart
abstract interface class BroadcastTransport {
  Future<void> start(BroadcastTransportContext context); // session channel, ICE servers, admission
  Future<void> stop();                                    // closes all peers, releases native resources

  /// Sends to every connected viewer; a slow/closed peer never blocks others.
  void sendToAll(CaptionWireMessage message);
  void sendTo(String peerId, CaptionWireMessage message);

  Stream<List<ViewerConnectionInfo>> get viewers;
  Stream<String> get viewerJoined;   // peerId, used for the caption-activity snapshot
  Stream<String> get viewerLeft;
}

abstract interface class ViewerTransport {
  Future<void> connect(ViewerTransportContext context);  // session channel, ICE servers
  Future<void> restart();                                 // ICE restart / re-signal after network change
  Future<void> disconnect();
  Stream<CaptionWireMessage> get messages;
  Stream<ConnectionStatus> get status;
}

abstract interface class PeerConnectionFactory {
  Future<PeerConnectionHandle> create(List<IceServer> iceServers);
}

abstract interface class IceServerProvider {
  /// Only the self-hosted Coturn; TURN entries carry short-lived credentials.
  Future<List<IceServer>> iceServersFor(String sessionId);
}

abstract interface class TurnCredentialService {
  Future<TurnCredentials> fetch(String sessionId); // username, credential, expiresAt, urls
}

class TransportSelector {
  /// Phase 2: always WebRTC. Later phases add relay / local WebSocket / BLE GATT.
  BroadcastTransport broadcastTransport();
  ViewerTransport viewerTransport();
}
```

## 5. Wire Format, Output Target, Receiver, Capacity

```dart
sealed class CaptionWireMessage {}  // Caption(SttResult) | CaptionActivityChanged(CaptionActivity) | Ended
enum CaptionActivity { active, paused, inactive }

abstract final class CaptionWireCodec {
  static Map<String, Object?> encode(CaptionWireMessage message);
  static CaptionWireMessage? decode(Object? json);   // null for unsupported version / invalid fields
}

class RemoteBroadcastTarget implements CaptionOutputTarget {
  RemoteBroadcastTarget(BroadcastTransport transport);
  @override String get targetId;                       // 'remote_broadcast'
  @override void onCaptionEvent(CaptionEvent event);   // SttResultEvent -> Caption; SessionStateEvent -> activity
  CaptionActivity get currentActivity;
  Stream<CaptionActivity> get activityChanges;         // drives the dashboard captions-inactive banner
  @override void dispose();
}

class RemoteCaptionReceiver {
  RemoteCaptionReceiver({required ViewerTransport transport, required CaptionBus viewerBus});
  Stream<CaptionActivity> get activity;
  Stream<void> get ended;
  void dispose();
}

final class BroadcastLimits {
  final int maxViewers;               // TBD (Spike 2.1), target 100-200
  final Duration presenceTimeout;     // TBD (Spike 2.1)
  final Duration reconnectWindow;     // TBD (Spike 2.1)
}

class ViewerAdmission {
  ViewerAdmission(BroadcastLimits limits);
  /// Atomic check-and-reserve; the count never exceeds maxViewers.
  AdmissionDecision tryAdmit(String peerId);
  void release(String peerId);
  int get count;
}
sealed class AdmissionDecision {}   // Admitted | Full
```

**Caption activity mapping** (in `RemoteBroadcastTarget`): `RecordingActiveState` maps to `active`. `PausedState` and `ReconnectingState` map to `paused`. `IdleState` and `StoppedState` map to `inactive`. Before any `SessionStateEvent` arrives, the initial activity comes from the current recording state when the target is created.

## 6. Session Orchestration

```dart
@freezed class BroadcastSettings {
  String sessionName;
  bool autoStartCaptioning;          // default false (plan Q3)
}

class BroadcastSessionNotifier /* keepAlive */ {
  BroadcastSessionState build();     // Offline
  /// Requires sign-in. Gets or creates the id, creates a session id, opens channels,
  /// starts the transport, registers RemoteBroadcastTarget, publishes live.
  /// Calls the recording notifier's start only if settings.autoStartCaptioning.
  Future<void> goLive();
  /// Notifies viewers, closes transport, unregisters target, publishes offline.
  /// Does not stop local captioning. Idempotent.
  Future<void> endBroadcast();
}

sealed class BroadcastSessionState {} // Offline | Starting | Live(LiveBroadcast) | Ending | BroadcastFailed(BroadcastFailure)

final class LiveBroadcast {
  final BroadcastId broadcastId;
  final Uri url;
  final String sessionId;
  final String sessionName;
  final CaptionActivity captionActivity;     // banner when != active
  final List<ViewerConnectionInfo> viewers;
  final int maxViewers;
}
enum BroadcastFailure { signedOut, signalingUnavailable, relayUnavailable, identityUnavailable, unknown }

class ViewerSessionNotifier {
  ViewerSessionState build();                // Idle
  /// Parses input, resolves, connects; creates the viewer-scoped bus + targets.
  Future<void> join(String input);
  /// Disconnects and disposes the viewer-scoped bus + targets. Idempotent.
  Future<void> leave();
  /// Viewer-scoped bus exposed to the viewer screen's caption display.
  CaptionBus? get viewerBus;
}

sealed class ViewerSessionState {}
// Idle | Resolving | Connecting | Live(captionActivity, connectionType) | Reconnecting
// | NotBroadcasting | Ended | Full | CannotConnect(ConnectFailure) | InvalidInput
enum ConnectFailure { noNetworkPath, relayUnavailable, signalingUnavailable, rateLimited, unknown }

class ReconnectPolicy {
  Duration? nextDelay(int attempt, Duration elapsed); // null = give up (window exceeded)
}
```

## 7. External Display (zip_broadcast)

```dart
abstract interface class DisplayEnumerator {
  Future<List<DisplayInfo>> displays();
  Stream<List<DisplayInfo>> get changes;     // connect/disconnect
}

final class DisplayInfo { String id; String label; Rect bounds; bool isPrimary; }

// CaptionOverlayTarget (existing) — additions:
//   Future<void> show(OverlayConfig config);       // now called from shell wiring
//   Future<void> hide();
//   Stream<OverlayEvent> get events;               // e.g. DisplayLost -> broadcaster notice

// main.dart: if launched as a desktop_multi_window sub-window, run OverlayWindowApp
void overlayWindowMain(List<String> args);
```

## 8. App Routing (zip_captions)

```dart
// go_router additions
GoRoute(path: '/join', builder: (_, __) => const JoinBroadcastScreen());
GoRoute(path: '/b/:broadcastId', builder: (_, state) =>
    BroadcastViewerScreen(input: state.pathParameters['broadcastId']!));
```
