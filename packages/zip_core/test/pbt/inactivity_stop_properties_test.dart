import 'dart:async';
import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:zip_core/src/constants/speech_inactivity.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_error.dart';
import 'package:zip_core/src/models/recording_error_factories.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/session_stop_reason_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_stt_session_manager.dart';
import '../helpers/mock_wake_lock_service.dart';
import '../helpers/pbt.dart' as pbt;

// TP-32 (Unit 10 Amendment 05, BR-U10-51): a stateful property over random
// sequences of results, pauses, resumes, stops and engine errors at random
// gaps, run under fake_async against a small model of the rule. The shim runs
// fixed seeds 0 to 99 and prints no seed; a failure message carries the op
// list so it can be reproduced.

enum _Op {
  interim,
  finalResult,
  pause,
  resume,
  userStop,
  errorRecovers,
  errorFails,
}

/// The reference model: non-paused time since the last reset, and how the
/// session ended, if it did.
class _Model {
  int idleMs = 0;
  bool paused = false;
  bool attemptedRestart = false;
  String? ended; // 'inactivity' | 'user' | 'error'

  int get remainingMs => defaultSpeechInactivityTimeout.inMilliseconds - idleMs;

  void elapse(int ms) {
    if (ended != null || paused) return;
    if (idleMs + ms >= defaultSpeechInactivityTimeout.inMilliseconds) {
      ended = 'inactivity';
    } else {
      idleMs += ms;
    }
  }

  void apply(_Op op) {
    if (ended != null) return;
    switch (op) {
      case _Op.interim:
      case _Op.finalResult:
        if (!paused) idleMs = 0;
      case _Op.pause:
        if (!paused) paused = true;
      case _Op.resume:
        if (paused) {
          paused = false;
          idleMs = 0;
        }
      case _Op.userStop:
        ended = 'user';
      case _Op.errorRecovers:
        if (paused) return;
        if (attemptedRestart) {
          ended = 'error';
        } else {
          attemptedRestart = true;
          idleMs = 0;
        }
      case _Op.errorFails:
        if (paused) return;
        attemptedRestart = true;
        ended = 'error';
    }
  }
}

class _Step {
  _Step(Random r)
    : op = _Op.values[r.nextInt(_Op.values.length)],
      gapKind = r.nextInt(5),
      gapSeed = r.nextInt(1 << 30);

  final _Op op;
  final int gapKind;
  final int gapSeed;

  /// Gaps that land just before, on and just after the deadline are included
  /// so the stop is checked for exactness, not only roughly.
  int gapMs(_Model m) {
    final r = Random(gapSeed);
    final span = defaultSpeechInactivityTimeout.inMilliseconds;
    switch (gapKind) {
      case 0:
        return r.nextInt(20000);
      case 1:
        return m.paused ? r.nextInt(2 * span) : max(0, m.remainingMs - 1);
      case 2:
        return m.paused ? r.nextInt(2 * span) : max(0, m.remainingMs);
      case 3:
        return m.paused ? r.nextInt(2 * span) : m.remainingMs + 1;
      default:
        return r.nextInt(2 * span);
    }
  }
}

List<_Step> _scenario(Random r) =>
    List.generate(5 + r.nextInt(26), (_) => _Step(r));

SttResult _result({required bool isFinal}) => SttResult(
  text: 'spoken words',
  isFinal: isFinal,
  confidence: 1,
  timestamp: DateTime.utc(2026, 10, 27),
  sourceId: 'default',
);

