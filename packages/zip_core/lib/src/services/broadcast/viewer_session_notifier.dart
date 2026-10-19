import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/constants/broadcast_limits_default.dart';
import 'package:zip_core/src/models/broadcast_id.dart';
import 'package:zip_core/src/models/broadcast_link.dart';
import 'package:zip_core/src/models/broadcast_resolution.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/ice_server.dart';
import 'package:zip_core/src/models/viewer_session_state.dart';
import 'package:zip_core/src/models/viewer_transport_context.dart';
import 'package:zip_core/src/output/on_screen_caption_target.dart';
import 'package:zip_core/src/providers/broadcast_resolver_provider.dart';
import 'package:zip_core/src/providers/ice_server_provider_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/providers/viewer_transport_factory_provider.dart';
import 'package:zip_core/src/services/broadcast/viewer_session_resources.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';
import 'package:zip_core/src/services/caption/remote_caption_receiver.dart';

part 'viewer_session_notifier.g.dart';

/// The viewer's own session orchestration (fixed shape, Application Design;
/// behaviour designed in `business-logic-model.md` F-7.2-F-7.9).
///
/// One app-lifetime notifier: at most one viewing session, surviving
/// navigation. Every repeated network attempt originates with a user action
/// or the status watch — never with a notifier-owned retry loop
/// (`business-rules.md` Rule 14).
@Riverpod(keepAlive: true)
class ViewerSessionNotifier extends _$ViewerSessionNotifier {
  static final _log = Logger('zip_core.ViewerSessionNotifier');

  ViewerSessionResources? _resources;
  String? _sessionName;
  BroadcastId? _currentBroadcastId;
  // The broadcast whose resolution request is in flight, if any. Set when a
  // request starts and cleared only by that same request, so the Rule 1
  // no-op check also covers `ResolvingState` — where `_currentBroadcastId`
  // is not set yet.
  BroadcastId? _resolvingBroadcastId;
  CaptionActivity _lastActivity = CaptionActivity.inactive;

  /// Incremented by every `join()` start, implicit leave and `leave()`; each
  /// `join()` re-checks it after its awaits so a superseded attempt cannot
  /// allocate resources or write state (NFR Design Q3).
  int _sessionEpoch = 0;

  @override
  ViewerSessionState build() {
    ref.onDispose(leave);
    return const ViewerSessionState.idle();
  }

  /// The viewer-scoped caption bus for the active session, if any (fresh
  /// per session — never the app's own bus, Rule 7).
  CaptionBus? get viewerBus => _resources?.bus;

  /// The viewer-scoped on-screen target for the active session, if any.
  /// Constructed with `repository: null`: remote captions are never
  /// persisted (Rule 7).
  OnScreenCaptionTarget? get viewerCaptionTarget => _resources?.target;

  /// The live session's display name, once resolution supplied one.
  String? get sessionName => _sessionName;

  /// The broadcast currently held, for route-reentry checks (F-7.2).
  BroadcastId? get currentBroadcastId => _currentBroadcastId;

  /// The broadcast whose resolution is in flight, if any.
  BroadcastId? get resolvingBroadcastId => _resolvingBroadcastId;

  /// Joins the broadcast described by [input] (F-7.2).
  ///
  /// A no-op for the broadcast already held, and for invalid input while a
  /// session is active; a different broadcast leaves first (Rule 1).
  Future<void> join(String input) async {
    final id = BroadcastLink.parseInput(input);

    if (id == null) {
      // An invalid input never tears down a session that is already held —
      // including a terminal one, whose caption pipeline stays alive until
      // leave() (Rule 1, F-7.5 step 3). Never echo the raw input (Rule 8).
      if (_resources != null || _hasActiveSession) {
        _log.info('join: invalid input ignored while a session is held');
        return;
      }
      _log.info('join: invalid input');
      _setState(const ViewerSessionState.invalidInput());
      return;
    }

    final current = state;
    if (current is! ViewerIdleState &&
        current is! InvalidInputState &&
        current is! EndedState &&
        current is! FullState &&
        current is! CannotConnectState &&
        (id == _currentBroadcastId || id == _resolvingBroadcastId)) {
      return;
    }

    if (_currentBroadcastId != null && id != _currentBroadcastId) {
      await leave();
    } else if (_currentBroadcastId == id) {
      // Same broadcast, but the prior session is terminal: its holder has
      // already released the transport/status watch, so a new session needs
      // a fresh holder rather than a partially released one. The old
      // pipeline is disposed with it (Rule 6: the retry is a full rejoin).
      await leave();
    }

    final epoch = ++_sessionEpoch;
    _setState(const ViewerSessionState.resolving());

    _resolvingBroadcastId = id;
    final BroadcastResolution resolution;
    try {
      resolution = await ref.read(broadcastResolverProvider).resolve(id);
    } finally {
      // Only the request that owns the slot may release it: a superseded
      // request must not clear the id a newer one is resolving.
      if (_resolvingBroadcastId == id) _resolvingBroadcastId = null;
    }
    if (epoch != _sessionEpoch) return;

    switch (resolution) {
      case BroadcastNotFound():
        _setState(
          const ViewerSessionState.cannotConnect(NotFound()),
        );
      case BroadcastRateLimited():
        _setState(
          const ViewerSessionState.cannotConnect(RateLimited()),
        );
      case BroadcastResolutionFailed():
        _setState(
          const ViewerSessionState.cannotConnect(ResolutionFailed()),
        );
      case BroadcastOffline():
        _currentBroadcastId = id;
        _allocate(id, null);
        _setState(const ViewerSessionState.notBroadcasting());
      case BroadcastLive(:final sessionId, :final sessionName):
        _currentBroadcastId = id;
        _sessionName = sessionName;
        _allocate(id, sessionId);
        if (epoch != _sessionEpoch) return;
        await _connect(epoch);
    }
  }

