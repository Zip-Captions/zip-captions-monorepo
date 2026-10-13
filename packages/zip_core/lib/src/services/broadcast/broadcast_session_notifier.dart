import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:uuid/uuid.dart';
import 'package:zip_core/src/constants/broadcast_limits_default.dart';
import 'package:zip_core/src/models/auth_state.dart';
import 'package:zip_core/src/models/broadcast_failure.dart';
import 'package:zip_core/src/models/broadcast_link.dart';
import 'package:zip_core/src/models/broadcast_settings.dart';
import 'package:zip_core/src/models/broadcast_transport_context.dart';
import 'package:zip_core/src/models/broadcaster_session_state.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/live_broadcast.dart';
import 'package:zip_core/src/models/viewer_connection_info.dart';
import 'package:zip_core/src/providers/auth_notifier.dart';
import 'package:zip_core/src/providers/broadcast_identity_repository_provider.dart';
import 'package:zip_core/src/providers/broadcast_transport_factory_provider.dart';
import 'package:zip_core/src/providers/caption_output_target_registry_provider.dart';
import 'package:zip_core/src/providers/captioning_starter_provider.dart';
import 'package:zip_core/src/providers/ice_server_provider_provider.dart';
import 'package:zip_core/src/providers/signaling_service_provider.dart';
import 'package:zip_core/src/services/broadcast/broadcast_settings_notifier.dart';
import 'package:zip_core/src/services/broadcast/session_resources.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';
import 'package:zip_core/src/services/caption/remote_broadcast_target.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';
import 'package:zip_core/src/services/webrtc/viewer_admission.dart';

part 'broadcast_session_notifier.g.dart';

const _uuid = Uuid();

/// The broadcaster's own session orchestration (fixed shape, Application
/// Design; behavior designed in `business-logic-model.md`).
///
/// Explicit calls into already-shipped services (Units 2–5) — no reactive
/// watcher triggers a side effect (the project Riverpod convention).
/// Failure handling implements `business-rules.md` Rule 2's table exactly,
/// including its deliberate per-step unwind choices (e.g. step 6's target
/// create/register/prime failure is documented as "local operation;
/// failure = programming error" with no unwind — not an oversight).
@Riverpod(keepAlive: true)
class BroadcastSessionNotifier extends _$BroadcastSessionNotifier {
  static final _log = Logger('zip_core.BroadcastSessionNotifier');

  SessionResources? _resources;

  @override
  BroadcasterSessionState build() => const BroadcasterSessionState.offline();

  /// Starts a new broadcast (F-6.2, `business-rules.md` Rules 1–4).
  ///
  /// A no-op unless the current state is [OfflineState] or
  /// [BroadcastFailedState] (Rule 1). Sets [StartingState] synchronously,
  /// before any `await`, so the entire mid-`goLive()` window is observable
  /// by the Rule 9 sign-out guard.
  Future<void> goLive() async {
    if (state is! OfflineState && state is! BroadcastFailedState) return;

    final settings = ref.read(broadcastSettingsNotifierProvider);
    if (BroadcastSettings.validateSessionName(settings.sessionName) != null) {
      return;
    }

    state = const BroadcasterSessionState.starting();

    // F2-1 — sign-in check.
    if (ref.read(authNotifierProvider) is! SignedInState) {
      state = const BroadcasterSessionState.failed(
        BroadcastFailure.signedOut,
      );
      return;
    }

    // F2-2 — identity.
    final broadcastId_ = await _step(
      () => ref.read(broadcastIdentityRepositoryProvider).getOrCreateMine(),
      BroadcastFailure.identityUnavailable,
    );
    if (broadcastId_ == null) return;
    final broadcastId = broadcastId_;

    // F2-3 — session + ICE.
    final sessionId = _uuid.v4();
    final iceServers = await _step(
      () => ref.read(iceServerProviderProvider).iceServersFor(sessionId),
      BroadcastFailure.relayUnavailable,
    );
    if (iceServers == null) return;

    // F2-5 — transport (F2-4 has no independent action left — Unit 3.1/
    // Unit 5 already subscribe to join requests inside `transport.start()`).
    // No unwind on this step's own failure (Rule 2's table: nothing else
    // has been created yet).
    final signalingService = ref.read(signalingServiceProvider);
    final admission = ViewerAdmission(defaultBroadcastLimits);
    final transport = ref.read(broadcastTransportFactoryProvider)();
    try {
      await transport.start(
        BroadcastTransportContext(
          sessionId: sessionId,
          broadcastId: broadcastId,
          signalingService: signalingService,
          iceServers: iceServers,
          admission: admission,
        ),
      );
    } on Object {
      state = const BroadcasterSessionState.failed(BroadcastFailure.unknown);
      return;
    }

    // F2-6 — target: create, register, then prime (Rule 4 / Q4).
    //
    // **Correction (CodeRabbit PR #34 review)**: `business-rules.md`
    // Rule 2's table literally says this step has no unwind ("local
    // operation; failure = programming error"), but `transport.start()`
    // already succeeded by this point — leaving it running on failure
    // would violate the "no session resources in BroadcastFailedState"
    // invariant every other failure path (and Rule 1's retry gate,
    // Rule 9's sign-out gate) depends on. `business-rules.md` is being
    // corrected to match this real unwind, not the other way around.
    final captioningStarter = ref.read(captioningStarterProvider);
    final registry = ref.read(captionOutputTargetRegistryProvider);
    RemoteBroadcastTarget? target;
    try {
      target = RemoteBroadcastTarget(transport);
      registry.add(target);
      target.primeActivity(captioningStarter.currentActivity);
    } on Object {
      await _unwindTransport(
        target: target,
        transport: transport,
        registry: registry,
      );
      state = const BroadcasterSessionState.failed(BroadcastFailure.unknown);
      return;
    }

    // F2-7 — publish live. Unwind: registry.remove(target) -> transport.stop()
    // (the StatusChannel itself was never opened, so it's not part of this
    // unwind — Rule 2's general unwind description).
    final statusChannel = signalingService.statusChannel(broadcastId);
    try {
      await statusChannel.publishLive(
        sessionId: sessionId,
        sessionName: settings.sessionName,
      );
    } on Object {
      await _unwindTransport(
        target: target,
        transport: transport,
        registry: registry,
      );
      state = const BroadcasterSessionState.failed(
        BroadcastFailure.signalingUnavailable,
      );
      return;
    }

    // F2-8 — optional coupled start (Rule 3): best-effort, never fails
    // goLive().
    if (settings.autoStartCaptioning &&
        captioningStarter.currentActivity == CaptionActivity.inactive) {
      try {
        await captioningStarter.start();
      } on Object catch (e) {
        _log.warning('captioningStarter.start() failed: ${e.runtimeType}');
      }
    }

    // F2-9 — state -> LiveState, start the two owned subscriptions.
    final broadcast = LiveBroadcast(
      broadcastId: broadcastId,
      url: BroadcastLink.toUrl(broadcastId),
      sessionId: sessionId,
      sessionName: settings.sessionName,
      captionActivity: captioningStarter.currentActivity,
      viewers: const [],
      maxViewers: defaultBroadcastLimits.maxViewers,
      startedAt: DateTime.now(),
    );

    // Cancelled in `SessionResources.disposeAll` (Rule 2/5's unwind/
    // teardown), not within this method — the lint can't trace that.
    // ignore: cancel_subscriptions
    final activitySub = target.activityChanges.listen(_onActivityChanged);
    // Cancelled in `SessionResources.disposeAll` (Rule 2/5's unwind/
    // teardown), not within this method — the lint can't trace that.
    // ignore: cancel_subscriptions
    final viewersSub = transport.viewers.listen(_onViewersChanged);

    _resources = SessionResources(
      statusChannel: statusChannel,
      admission: admission,
      transport: transport,
      target: target,
      registry: registry,
      activitySub: activitySub,
      viewersSub: viewersSub,
    );
    state = BroadcasterSessionState.live(broadcast);
  }

