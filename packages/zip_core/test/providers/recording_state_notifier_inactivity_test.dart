import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
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
import 'package:zip_core/src/providers/speech_inactivity_timeout_provider.dart';
import 'package:zip_core/src/providers/stt_engine_provider.dart';
import 'package:zip_core/src/providers/stt_session_manager_provider.dart';
import 'package:zip_core/src/providers/wake_lock_service_provider.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

import '../helpers/mock_stt_engine.dart';
import '../helpers/mock_stt_session_manager.dart';
import '../helpers/mock_wake_lock_service.dart';

/// Unit 10 Amendment 05 (BR-U10-51): the inactivity stop, as example pins.
/// The stateful property is TP-32 in `test/pbt/inactivity_stop_properties_test`.
const _timeout = Duration(minutes: 5);

class _Harness {
  _Harness({Duration? timeout}) {
    captionBus.stream.listen(events.add);
    when(
      () => manager.initialize(
        engineId: any(named: 'engineId'),
        localeId: any(named: 'localeId'),
        onResult: any(named: 'onResult'),
        onError: any(named: 'onError'),
      ),
    ).thenAnswer((inv) async {
      emitResult = inv.namedArguments[#onResult] as void Function(SttResult);
      emitError = inv.namedArguments[#onError] as void Function(RecordingError);
      return true;
    });
    when(manager.startListening).thenAnswer((_) async => true);
    when(manager.pause).thenAnswer((_) async => true);
    when(manager.resume).thenAnswer((_) async => true);
    when(manager.stop).thenAnswer((_) async {});
    when(() => manager.handleEngineError(any())).thenAnswer((_) async => true);
    when(wakeLock.acquire).thenAnswer((_) async {});
    when(wakeLock.release).thenAnswer((_) async {});
    when(wakeLock.onPause).thenAnswer((_) async {});
    when(() => wakeLock.settings).thenReturn(const WakeLockSettings());

    container = ProviderContainer(
      overrides: [
        captionBusProvider.overrideWithValue(captionBus),
        sttSessionManagerProvider.overrideWithValue(manager),
        wakeLockServiceProvider.overrideWithValue(wakeLock),
        sttEngineProvider.overrideWithValue(MockSttEngine()),
        resolvedLocaleIdProvider.overrideWithValue('en-US'),
        if (timeout != null)
          speechInactivityTimeoutProvider.overrideWithValue(timeout),
      ],
    );
    container.read(sessionStopCallbackProvider).callback = () async {
      finalizeCalls++;
    };
  }

  final captionBus = CaptionBus();
  final manager = MockSttSessionManager();
  final wakeLock = MockWakeLockService();
  final events = <CaptionEvent>[];
  late final ProviderContainer container;
  void Function(SttResult) emitResult = (_) => fail('onResult not captured');
  void Function(RecordingError) emitError = (_) => fail('onError not captured');
  int finalizeCalls = 0;

  RecordingStateNotifier get notifier =>
      container.read(recordingStateNotifierProvider.notifier);
  RecordingState get state => container.read(recordingStateNotifierProvider);
  SessionStopReason? get reason =>
      container.read(sessionStopReasonNotifierProvider);

  int get stoppedEvents => events
      .whereType<SessionStateEvent>()
      .where((e) => e.state is StoppedState)
      .length;

  void dispose() {
    container.dispose();
    captionBus.dispose();
  }
}

void _settle(FakeAsync async, [Duration d = Duration.zero]) {
  async
    ..flushMicrotasks()
    ..elapse(d)
    ..flushMicrotasks();
}

SttResult _result({required bool isFinal}) => SttResult(
  text: 'hello world',
  isFinal: isFinal,
  confidence: 1,
  timestamp: DateTime.utc(2026, 10, 27),
  sourceId: 'default',
);

final SttResult _interim = _result(isFinal: false);
final SttResult _final = _result(isFinal: true);

void main() {
  test('stops exactly at the timeout: one finalise, StoppedState, wake lock '
      'released, lastError null, reason recorded', () {
    fakeAsync((async) {
      final h = _Harness();
      unawaited(h.notifier.start());
      _settle(async);
      expect(h.state, isA<RecordingActiveState>());

      _settle(async, _timeout - const Duration(milliseconds: 1));
      expect(h.state, isA<RecordingActiveState>(), reason: 'not yet');

      _settle(async, const Duration(milliseconds: 1));
      expect(h.state, isA<StoppedState>());
      expect(h.finalizeCalls, 1);
      expect(h.stoppedEvents, 1);
      expect(h.notifier.lastError, isNull);
      expect(h.reason, SessionStopReason.inactivity);
      verify(h.wakeLock.release).called(1);
      verify(h.manager.stop).called(1);

      _settle(async, _timeout * 2);
      expect(h.finalizeCalls, 1, reason: 'never a second stop');
      h.dispose();
    });
  });

  test('an interim result restarts the timer', () {
    fakeAsync((async) {
      final h = _Harness();
      unawaited(h.notifier.start());
      _settle(async, const Duration(minutes: 4));
      h.emitResult(_interim);
      _settle(async, const Duration(minutes: 4, seconds: 59));
      expect(h.state, isA<RecordingActiveState>());
      _settle(async, const Duration(seconds: 1));
      expect(h.state, isA<StoppedState>());
      h.dispose();
    });
  });

  test('a final result restarts the timer', () {
    fakeAsync((async) {
      final h = _Harness();
      unawaited(h.notifier.start());
      _settle(async, const Duration(minutes: 4));
      h.emitResult(_final);
      _settle(async, const Duration(minutes: 4, seconds: 59));
      expect(h.state, isA<RecordingActiveState>());
      _settle(async, const Duration(seconds: 1));
      expect(h.state, isA<StoppedState>());
      h.dispose();
    });
  });

  test('pause cancels the timer and resume restarts it from zero', () {
    fakeAsync((async) {
      final h = _Harness();
      unawaited(h.notifier.start());
      _settle(async, const Duration(minutes: 4));
      unawaited(h.notifier.pause());
      _settle(async, const Duration(hours: 1));
      expect(h.state, isA<PausedState>(), reason: 'paused time never counts');

      unawaited(h.notifier.resume());
      _settle(async);
      expect(h.state, isA<RecordingActiveState>());
      _settle(async, const Duration(minutes: 4, seconds: 59));
      expect(h.state, isA<RecordingActiveState>());
      _settle(async, const Duration(seconds: 1));
      expect(h.state, isA<StoppedState>());
      expect(h.reason, SessionStopReason.inactivity);
      h.dispose();
    });
  });

  test('the user Stop cancels the timer and records no reason', () {
    fakeAsync((async) {
      final h = _Harness();
      unawaited(h.notifier.start());
      _settle(async, const Duration(minutes: 1));
      unawaited(h.notifier.stop());
      _settle(async, _timeout * 2);

      expect(h.state, isA<StoppedState>());
      expect(h.finalizeCalls, 1);
      expect(h.stoppedEvents, 1);
      expect(h.reason, isNull);
      h.dispose();
    });
  });

  test('a stop for an engine error records no reason', () {
    fakeAsync((async) {
      final h = _Harness();
      when(
        () => h.manager.handleEngineError(any()),
      ).thenAnswer((_) async => false);
      unawaited(h.notifier.start());
      _settle(async, const Duration(minutes: 1));
      h.emitError(RecordingErrorFactories.engineStartFailed());
      _settle(async, _timeout * 2);

      expect(h.state, isA<StoppedState>());
      expect(h.finalizeCalls, 1);
      expect(h.notifier.lastError, isNotNull);
      expect(h.reason, isNull);
      h.dispose();
    });
  });

  test('recovery back to recording restarts the timer from zero', () {
    fakeAsync((async) {
      final h = _Harness();
      unawaited(h.notifier.start());
      _settle(async, const Duration(minutes: 4));
      h.emitError(RecordingErrorFactories.engineStartFailed());
      _settle(async);
      expect(h.state, isA<RecordingActiveState>(), reason: 'recovered');

      _settle(async, const Duration(minutes: 4, seconds: 59));
      expect(h.state, isA<RecordingActiveState>());
      _settle(async, const Duration(seconds: 1));
      expect(h.state, isA<StoppedState>());
      h.dispose();
    });
  });

  test('the timeout in force comes from the provider', () {
    fakeAsync((async) {
      final h = _Harness(timeout: const Duration(minutes: 1));
      unawaited(h.notifier.start());
      _settle(async, const Duration(seconds: 59));
      expect(h.state, isA<RecordingActiveState>());
      _settle(async, const Duration(seconds: 1));
      expect(h.state, isA<StoppedState>());
      h.dispose();
    });
  });

  test('a new session forgets the previous reason', () {
    fakeAsync((async) {
      final h = _Harness();
      unawaited(h.notifier.start());
      _settle(async, _timeout);
      expect(h.reason, SessionStopReason.inactivity);

      h.notifier.clearSession();
      unawaited(h.notifier.start());
      _settle(async);
      expect(h.state, isA<RecordingActiveState>());
      expect(h.reason, isNull);
      h.dispose();
    });
  });
}
