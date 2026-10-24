// Tests for Unit 8.1 (S-21): the availability rule (FD §5 POP-7;
// FD frontend-components §6; BR-PIP-12/13). N-09.
//
// A table test, not a generated one: the domain is finite (7 statuses x 5
// recording states x 2 engine values = 70 cells) and every cell is asserted
// against the rule the spec states, so no invented value can be mistaken for a
// decision.
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/output/overlay/display_info.dart';
import 'package:zip_core/src/output/overlay/external_display_status.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/output/overlay/pop_out_availability.dart';

DisplayInfo _display() => const DisplayInfo(
  id: 'primary',
  label: 'primary',
  bounds: Rect.fromLTWH(0, 0, 1920, 1080),
  scaleFactor: 1,
  isPrimary: true,
);

List<ExternalDisplayStatus> _allStatuses() => <ExternalDisplayStatus>[
  const Unsupported(),
  const NoDisplays(),
  const Off(),
  const Opening(),
  const Open(activity: OverlayActivity.live, displayId: 'primary'),
  const WaitingForDisplay(displayId: 'primary'),
  const Failed(reason: 'create_failed'),
];

List<RecordingState> _allRecordingStates() => <RecordingState>[
  const RecordingState.idle(),
  const RecordingState.recording(sessionId: 'a'),
  const RecordingState.paused(sessionId: 'a'),
  const RecordingState.reconnecting(sessionId: 'a'),
  const RecordingState.stopped(sessionId: 'a'),
];

String _describe(ExternalDisplayStatus status, RecordingState recording) =>
    '${status.runtimeType} / ${recording.runtimeType}';

void main() {
  test(
    'the domain has the seven statuses and five recording states expected',
    () {
      expect(_allStatuses().map((s) => s.runtimeType).toSet(), hasLength(7));
      expect(
        _allRecordingStates().map((s) => s.runtimeType).toSet(),
        hasLength(5),
      );
      expect(_display().isPrimary, isTrue);
    },
  );

  group('the 7 x 5 x 2 matrix', () {
    for (final status in _allStatuses()) {
      for (final recording in _allRecordingStates()) {
        for (final engineAvailable in const [true, false]) {
          test(
            '${_describe(status, recording)} engine=$engineAvailable',
            () {
              final result = popOutAvailability(
                status: status,
                recording: recording,
                engineAvailable: engineAvailable,
              );
              final sessionActive = popOutSessionActive(recording);

              final supported = status is! Unsupported;
              expect(result.visible, supported);
              expect(
                result.enabled,
                supported && sessionActive && engineAvailable,
              );

              if (!result.visible || result.enabled) {
                expect(result.reason, isNull);
              } else if (!engineAvailable) {
                expect(result.reason, PopOutUnavailableReason.noEngine);
              } else {
                expect(result.reason, PopOutUnavailableReason.noSession);
              }
            },
          );
        }
      }
    }
  });

  group('the concrete rules the matrix encodes', () {
    test('unsupported renders nothing whatever the session or engine is', () {
      for (final recording in _allRecordingStates()) {
        for (final engineAvailable in const [true, false]) {
          final result = popOutAvailability(
            status: const Unsupported(),
            recording: recording,
            engineAvailable: engineAvailable,
          );

          expect(result.visible, isFalse);
          expect(result.enabled, isFalse);
          expect(result.reason, isNull);
        }
      }
    });

    test(
      'a stopped session is not active, even though it carries the mixin',
      () {
        const stopped = RecordingState.stopped(sessionId: 'a');

        expect(stopped, isA<ActiveSessionState>());
        expect(popOutSessionActive(stopped), isFalse);
      },
    );

    test('the engine reason wins when both reasons apply', () {
      final result = popOutAvailability(
        status: const Off(),
        recording: const RecordingState.idle(),
        engineAvailable: false,
      );

      expect(result.reason, PopOutUnavailableReason.noEngine);
    });

    test('availability is value-equal, so a rebuild can compare cheaply', () {
      const a = PopOutAvailability(visible: true, enabled: false);
      const b = PopOutAvailability(
        visible: true,
        enabled: false,
      );

      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });
}
