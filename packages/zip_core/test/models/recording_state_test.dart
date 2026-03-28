import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/recording_state.dart';

void main() {
  group('RecordingState', () {
    test('idle creates an IdleState', () {
      const state = RecordingState.idle();
      expect(state, isA<IdleState>());
    });

    test('recording creates a RecordingActiveState', () {
      const state = RecordingState.recording();
      expect(state, isA<RecordingActiveState>());
    });

    test('paused creates a PausedState', () {
      const state = RecordingState.paused();
      expect(state, isA<PausedState>());
    });

    test('stopped creates a StoppedState', () {
      const state = RecordingState.stopped();
      expect(state, isA<StoppedState>());
    });

    test('pattern matching covers all variants', () {
      const states = <RecordingState>[
        RecordingState.idle(),
        RecordingState.recording(),
        RecordingState.paused(),
        RecordingState.stopped(),
      ];

      for (final state in states) {
        // Exhaustive switch — compiler enforces all variants handled.
        final label = switch (state) {
          IdleState() => 'idle',
          RecordingActiveState() => 'recording',
          PausedState() => 'paused',
          StoppedState() => 'stopped',
        };
        expect(label, isNotEmpty);
      }
    });
  });
}
