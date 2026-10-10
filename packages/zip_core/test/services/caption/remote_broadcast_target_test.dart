// Tests for S-14, S-16, S-18: `RemoteBroadcastTarget` (WebRTC Transport,
// Remote Broadcast Output Target, Viewer Capacity) — forwards caption
// events over a mocked `BroadcastTransport`, maps recording states to the
// caption activity reported to viewers, and snapshots that activity for
// late-joining viewers.
//
// The mock backs `viewerJoined` with a real broadcast `StreamController`
// and overrides the getter directly (not via `when`/`thenAnswer`): the
// target subscribes to it in its constructor, before any stubbing is
// possible — same pattern as `test/helpers/mock_transcript_repository.dart`.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/caption_wire_message.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/caption/remote_broadcast_target.dart';
import 'package:zip_core/src/services/webrtc/broadcast_transport.dart';

/// Mocktail mock for [BroadcastTransport].
class MockBroadcastTransport extends Mock implements BroadcastTransport {
  final _joinedController = StreamController<String>.broadcast();

  @override
  Stream<String> get viewerJoined => _joinedController.stream;

  /// Emits [peerId] on [viewerJoined].
  void emitViewerJoined(String peerId) => _joinedController.add(peerId);

  /// Closes the internal stream controller.
  void disposeController() => _joinedController.close();
}

void main() {
  late MockBroadcastTransport transport;
  late RemoteBroadcastTarget target;

  SttResult makeSttResult([String text = 'hello']) => SttResult(
    text: text,
    isFinal: true,
    confidence: 1,
    timestamp: DateTime.utc(2026),
    sourceId: 'default',
  );

  setUpAll(() {
    // `any()` on the custom wire-message parameter needs a fallback.
    registerFallbackValue(
      const CaptionActivityChanged(activity: CaptionActivity.inactive),
    );
  });

  setUp(() {
    transport = MockBroadcastTransport();
    target = RemoteBroadcastTarget(transport);
  });

  tearDown(() {
    target.dispose();
    transport.disposeController();
  });

  group('RemoteBroadcastTarget', () {
    test('targetId is remote_broadcast', () {
      expect(target.targetId, 'remote_broadcast');
    });

    test(
      'currentActivity defaults to inactive before any SessionStateEvent',
      () {
        expect(target.currentActivity, CaptionActivity.inactive);
      },
    );

    test('SttResultEvent is forwarded to all viewers via sendToAll', () {
      final result = makeSttResult();

      target.onCaptionEvent(SttResultEvent(result));

      verify(() => transport.sendToAll(Caption(result: result))).called(1);
    });

    group('SessionStateEvent activity mapping', () {
      // Every case primes the target with a state that maps to a different
      // activity, so the event under test always takes the change branch
      // (the no-op branch is covered by a dedicated test below).
      final cases = <(String, RecordingState, RecordingState, CaptionActivity)>[
        (
          'RecordingActiveState maps to active',
          const PausedState(sessionId: 's1'),
          const RecordingActiveState(sessionId: 's1'),
          CaptionActivity.active,
        ),
        (
          'PausedState maps to paused',
          const RecordingActiveState(sessionId: 's1'),
          const PausedState(sessionId: 's1'),
          CaptionActivity.paused,
        ),
        (
          'ReconnectingState maps to paused',
          const RecordingActiveState(sessionId: 's1'),
          const ReconnectingState(sessionId: 's1'),
          CaptionActivity.paused,
        ),
        (
          'IdleState maps to inactive',
          const RecordingActiveState(sessionId: 's1'),
          const IdleState(),
          CaptionActivity.inactive,
        ),
        (
          'StoppedState maps to inactive',
          const RecordingActiveState(sessionId: 's1'),
          const StoppedState(sessionId: 's1'),
          CaptionActivity.inactive,
        ),
      ];

      for (final (description, prime, next, expected) in cases) {
        test(description, () async {
          final activities = <CaptionActivity>[];
          target.activityChanges.listen(activities.add);

          target
            ..onCaptionEvent(SessionStateEvent(prime))
            ..onCaptionEvent(SessionStateEvent(next));
          await Future<void>.delayed(Duration.zero);

          expect(target.currentActivity, expected);
          verify(
            () => transport.sendToAll(
              CaptionActivityChanged(activity: expected),
            ),
          ).called(1);
          // One emission for the prime state, one for the event under test.
          expect(activities, hasLength(2));
          expect(activities.last, expected);
        });
      }

      test('event mapping to the current activity is a no-op', () async {
        final activities = <CaptionActivity>[];
        target.activityChanges.listen(activities.add);

        target
          ..onCaptionEvent(
            const SessionStateEvent(PausedState(sessionId: 's1')),
          )
          ..onCaptionEvent(
            const SessionStateEvent(ReconnectingState(sessionId: 's1')),
          );
        await Future<void>.delayed(Duration.zero);

        // ReconnectingState also maps to paused: no second send and no
        // second emission.
        expect(target.currentActivity, CaptionActivity.paused);
        verify(
          () => transport.sendToAll(
            const CaptionActivityChanged(activity: CaptionActivity.paused),
          ),
        ).called(1);
        expect(activities, [CaptionActivity.paused]);
      });
    });

    group('viewerJoined', () {
      test(
        'sends the current activity snapshot, not a construction-time one',
        () async {
          // Change the activity before the join fires, so a snapshot taken
          // at construction time (inactive) would fail this verification.
          target.onCaptionEvent(
            const SessionStateEvent(RecordingActiveState(sessionId: 's1')),
          );
          await Future<void>.delayed(Duration.zero);

          transport.emitViewerJoined('peer-1');
          await Future<void>.delayed(Duration.zero);

          verify(
            () => transport.sendTo(
              'peer-1',
              const CaptionActivityChanged(activity: CaptionActivity.active),
            ),
          ).called(1);
        },
      );

      test('dispose stops the activity snapshot for joining viewers', () async {
        target.dispose();

        transport.emitViewerJoined('peer-1');
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => transport.sendTo(any(), any()));
      });
    });
  });
}