void main() {
  group('TP-32: the inactivity stop', () {
    const pbt.Glados<List<_Step>>(_scenario).test(
      'stops exactly when no result arrived for the timeout of non-paused '
      'time, at most once, with one finalise, and never after another stop',
      (steps) {
        fakeAsync((async) {
          final captionBus = CaptionBus();
          final events = <CaptionEvent>[];
          captionBus.stream.listen(events.add);
          final manager = MockSttSessionManager();
          final wakeLock = MockWakeLockService();
          late void Function(SttResult) emitResult;
          late void Function(RecordingError) emitError;
          var recovers = true;
          var finalizeCalls = 0;

          when(
            () => manager.initialize(
              engineId: any(named: 'engineId'),
              localeId: any(named: 'localeId'),
              onResult: any(named: 'onResult'),
              onError: any(named: 'onError'),
            ),
          ).thenAnswer((inv) async {
            emitResult =
                inv.namedArguments[#onResult] as void Function(SttResult);
            emitError =
                inv.namedArguments[#onError] as void Function(RecordingError);
            return true;
          });
          when(manager.startListening).thenAnswer((_) async => true);
          when(manager.pause).thenAnswer((_) async => true);
          when(manager.resume).thenAnswer((_) async => true);
          when(manager.stop).thenAnswer((_) async {});
          when(
            () => manager.handleEngineError(any()),
          ).thenAnswer((_) async => recovers);
          when(wakeLock.acquire).thenAnswer((_) async {});
          when(wakeLock.release).thenAnswer((_) async {});
          when(wakeLock.onPause).thenAnswer((_) async {});
          when(() => wakeLock.settings).thenReturn(const WakeLockSettings());

          final container = ProviderContainer(
            overrides: [
              captionBusProvider.overrideWithValue(captionBus),
              sttSessionManagerProvider.overrideWithValue(manager),
              wakeLockServiceProvider.overrideWithValue(wakeLock),
              sttEngineProvider.overrideWithValue(MockSttEngine()),
              resolvedLocaleIdProvider.overrideWithValue('en-US'),
            ],
          );
          container.read(sessionStopCallbackProvider).callback = () async {
            finalizeCalls++;
          };
          final notifier = container.read(
            recordingStateNotifierProvider.notifier,
          );
          RecordingState current() =>
              container.read(recordingStateNotifierProvider);
          final why = StringBuffer('ops:');

          void settle([int ms = 0]) {
            async
              ..flushMicrotasks()
              ..elapse(Duration(milliseconds: ms))
              ..flushMicrotasks();
          }

          unawaited(notifier.start());
          settle();
          expect(current(), isA<RecordingActiveState>());

          final model = _Model();
          for (final step in steps) {
            final gap = step.gapMs(model);
            why.write(' +${gap}ms ${step.op.name};');
            model.elapse(gap);
            settle(gap);

            // Exactness: stopped by inactivity now iff the model says so.
            expect(
              current() is StoppedState,
              model.ended != null,
              reason: '$why',
            );

            switch (step.op) {
              case _Op.interim:
                emitResult(_result(isFinal: false));
              case _Op.finalResult:
                emitResult(_result(isFinal: true));
              case _Op.pause:
                unawaited(notifier.pause());
              case _Op.resume:
                unawaited(notifier.resume());
              case _Op.userStop:
                unawaited(notifier.stop());
              case _Op.errorRecovers:
                recovers = true;
                emitError(RecordingErrorFactories.engineStartFailed());
              case _Op.errorFails:
                recovers = false;
                emitError(RecordingErrorFactories.engineStartFailed());
            }
            model.apply(step.op);
            settle();
            expect(
              current() is StoppedState,
              model.ended != null,
              reason: '$why (after ${step.op.name})',
            );
          }

          // Drain: a running session must now stop at its deadline, a stopped
          // one must stay stopped.
          settle(defaultSpeechInactivityTimeout.inMilliseconds * 2);
          if (model.ended == null && !model.paused) model.ended = 'inactivity';
          final stopped = model.ended != null;
          expect(current() is StoppedState, stopped, reason: '$why (drain)');

          final stoppedEvents = events
              .whereType<SessionStateEvent>()
              .where((e) => e.state is StoppedState)
              .length;
          expect(finalizeCalls, stopped ? 1 : 0, reason: '$why');
          expect(stoppedEvents, stopped ? 1 : 0, reason: '$why');
          verify(wakeLock.release).called(stopped ? 1 : 0);
          expect(
            container.read(sessionStopReasonNotifierProvider),
            model.ended == 'inactivity' ? SessionStopReason.inactivity : null,
            reason: '$why',
          );
          if (model.ended == 'inactivity') {
            expect(notifier.lastError, isNull, reason: '$why');
          }

          container.dispose();
          captionBus.dispose();
        });
      },
    );
  });
}
