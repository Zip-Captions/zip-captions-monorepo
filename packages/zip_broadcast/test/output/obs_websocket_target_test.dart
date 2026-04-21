import 'dart:async';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obs_websocket/obs_websocket.dart';
import 'package:zip_broadcast/src/models/obs_connection_state.dart';
import 'package:zip_broadcast/src/models/obs_settings.dart';
import 'package:zip_broadcast/src/output/obs/obs_websocket_target.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/stt_result.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testSettings = ObsSettings();

SttResultEvent _interimEvent(String text) => SttResultEvent(
  SttResult(
    text: text,
    isFinal: false,
    confidence: 0.5,
    timestamp: DateTime.utc(2026),
    sourceId: 'default',
  ),
);

SttResultEvent _finalEvent(String text) => SttResultEvent(
  SttResult(
    text: text,
    isFinal: true,
    confidence: 1,
    timestamp: DateTime.utc(2026),
    sourceId: 'default',
  ),
);

/// A connector that always throws on the next call, or hangs indefinitely.
class _FailingConnector {
  final _pending = <Completer<ObsWebSocket>>[];

  Future<ObsWebSocket> call(String url, {String? password}) {
    final c = Completer<ObsWebSocket>();
    _pending.add(c);
    return c.future;
  }

  void failNext([Object? error]) {
    if (_pending.isEmpty) return;
    _pending
        .removeAt(0)
        .completeError(
          error ?? Exception('connect failed'),
          StackTrace.empty,
        );
  }

  int get pendingCount => _pending.length;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('backoff schedule', () {
    test('delays follow 1 s, 2 s, 4 s, 8 s, 16 s, 30 s cap', () {
      fakeAsync((fake) {
        final connector = _FailingConnector();
        final target = ObsWebSocketTarget(connector: connector.call);
        final states = <ObsConnectionState>[];
        target.connectionStateStream.listen(states.add);

        target.connect(_testSettings);
        // Attempt 1 fails
        connector.failNext();
        fake.elapse(Duration.zero);
        expect(states.last, isA<ObsReconnecting>());
        expect(
          (states.last as ObsReconnecting).nextRetryMs,
          equals(1000),
        );

        // 1 s → attempt 2
        fake.elapse(const Duration(milliseconds: 1000));
        connector.failNext();
        fake.elapse(Duration.zero);
        expect((states.last as ObsReconnecting).nextRetryMs, equals(2000));

        // 2 s → attempt 3
        fake.elapse(const Duration(milliseconds: 2000));
        connector.failNext();
        fake.elapse(Duration.zero);
        expect((states.last as ObsReconnecting).nextRetryMs, equals(4000));

        // 4 s → attempt 4
        fake.elapse(const Duration(milliseconds: 4000));
        connector.failNext();
        fake.elapse(Duration.zero);
        expect((states.last as ObsReconnecting).nextRetryMs, equals(8000));

        // 8 s → attempt 5
        fake.elapse(const Duration(milliseconds: 8000));
        connector.failNext();
        fake.elapse(Duration.zero);
        expect((states.last as ObsReconnecting).nextRetryMs, equals(16000));

        // 16 s → attempt 6: capped at 30 s
        fake.elapse(const Duration(milliseconds: 16000));
        connector.failNext();
        fake.elapse(Duration.zero);
        expect(
          (states.last as ObsReconnecting).nextRetryMs,
          equals(30000),
        );

        target.dispose();
      });
    });

    test('emits ObsError after 10-minute timeout', () {
      fakeAsync((fake) {
        final connector = _FailingConnector();
        final target = ObsWebSocketTarget(connector: connector.call);
        final states = <ObsConnectionState>[];
        target.connectionStateStream.listen(states.add);

        target.connect(_testSettings);

        // First failure starts the retry clock.
        connector.failNext();
        fake.elapse(Duration.zero);

        // Advance past the 10-minute window in one shot. The 1 s retry timer
        // fires inside fake.elapse, queuing one connection attempt. No further
        // timers fire because _scheduleReconnect() hasn't run yet. Failing
        // that attempt calls _scheduleReconnect() with now = 11 min, which
        // exceeds the 600 s threshold and emits ObsError.
        fake.elapse(const Duration(minutes: 11));
        connector.failNext();
        fake.elapse(Duration.zero);

        expect(states.last, isA<ObsError>());
        target.dispose();
      });
    });
  });

  group('onCaptionEvent', () {
    test('events when disconnected do not throw', () {
      final connector = _FailingConnector();
      final target = ObsWebSocketTarget(connector: connector.call);
      // No connect() called — stays in ObsDisconnected.
      expect(
        () {
          target
            ..onCaptionEvent(_finalEvent('hello'))
            ..onCaptionEvent(_interimEvent('hel'));
        },
        returnsNormally,
      );
      target.dispose();
    });
  });

  group('disconnect()', () {
    test('suppresses reconnection after first failure', () {
      fakeAsync((fake) {
        final connector = _FailingConnector();
        final target = ObsWebSocketTarget(connector: connector.call);
        final states = <ObsConnectionState>[];
        target.connectionStateStream.listen(states.add);

        target.connect(_testSettings);
        connector.failNext();
        fake.elapse(Duration.zero);
        expect(states.last, isA<ObsReconnecting>());

        // Disconnect before the 1 s timer fires.
        target.disconnect();
        fake.elapse(const Duration(seconds: 2));

        // No new connection attempt was queued.
        expect(connector.pendingCount, equals(0));
        expect(states.last, isA<ObsDisconnected>());
      });
    });

    test('emits ObsDisconnected immediately', () {
      fakeAsync((fake) {
        final connector = _FailingConnector();
        // Connection is pending (not yet failed or succeeded).
        final target = ObsWebSocketTarget(connector: connector.call)
          ..connect(_testSettings)
          ..disconnect();

        expect(target.connectionState, isA<ObsDisconnected>());
      });
    });
  });
}
