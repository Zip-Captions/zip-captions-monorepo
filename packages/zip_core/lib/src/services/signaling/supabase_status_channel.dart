import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zip_core/src/models/broadcast_status.dart';
import 'package:zip_core/src/services/broadcast/broadcast_authorization_exception.dart';
import 'package:zip_core/src/services/signaling/status_channel.dart';

/// Realtime-backed [StatusChannel] for `status:{broadcast_id}` (SR-02 §4).
///
/// Live/offline is conveyed via presence (not broadcast messages):
/// [publishLive] tracks a presence entry carrying `sessionId`/`sessionName`;
/// [publishOffline] untracks it. A watcher reads the channel's current
/// presence state on every sync event — no presence tracked means offline,
/// which is also what presence-expiry produces automatically on an unclean
/// disconnect (Rule 6, `business-rules.md`).
class SupabaseStatusChannel implements StatusChannel {
  /// Creates a [SupabaseStatusChannel] for the broadcast identified by
  /// [broadcastIdValue] (a `BroadcastId.value`).
  SupabaseStatusChannel({
    required SupabaseClient client,
    required String broadcastIdValue,
  })  : _channel = client.channel(
          'status:$broadcastIdValue',
          opts: const RealtimeChannelConfig(private: true),
        ) {
    _channel.onPresenceSync((_) {
      _hasSeenPresenceSync = true;
      if (!_initialPresenceSync.isCompleted) _initialPresenceSync.complete();
      _emitCurrentStatus();
    });
  }

  final RealtimeChannel _channel;
  final _statusController = StreamController<BroadcastStatus>.broadcast();

  /// Completes on the channel's first presence sync — the server-sent
  /// snapshot fires once on join regardless of whether any presence is
  /// tracked yet, and arrives as a separate message from the `subscribed`
  /// callback, not necessarily bundled with it (PR #24 review,
  /// 2026-10-01). `watch()` waits on this before computing its first value
  /// so an already-live topic is never misread as offline from a stale,
  /// pre-sync `presenceState()` snapshot.
  ///
  /// Mutable, not `final`: if the channel errors/closes before the first
  /// sync ever arrives, this is completed with an error so a pending
  /// `watch()` doesn't hang forever — but a *second* CodeRabbit review pass
  /// (PR #24, 2026-10-01) correctly flagged that completing it permanently
  /// would reintroduce the exact stale-failure-cache bug just fixed for
  /// `_subscribeWait` below. [_ensureInitialPresenceSync] replaces it with a
  /// fresh wait after an error, so a later automatic rejoin (and its own
  /// subsequent presence sync) still unblocks future callers.
  Completer<void> _initialPresenceSync = _newSilencedCompleter();
  bool _hasSeenPresenceSync = false;

  /// A [Completer] whose future has an eager no-op error listener attached,
  /// so completing it with an error before any real caller has started
  /// awaiting it (e.g. a channel error that arrives before any [watch()]
  /// call) doesn't surface as an unhandled-exception zone error in tests
  /// and apps — real awaiters (via [_ensureInitialPresenceSync]) still
  /// receive the error through their own independent listen on the same
  /// future.
  static Completer<void> _newSilencedCompleter() {
    final completer = Completer<void>();
    unawaited(completer.future.catchError((_) {}));
    return completer;
  }

  Completer<void>? _subscribeWait;
  bool _subscribeCalled = false;
  RealtimeSubscribeStatus? _lastSubscribeStatus;

  /// Set once the channel reaches a definitively dead state: either
  /// `RealtimeSubscribeStatus.closed` (the realtime client itself will never
  /// rejoin a closed channel — a new channel instance would be needed) or an
  /// explicit [close()] call. Distinguishing this from a merely transient
  /// failure (`channelError`/`timedOut`, which the client *does* retry on
  /// its own) is what makes it safe to hand out a fresh wait after a
  /// failure: a transient one deserves a fresh chance to observe the
  /// client's own recovery, but a terminal one must keep failing forever —
  /// otherwise a fresh wait created right as the channel dies would hang
  /// forever, since nothing will ever complete it (found via a second
  /// CodeRabbit review pass surfacing exactly this race, PR #24,
  /// 2026-10-01).
  bool _terminated = false;

  /// `RealtimeChannel.subscribe()` may only ever be called once per channel
  /// instance (it throws on a second call) — its own timeout/error handling
  /// can automatically rejoin and re-invoke the *same* callback later with
  /// `subscribed`. The original version of this method cached the first
  /// outcome forever, so a transient failure permanently broke every later
  /// call even after the channel silently recovered (PR #24 review,
  /// 2026-10-01). Fixed: `subscribe()` is invoked exactly once; a failed
  /// wait is replaced with a fresh one for later callers instead of being
  /// replayed, so they pick up the channel's eventual recovery — unless
  /// [_terminated], in which case the failure is permanent and must stay
  /// that way.
  Future<void> _ensureSubscribed() {
    if (!_subscribeCalled) {
      _subscribeCalled = true;
      final completer = _newSilencedCompleter();
      _subscribeWait = completer;
      _channel.subscribe(_handleSubscribeStatus);
      return completer.future;
    }
    if (_lastSubscribeStatus == RealtimeSubscribeStatus.subscribed) {
      return Future.value();
    }
    final existing = _subscribeWait;
    if (existing != null && !existing.isCompleted) return existing.future;
    if (_terminated) return existing!.future;
    final completer = _newSilencedCompleter();
    _subscribeWait = completer;
    return completer.future;
  }

