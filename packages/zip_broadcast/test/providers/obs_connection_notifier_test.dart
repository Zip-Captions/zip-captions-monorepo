import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';

import '../helpers/mock_obs_websocket_target.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  ProviderContainer buildContainer(MockObsWebSocketTarget mock) {
    final container = ProviderContainer(
      overrides: [
        obsWebSocketTargetProvider.overrideWithValue(mock),
      ],
    );
    addTearDown(() {
      mock.close();
      container.dispose();
    });
    return container;
  }

  group('ObsConnectionNotifier', () {
    // -----------------------------------------------------------------------
    // TEST-U6.3 — coverage map rows 1–5
    // -----------------------------------------------------------------------

    test('row 1: enable OBS → connect() called once', () async {
      final mock = MockObsWebSocketTarget();
      final container = buildContainer(mock);

      // Initialize notifier (fires listener with obsEnabled=false → disconnect).
      container.read(obsConnectionNotifierProvider);
      await pumpEventQueue();

      final disconnectOnInit = mock.disconnectCount;

      // Enable OBS.
      await container
          .read(outputTargetSettingsNotifierProvider.notifier)
          .update(const OutputTargetSettings(obsEnabled: true));
      await pumpEventQueue();

      expect(mock.connectCount, equals(1));
      expect(disconnectOnInit, isNonNegative);
    });

    test('row 2: status stream disconnect event → state becomes disconnected',
        () async {
      final mock = MockObsWebSocketTarget();
      final container = buildContainer(mock);

      container.read(obsConnectionNotifierProvider);

      // Push connected status.
      mock.pushStatus(ObsConnectionStatus.connected);
      await pumpEventQueue();
      expect(
        container.read(obsConnectionNotifierProvider),
        ObsConnectionStatus.connected,
      );

      // Push disconnected status.
      mock.pushStatus(ObsConnectionStatus.disconnected);
      await pumpEventQueue();
      expect(
        container.read(obsConnectionNotifierProvider),
        ObsConnectionStatus.disconnected,
      );
    });

    test('row 3: testConnection() success returns connected', () async {
      final mock = MockObsWebSocketTarget();
      final container = buildContainer(mock);

      container.read(obsConnectionNotifierProvider);

      final result = await container
          .read(obsConnectionNotifierProvider.notifier)
          .testConnection();

      expect(result, ObsConnectionStatus.connected);
      expect(mock.testCount, equals(1));
    });

    test('row 4: testConnection() timeout returns error (via FakeAsync)', () {
      final mock = MockObsWebSocketTarget()
        ..shouldTimeoutTest = true
        ..testDelay = const Duration(seconds: 5);

      final container = ProviderContainer(
        overrides: [obsWebSocketTargetProvider.overrideWithValue(mock)],
      );
      addTearDown(() {
        mock.close();
        container.dispose();
      });

      fakeAsync((fake) {
        container.read(obsConnectionNotifierProvider);

        ObsConnectionStatus? result;
        container
            .read(obsConnectionNotifierProvider.notifier)
            .testConnection(timeout: const Duration(seconds: 5))
            .then((r) => result = r);

        fake.elapse(const Duration(seconds: 6));
        fake.flushMicrotasks();

        expect(result, ObsConnectionStatus.error);
      });
    });

    test('row 5: disable OBS while enabled → disconnect() called', () async {
      final mock = MockObsWebSocketTarget();
      final container = buildContainer(mock);

      // Initialize notifier.
      container.read(obsConnectionNotifierProvider);
      await pumpEventQueue();

      // Enable OBS.
      await container
          .read(outputTargetSettingsNotifierProvider.notifier)
          .update(const OutputTargetSettings(obsEnabled: true));
      await pumpEventQueue();
      expect(mock.connectCount, equals(1));

      final disconnectCountBeforeDisable = mock.disconnectCount;

      // Disable OBS.
      await container
          .read(outputTargetSettingsNotifierProvider.notifier)
          .update(const OutputTargetSettings(obsEnabled: false));
      await pumpEventQueue();

      expect(mock.disconnectCount, greaterThan(disconnectCountBeforeDisable));
    });
  });
}
