import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/recording_state.dart';

void main() {
  group('RecordingState', () {
    test('idle creates an IdleState', () {
      const state = RecordingState.idle();
      expect(state, isA<IdleState>());
    });

    test('recording creates a RecordingActiveState', () {
      const state = RecordingState.recording(sessionId: 'abc');
      expect(state, isA<RecordingActiveState>());
    });

    test('paused creates a PausedState', () {
      const state = RecordingState.paused(sessionId: 'abc');
      expect(state, isA<PausedState>());
    });

    test('stopped creates a StoppedState', () {
      const state = RecordingState.stopped(sessionId: 'abc');
      expect(state, isA<StoppedState>());
    });

    test('reconnecting creates a ReconnectingState', () {
      const state = RecordingState.reconnecting(sessionId: 'abc');
      expect(state, isA<ReconnectingState>());
    });

    test('pattern matching covers all variants', () {
      const states = <RecordingState>[
        RecordingState.idle(),
        RecordingState.recording(sessionId: 'test'),
        RecordingState.paused(sessionId: 'test'),
        RecordingState.reconnecting(sessionId: 'test'),
        RecordingState.stopped(sessionId: 'test'),
      ];

      for (final state in states) {
        final label = switch (state) {
          IdleState() => 'idle',
          RecordingActiveState() => 'recording',
          PausedState() => 'paused',
          ReconnectingState() => 'reconnecting',
          StoppedState() => 'stopped',
        };
        expect(label, isNotEmpty);
      }
    });
  });

  group('ActiveSessionState mixin', () {
    test('RecordingActiveState implements ActiveSessionState', () {
      const state = RecordingState.recording(sessionId: 'session-1');
      expect(state, isA<ActiveSessionState>());
      expect((state as ActiveSessionState).sessionId, 'session-1');
    });

    test('PausedState implements ActiveSessionState', () {
      const state = RecordingState.paused(sessionId: 'session-2');
      expect(state, isA<ActiveSessionState>());
      expect((state as ActiveSessionState).sessionId, 'session-2');
    });

    test('StoppedState implements ActiveSessionState', () {
      const state = RecordingState.stopped(sessionId: 'session-3');
      expect(state, isA<ActiveSessionState>());
      expect((state as ActiveSessionState).sessionId, 'session-3');
    });

    test('ReconnectingState implements ActiveSessionState', () {
      const state = RecordingState.reconnecting(sessionId: 'session-r');
      expect(state, isA<ActiveSessionState>());
      expect((state as ActiveSessionState).sessionId, 'session-r');
    });

    test('ReconnectingState preserves currentSegment', () {
      const state = RecordingState.reconnecting(
        sessionId: 's',
        currentSegment: 'partial text',
      );
      expect((state as ReconnectingState).currentSegment, 'partial text');
    });

    test('IdleState does not implement ActiveSessionState', () {
      const state = RecordingState.idle();
      expect(state, isNot(isA<ActiveSessionState>()));
    });

    test('currentSegment defaults to empty string', () {
      const state = RecordingState.recording(sessionId: 's');
      expect((state as RecordingActiveState).currentSegment, isEmpty);
    });

    test('currentSegment can be set', () {
      const state = RecordingState.recording(
        sessionId: 's',
        currentSegment: 'hello world',
      );
      expect((state as RecordingActiveState).currentSegment, 'hello world');
    });

    test('can access sessionId via concrete type', () {
      const state = RecordingState.recording(sessionId: 'via-mixin');
      expect((state as RecordingActiveState).sessionId, 'via-mixin');
    });
  });
}
