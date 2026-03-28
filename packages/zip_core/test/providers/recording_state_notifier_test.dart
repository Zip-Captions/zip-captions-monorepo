import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });

  tearDown(() => container.dispose());

  RecordingStateNotifier notifier() =>
      container.read(recordingStateNotifierProvider.notifier);

  RecordingState state() =>
      container.read(recordingStateNotifierProvider);

  group('RecordingStateNotifier', () {
    test('initial state is idle', () {
      expect(state(), isA<IdleState>());
    });

    group('valid transitions', () {
      test('idle -> recording via start', () async {
        await notifier().start();
        expect(state(), isA<RecordingActiveState>());
      });

      test('recording -> paused via pause', () async {
        await notifier().start();
        await notifier().pause();
        expect(state(), isA<PausedState>());
      });

      test('paused -> recording via resume', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().resume();
        expect(state(), isA<RecordingActiveState>());
      });

      test('recording -> stopped via stop', () async {
        await notifier().start();
        await notifier().stop();
        expect(state(), isA<StoppedState>());
      });

      test('paused -> stopped via stop', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().stop();
        expect(state(), isA<StoppedState>());
      });

      test('stopped -> idle via clearSession', () async {
        await notifier().start();
        await notifier().stop();
        notifier().clearSession();
        expect(state(), isA<IdleState>());
      });
    });

    group('invalid transitions (silent no-op)', () {
      test('idle: pause is no-op', () async {
        await notifier().pause();
        expect(state(), isA<IdleState>());
      });

      test('idle: resume is no-op', () async {
        await notifier().resume();
        expect(state(), isA<IdleState>());
      });

      test('idle: stop is no-op', () async {
        await notifier().stop();
        expect(state(), isA<IdleState>());
      });

      test('idle: clearSession is no-op', () {
        notifier().clearSession();
        expect(state(), isA<IdleState>());
      });

      test('recording: start is no-op', () async {
        await notifier().start();
        await notifier().start();
        expect(state(), isA<RecordingActiveState>());
      });

      test('recording: resume is no-op', () async {
        await notifier().start();
        await notifier().resume();
        expect(state(), isA<RecordingActiveState>());
      });

      test('recording: clearSession is no-op', () async {
        await notifier().start();
        notifier().clearSession();
        expect(state(), isA<RecordingActiveState>());
      });

      test('paused: start is no-op', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().start();
        expect(state(), isA<PausedState>());
      });

      test('paused: pause is no-op', () async {
        await notifier().start();
        await notifier().pause();
        await notifier().pause();
        expect(state(), isA<PausedState>());
      });

      test('paused: clearSession is no-op', () async {
        await notifier().start();
        await notifier().pause();
        notifier().clearSession();
        expect(state(), isA<PausedState>());
      });

      test('stopped: start is no-op', () async {
        await notifier().start();
        await notifier().stop();
        await notifier().start();
        expect(state(), isA<StoppedState>());
      });

      test('stopped: pause is no-op', () async {
        await notifier().start();
        await notifier().stop();
        await notifier().pause();
        expect(state(), isA<StoppedState>());
      });

      test('stopped: resume is no-op', () async {
        await notifier().start();
        await notifier().stop();
        await notifier().resume();
        expect(state(), isA<StoppedState>());
      });

      test('stopped: stop is no-op', () async {
        await notifier().start();
        await notifier().stop();
        await notifier().stop();
        expect(state(), isA<StoppedState>());
      });
    });

    group('pause/resume cycles (BR-02)', () {
      test('supports multiple pause/resume cycles', () async {
        await notifier().start();

        for (var i = 0; i < 5; i++) {
          await notifier().pause();
          expect(state(), isA<PausedState>());
          await notifier().resume();
          expect(state(), isA<RecordingActiveState>());
        }
      });
    });

    test('start clears lastError', () async {
      await notifier().start();
      expect(notifier().lastError, isNull);
    });

    test('clearSession clears lastError', () async {
      await notifier().start();
      await notifier().stop();
      notifier().clearSession();
      expect(notifier().lastError, isNull);
    });
  });
}
