import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/mock_caption_bus.dart';
import '../helpers/mock_obs_websocket_target.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

ProviderContainer _buildContainer(
  MockObsWebSocketTarget mockObs,
  MockCaptionBus bus,
  SharedPreferences prefs,
) {
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      obsWebSocketTargetProvider.overrideWithValue(mockObs),
      captionBusProvider.overrideWithValue(bus),
    ],
  );
  addTearDown(() {
    mockObs.close();
    container.dispose();
  });
  return container;
}

// ---------------------------------------------------------------------------
// Tests — INT-ZB-03: OBS settings ↔ connection ↔ caption forwarding
// ---------------------------------------------------------------------------

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  group('INT-ZB-03: ObsConnectionNotifier settings + caption forwarding', () {
    test('enable OBS → final caption on bus → forwarded to OBS target',
        () async {
      final mockObs = MockObsWebSocketTarget();
      final bus = MockCaptionBus();
      final container = _buildContainer(mockObs, bus, prefs);

      // Initialize the notifier (triggers fireImmediately ref.listen).
      container.read(obsConnectionNotifierProvider);
      await pumpEventQueue();

      // Enable OBS — MockObsWebSocketTarget.connect() emits 'connected'.
      await container
          .read(outputTargetSettingsNotifierProvider.notifier)
          .update(const OutputTargetSettings(obsEnabled: true));
      await pumpEventQueue();

      expect(
        container.read(obsConnectionNotifierProvider),
        equals(ObsConnectionStatus.connected),
      );

      // Publish a final caption to the bus.
      bus.publish(
        SttResultEvent(SttResult(text: 'test caption', isFinal: true, confidence: 1.0, timestamp: DateTime(2026), sourceId: 'default')),
      );
      await pumpEventQueue();

      expect(mockObs.sentCaptions, contains('test caption'));
    });

    test('partial caption (isFinal=false) → not forwarded to OBS', () async {
      final mockObs = MockObsWebSocketTarget();
      final bus = MockCaptionBus();
      final container = _buildContainer(mockObs, bus, prefs);

      container.read(obsConnectionNotifierProvider);
      await pumpEventQueue();

      await container
          .read(outputTargetSettingsNotifierProvider.notifier)
          .update(const OutputTargetSettings(obsEnabled: true));
      await pumpEventQueue();

      bus.publish(
        SttResultEvent(
          SttResult(text: 'partial', isFinal: false, confidence: 1.0, timestamp: DateTime(2026), sourceId: 'default'),
        ),
      );
      await pumpEventQueue();

      expect(mockObs.sentCaptions, isEmpty);
    });

    test('disable OBS → caption on bus → not forwarded', () async {
      final mockObs = MockObsWebSocketTarget();
      final bus = MockCaptionBus();
      final container = _buildContainer(mockObs, bus, prefs);

      container.read(obsConnectionNotifierProvider);
      await pumpEventQueue();

      // Enable then disable.
      final settingsNotifier =
          container.read(outputTargetSettingsNotifierProvider.notifier);
      await settingsNotifier
          .update(const OutputTargetSettings(obsEnabled: true));
      await pumpEventQueue();
      await settingsNotifier
          .update(const OutputTargetSettings(obsEnabled: false));
      await pumpEventQueue();

      final countBefore = mockObs.sentCaptions.length;

      bus.publish(
        SttResultEvent(SttResult(text: 'should not send', isFinal: true, confidence: 1.0, timestamp: DateTime(2026), sourceId: 'default')),
      );
      await pumpEventQueue();

      expect(mockObs.sentCaptions.length, equals(countBefore));
    });

    test('enable OBS → SessionStateEvent on bus → not forwarded (only SttResult)',
        () async {
      final mockObs = MockObsWebSocketTarget();
      final bus = MockCaptionBus();
      final container = _buildContainer(mockObs, bus, prefs);

      container.read(obsConnectionNotifierProvider);
      await pumpEventQueue();

      await container
          .read(outputTargetSettingsNotifierProvider.notifier)
          .update(const OutputTargetSettings(obsEnabled: true));
      await pumpEventQueue();

      bus.publish(
        SessionStateEvent(
          RecordingState.recording(sessionId: 'sid'),
        ),
      );
      await pumpEventQueue();

      expect(mockObs.sentCaptions, isEmpty);
    });
  });
}
