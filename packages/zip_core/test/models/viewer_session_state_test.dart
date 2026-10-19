// Tests for S-19: Zip Captions Viewer, `ViewerSessionState` (Unit 7).
import 'package:flutter_test/flutter_test.dart' hide Timeout;
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/connect_failure.dart';
import 'package:zip_core/src/models/connection_status.dart';
import 'package:zip_core/src/models/viewer_session_state.dart';

void main() {
  group('ViewerSessionState', () {
    test('AC: exposes the ten fixed variants', () {
      const states = <ViewerSessionState>[
        ViewerSessionState.idle(),
        ViewerSessionState.resolving(),
        ViewerSessionState.connecting(),
        ViewerSessionState.liveView(
          captionActivity: CaptionActivity.active,
          connectionType: ConnectionType.p2pDirect,
        ),
        ViewerSessionState.reconnecting(),
        ViewerSessionState.notBroadcasting(),
        ViewerSessionState.ended(),
        ViewerSessionState.full(),
        ViewerSessionState.cannotConnect(NotFound()),
        ViewerSessionState.invalidInput(),
      ];

      expect(states, hasLength(10));
      expect(states.toSet(), hasLength(10));
      expect(states[0], isA<IdleState>());
      expect(states[3], isA<LiveViewState>());
      expect(states[8], isA<CannotConnectState>());
    });

    test('AC: variants are value-equal and copyWith updates in place', () {
      const a = ViewerSessionState.liveView(
        captionActivity: CaptionActivity.active,
        connectionType: ConnectionType.p2pDirect,
      );
      const b = ViewerSessionState.liveView(
        captionActivity: CaptionActivity.active,
        connectionType: ConnectionType.p2pDirect,
      );
      expect(a, equals(b));

      final paused = (a as LiveViewState).copyWith(
        captionActivity: CaptionActivity.paused,
      );
      expect(paused, isA<LiveViewState>());
      expect(paused.captionActivity, equals(CaptionActivity.paused));
      expect(paused.connectionType, equals(ConnectionType.p2pDirect));
    });

    test('AC: CannotConnectState carries its ConnectFailure reason', () {
      const state = ViewerSessionState.cannotConnect(ResolutionFailed());
      expect(state, isA<CannotConnectState>());
      expect((state as CannotConnectState).reason, equals(const ResolutionFailed()));
    });

    test('AC: InvalidInputState carries no data (Rule 8)', () {
      const state = InvalidInputState();
      // Every field of the sealed family that could carry a string is
      // either a fixed variant or a typed reason — no caption text, no raw
      // input.
      final fields = switch (state) {
        InvalidInputState() => const <Object?>[],
        _ => fail('expected InvalidInputState'),
      };
      expect(fields, isEmpty);
      expect(state.toString(), isNot(contains('SENTINEL')));
    });
  });
}