  /// Leaves the current session (F-7.7). Idempotent from any state.
  Future<void> leave() async {
    _sessionEpoch++;
    _resolvingBroadcastId = null;
    // The holder is taken out of the field before its teardown starts: a
    // teardown that synchronously triggers another leave()/join() must see
    // "already released", never the same holder twice (single-writer rule).
    final resources = _resources;
    _resources = null;
    if (resources == null) {
      if (state is ViewerIdleState) return;
      _currentBroadcastId = null;
      _sessionName = null;
      _setState(const ViewerSessionState.idle());
      return;
    }

    await resources.disposeAll(_log);
    _currentBroadcastId = null;
    _sessionName = null;
    _lastActivity = CaptionActivity.inactive;
    _setState(const ViewerSessionState.idle());
  }

  bool get _hasActiveSession {
    final current = state;
    return current is ResolvingState ||
        current is ConnectingState ||
        current is LiveViewState ||
        current is ViewerReconnectingState ||
        current is NotBroadcastingState;
  }

  /// Creates the viewer-scoped pipeline and subscriptions for [id]
  /// (F-7.2 step 4). [sessionId] is null for an `offline` resolution.
  void _allocate(BroadcastId id, String? sessionId) {
    final bus = CaptionBus();
    final target = OnScreenCaptionTarget(targetId: 'viewer');
    final registry = CaptionOutputTargetRegistry(bus)..add(target);
    final transport = ref.read(viewerTransportFactoryProvider)();
    final receiver = RemoteCaptionReceiver(
      transport: transport,
      viewerBus: bus,
    );
    final statusChannel = ref.read(signalingServiceProvider).statusChannel(id);

    final resources = ViewerSessionResources(
      broadcastId: id,
      sessionId: sessionId,
      transport: transport,
      receiver: receiver,
      bus: bus,
      registry: registry,
      target: target,
      statusChannel: statusChannel,
      statusWatch: statusChannel.watch().listen(_onStatusChannelEvent),
      statusSub: transport.status.listen(_onTransportStatus),
      activitySub: receiver.activity.listen(_onActivity),
      endedSub: receiver.ended.listen((_) => _onEnded()),
      windowTimer: null,
    );
    _resources = resources;
    _log.info('session resources allocated: broadcastId=${id.value}');
  }

  /// F-7.2 step 5: fetch ICE servers, then connect. Every failure maps to
  /// the generic "couldn't reach" reason — never `Timeout`, which stays
  /// reserved for the transport's own reported outcome.
  Future<void> _connect(int epoch) async {
    final resources = _resources;
    final sessionId = resources?.sessionId;
    final transport = resources?.transport;
    final id = _currentBroadcastId;
    if (resources == null ||
        sessionId == null ||
        transport == null ||
        id == null) {
      return;
    }

    _setState(const ViewerSessionState.connecting());

    List<IceServer> iceServers;
    try {
      iceServers = await ref
          .read(iceServerProviderProvider)
          .iceServersFor(sessionId);
    } on Object catch (e) {
      if (epoch != _sessionEpoch) return;
      _log.warning('iceServersFor() failed: ${e.runtimeType}');
      await _terminate(
        const ViewerSessionState.cannotConnect(IceFailed()),
      );
      return;
    }
    if (epoch != _sessionEpoch) return;

    try {
      await transport.connect(
        ViewerTransportContext(
          sessionId: sessionId,
          broadcastId: id,
          signalingService: ref.read(signalingServiceProvider),
          iceServers: iceServers,
        ),
      );
    } on Object catch (e) {
      if (epoch != _sessionEpoch) return;
      _log.warning('transport.connect() failed: ${e.runtimeType}');
      await _terminate(
        const ViewerSessionState.cannotConnect(IceFailed()),
      );
    }
  }