  void _handleSubscribeStatus(RealtimeSubscribeStatus status, Object? error) {
    _lastSubscribeStatus = status;
    final completer = _subscribeWait;
    switch (status) {
      case RealtimeSubscribeStatus.subscribed:
        if (completer != null && !completer.isCompleted) {
          completer.complete();
        }
      case RealtimeSubscribeStatus.channelError:
        final authError = BroadcastAuthorizationException(
          error?.toString() ?? 'status channel subscription rejected',
        );
        if (completer != null && !completer.isCompleted) {
          completer.completeError(authError);
        }
        // A channel error can arrive *after* a successful `subscribed` but
        // before any presence sync — without this, `watch()` would wait on
        // `_initialPresenceSync` forever (PR #24 review, second pass,
        // 2026-10-01).
        _failInitialPresenceSyncIfPending(authError);
      case RealtimeSubscribeStatus.timedOut:
        final stateError = StateError('status channel subscription $status');
        if (completer != null && !completer.isCompleted) {
          completer.completeError(stateError);
        }
        _failInitialPresenceSyncIfPending(stateError);
      case RealtimeSubscribeStatus.closed:
        _terminated = true;
        final stateError = StateError('status channel subscription $status');
        if (completer != null && !completer.isCompleted) {
          completer.completeError(stateError);
        }
        _failInitialPresenceSyncIfPending(stateError);
    }
  }

  void _failInitialPresenceSyncIfPending(Object error) {
    if (_hasSeenPresenceSync || _initialPresenceSync.isCompleted) return;
    _initialPresenceSync.completeError(error);
  }

  /// Returns the pending wait for the channel's first presence sync,
  /// replacing it with a fresh one if the previous wait already failed and
  /// the channel isn't [_terminated] — otherwise a channel error before the
  /// first sync would permanently break every later [watch()] call even
  /// after the channel's own automatic rejoin recovers and a sync does
  /// eventually arrive, the same stale-failure-cache bug already fixed once
  /// for [_subscribeWait]. A [_terminated] channel's failure, in contrast,
  /// must never be replaced — nothing will ever complete a fresh wait for a
  /// channel that's permanently dead.
  Future<void> _ensureInitialPresenceSync() {
    if (_hasSeenPresenceSync) return Future.value();
    if (_initialPresenceSync.isCompleted && !_terminated) {
      _initialPresenceSync = _newSilencedCompleter();
    }
    return _initialPresenceSync.future;
  }

  BroadcastStatus _currentStatus() {
    final states = _channel.presenceState();
    if (states.isEmpty || states.first.presences.isEmpty) {
      return const BroadcastStatus.offline();
    }
    final payload = states.first.presences.first.payload;
    return BroadcastStatus.live(
      sessionId: payload['sessionId'] as String? ?? '',
      sessionName: payload['sessionName'] as String? ?? '',
    );
  }

  void _emitCurrentStatus() => _statusController.add(_currentStatus());

  @override
  Future<void> publishLive({
    required String sessionId,
    required String sessionName,
  }) async {
    await _ensureSubscribed();
    await _channel.track({'sessionId': sessionId, 'sessionName': sessionName});
  }

  @override
  Future<void> publishOffline() async {
    await _ensureSubscribed();
    await _channel.untrack();
  }

  @override
  Stream<BroadcastStatus> watch() => Stream<BroadcastStatus>.multi((
        controller,
      ) async {
        try {
          await _ensureSubscribed();
          await _ensureInitialPresenceSync();
        } on Object catch (error, stackTrace) {
          controller.addError(error, stackTrace);
          return;
        }
        final sub = _statusController.stream.listen(
          controller.add,
          onError: controller.addError,
        );
        // The initial value is added directly to `controller`, not routed
        // through `_statusController` — a broadcast stream drops events
        // added before a listener attaches, so it must bypass that
        // entirely rather than racing the `listen` call above.
        controller
          ..onCancel = sub.cancel
          ..add(_currentStatus());
      });

  @override
  Future<void> close() async {
    _terminated = true;
    final closedError = StateError('status channel closed');
    final subscribeWait = _subscribeWait;
    if (subscribeWait != null && !subscribeWait.isCompleted) {
      subscribeWait.completeError(closedError);
    }
    _failInitialPresenceSyncIfPending(closedError);
    await _channel.unsubscribe();
    await _statusController.close();
  }
}
