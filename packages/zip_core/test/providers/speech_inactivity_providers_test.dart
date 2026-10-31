import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/constants/speech_inactivity.dart';
import 'package:zip_core/src/providers/session_stop_reason_provider.dart';
import 'package:zip_core/src/providers/speech_inactivity_timeout_provider.dart';

/// Unit 10 Amendment 05: BR-U10-52 (the setting) and the stop-reason provider
/// behind BR-U10-53.
void main() {
  group('BR-U10-52: speechInactivityTimeout', () {
    test('the default is 5 minutes', () {
      expect(defaultSpeechInactivityTimeout, const Duration(minutes: 5));
    });

    test('the provider returns the constant', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        container.read(speechInactivityTimeoutProvider),
        defaultSpeechInactivityTimeout,
      );
    });

    test('a future setting can override the provider', () {
      final container = ProviderContainer(
        overrides: [
          speechInactivityTimeoutProvider.overrideWithValue(
            const Duration(minutes: 1),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(speechInactivityTimeoutProvider),
        const Duration(minutes: 1),
      );
    });
  });

  group('SessionStopReasonNotifier', () {
    test('starts empty', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(sessionStopReasonNotifierProvider), isNull);
    });

    test('take() returns the recorded reason once, then null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final notifier = container.read(
        sessionStopReasonNotifierProvider.notifier,
      )..reason = SessionStopReason.inactivity;

      expect(
        container.read(sessionStopReasonNotifierProvider),
        SessionStopReason.inactivity,
      );
      expect(notifier.take(), SessionStopReason.inactivity);
      expect(container.read(sessionStopReasonNotifierProvider), isNull);
      expect(notifier.take(), isNull);
    });

    test('clear() forgets the reason', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(sessionStopReasonNotifierProvider.notifier)
        ..reason = SessionStopReason.inactivity
        ..clear();

      expect(container.read(sessionStopReasonNotifierProvider), isNull);
    });
  });
}
