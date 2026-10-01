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
    _channel.onPresenceSync((_) => _emitCurrentStatus());
  }

  final RealtimeChannel _channel;
  final _statusController = StreamController<BroadcastStatus>.broadcast();
  Completer<void>? _subscribed;

  Future<void> _ensureSubscribed() {
    final existing = _subscribed;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _subscribed = completer;
    _channel.subscribe((status, error) {
      if (completer.isCompleted) return;
      switch (status) {
        case RealtimeSubscribeStatus.subscribed:
          completer.complete();
        case RealtimeSubscribeStatus.channelError:
          completer.completeError(
            BroadcastAuthorizationException(
              error?.toString() ?? 'status channel subscription rejected',
            ),
          );
        case RealtimeSubscribeStatus.timedOut:
        case RealtimeSubscribeStatus.closed:
          completer.completeError(
            StateError('status channel subscription $status'),
          );
      }
    });
    return completer.future;
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
    await _channel.unsubscribe();
    await _statusController.close();
  }
}