  /// Ends the current broadcast (F-6.6, `business-rules.md` Rule 5).
  ///
  /// A no-op unless the current state is [LiveState] (idempotent from
  /// [EndingState]; a safe no-op from every other state).
  Future<void> endBroadcast() async {
    if (state is EndingState) return;
    if (state is! LiveState) return;

    state = const BroadcasterSessionState.ending();

    final resources = _resources;
    if (resources != null) {
      resources.transport.sendToAll(const Ended());
      try {
        await resources.transport.sendBroadcastEnded();
      } on Object catch (e) {
        _log.warning('sendBroadcastEnded() failed: ${e.runtimeType}');
      }
      await resources.disposeAll(_log);
      _resources = null;
    }

    state = const BroadcasterSessionState.offline();
  }

  /// Runs [action], mapping any thrown exception to [onFailure] and
  /// returning `null` (the caller treats a `null` result as "already
  /// handled, stop"). No resources exist yet at this point in `goLive()`'s
  /// sequence, so no unwind call is needed for F2-2/F2-3's own failures
  /// (Rule 2's table).
  Future<T?> _step<T>(
    Future<T> Function() action,
    BroadcastFailure onFailure,
  ) async {
    try {
      return await action();
    } on Object {
      state = BroadcasterSessionState.failed(onFailure);
      return null;
    }
  }

  /// Unwinds a partially-started `goLive()` attempt (F2-6/F2-7 failure
  /// paths): removes [target] from [registry] if it was registered, then
  /// stops [transport] — each step individually caught and logged, never
  /// allowed to escape (CodeRabbit PR #34 review: an uncaught
  /// `transport.stop()` here would leave the notifier stuck in
  /// `StartingState`, where both `goLive()`'s retry gate and Rule 9's
  /// sign-out guard refuse — the same catch-and-continue discipline as
  /// `SessionResources.disposeAll`).
  Future<void> _unwindTransport({
    required RemoteBroadcastTarget? target,
    required BroadcastTransport transport,
    required CaptionOutputTargetRegistry registry,
  }) async {
    if (target != null) {
      try {
        registry.remove(target);
      } on Object catch (e) {
        _log.warning('registry.remove(target) failed: ${e.runtimeType}');
      }
    }
    try {
      await transport.stop();
    } on Object catch (e) {
      _log.warning('transport.stop() failed: ${e.runtimeType}');
    }
  }

  void _onActivityChanged(CaptionActivity activity) {
    final current = state;
    if (current is! LiveState) return;
    state = BroadcasterSessionState.live(
      current.broadcast.copyWith(captionActivity: activity),
    );
  }

  void _onViewersChanged(List<ViewerConnectionInfo> viewers) {
    final current = state;
    if (current is! LiveState) return;
    state = BroadcasterSessionState.live(
      current.broadcast.copyWith(viewers: viewers),
    );
  }
}