  void _onTransportStatus(ConnectionStatus status) {
    final resources = _resources;
    if (resources == null) return;
    final current = state;
    if (current is! ConnectingState &&
        current is! LiveViewState &&
        current is! ViewerReconnectingState) {
      return;
    }

    switch (status) {
      case Connecting():
        break;
      case Connected(:final connectionType):
        _setState(
          ViewerSessionState.liveView(
            captionActivity: _lastActivity,
            connectionType: connectionType,
          ),
        );
      case Interrupted():
        _enterReconnecting();
      case Failed(:final failure):
        if (failure is BroadcastFull) {
          unawaited(_terminate(const ViewerSessionState.full()));
        } else {
          unawaited(
            _terminate(ViewerSessionState.cannotConnect(failure)),
          );
        }
    }
  }

  void _onActivity(CaptionActivity activity) {
    _lastActivity = activity;
    final current = state;
    if (current is LiveViewState) {
      _setState(current.copyWith(captionActivity: activity));
    }
  }

  void _onEnded() {
    if (_resources == null) return;
    unawaited(_terminate(const ViewerSessionState.ended()));
  }

  /// Rule 4's scoped split for status-watch emissions.
  void _onStatusChannelEvent(BroadcastStatus status) {
    final resources = _resources;
    if (resources == null) return;
    resources.lastStatus = status;
    final current = state;

    switch (status) {
      case BroadcastStatusOffline():
        if (current is ViewerReconnectingState) {
          // Rule 4b: liveness is authoritatively known — do not wait out
          // the remaining window.
          _setState(const ViewerSessionState.notBroadcasting());
        }
      // Rule 4c: LiveView keeps the data channel authoritative; every
      // other state is a no-op.
      case BroadcastStatusLive(:final sessionId, :final sessionName):
        if (current is NotBroadcastingState) {
          resources
            ..sessionId = sessionId
            ..lastStatus = status;
          _sessionName = sessionName;
          _setState(const ViewerSessionState.connecting());
          unawaited(_connect(_sessionEpoch));
        }
    }
  }

  /// Enters `ViewerReconnectingState` with exactly one window timer
  /// (Rule 3): no `restart()` calls anywhere.
  void _enterReconnecting() {
    final resources = _resources;
    if (resources == null) return;
    resources.windowTimer?.cancel();
    resources.windowTimer = Timer(
      defaultBroadcastLimits.reconnectWindow,
      _onWindowExpired,
    );
    _setState(const ViewerSessionState.reconnecting());
  }

  /// F-7.4 step 4: three outcomes, decided by the last status emission.
  Future<void> _onWindowExpired() async {
    final resources = _resources;
    if (resources == null || state is! ViewerReconnectingState) return;
    final epoch = _sessionEpoch;

    final lastStatus = resources.lastStatus;
    if (lastStatus is BroadcastStatusOffline) {
      _setState(const ViewerSessionState.notBroadcasting());
      return;
    }
    if (lastStatus == null) {
      await _terminate(
        const ViewerSessionState.cannotConnect(ResolutionFailed()),
      );
      return;
    }

    final transport = resources.transport;
    if (transport != null) {
      try {
        await transport.disconnect();
      } on Object catch (e) {
        _log.warning('transport.disconnect() failed: ${e.runtimeType}');
      }
    }
    if (epoch != _sessionEpoch) return;
    await _terminate(
      const ViewerSessionState.cannotConnect(IceFailed()),
    );
  }

  /// Releases everything a terminal transition owns, then writes [next] last
  /// and unconditionally, so a throwing teardown step cannot leave the
  /// terminal state unreached (NFR Design Q4).
  ///
  /// The viewer-scoped bus/registry/target survive so the last captions stay
  /// visible until `leave()` (F-7.5 step 3).
  Future<void> _terminate(ViewerSessionState next) async {
    // Unlike leave(), the holder stays in the field: terminal states keep
    // the caption pipeline until the user leaves (F-7.5 step 3), and
    // `disposeAll`'s per-step nulling is the release record so a re-entry
    // (a second terminal event) skips the already-released parts.
    final resources = _resources;
    if (resources != null) {
      await resources.disposeAll(_log, releaseCaptionPipeline: false);
    }
    _setState(next);
  }

  /// The only state writer. Cancels the window timer whenever [next] is not
  /// `ViewerReconnectingState`, making Rule 3's cancellation structural
  /// (NFR Design Q2).
  void _setState(ViewerSessionState next) {
    final resources = _resources;
    if (next is! ViewerReconnectingState) {
      resources?.windowTimer?.cancel();
      resources?.windowTimer = null;
    }
    state = next;
    _log.fine('state=${next.runtimeType}');
  }
}
