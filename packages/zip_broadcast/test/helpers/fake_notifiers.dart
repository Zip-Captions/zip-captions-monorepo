import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/obs_connection_notifier.dart';

/// Fake [AudioInputConfigNotifier] that returns an empty list.
///
/// Used in HomeScreen widget tests: Start should be disabled when no audio
/// inputs are configured (TEST-U6.1).
///
/// Usage: `audioInputConfigNotifierProvider.overrideWith(FakeEmptyAudioInputConfigNotifier.new)`
class FakeEmptyAudioInputConfigNotifier extends AudioInputConfigNotifier {
  @override
  List<AudioInputConfig> build() => const [];
}

/// Fake [AudioInputConfigNotifier] that returns one default input.
///
/// Usage: `audioInputConfigNotifierProvider.overrideWith(FakeOneInputAudioInputConfigNotifier.new)`
class FakeOneInputAudioInputConfigNotifier
    extends AudioInputConfigNotifier {
  @override
  List<AudioInputConfig> build() => const [
        AudioInputConfig(
          deviceId: 'mic-0',
          name: 'Test Mic',
        ),
      ];
}

/// Fake [BroadcastRecordingNotifier] stuck in [BroadcastIdleState].
///
/// Usage: `broadcastRecordingNotifierProvider.overrideWith(FakeIdleBroadcastRecordingNotifier.new)`
class FakeIdleBroadcastRecordingNotifier
    extends BroadcastRecordingNotifier {
  @override
  BroadcastSessionState build() => const BroadcastIdleState();

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  void clearSession() {}
}

/// Fake [BroadcastRecordingNotifier] stuck in [BroadcastActiveState].
///
/// Usage: `broadcastRecordingNotifierProvider.overrideWith(FakeActiveBroadcastRecordingNotifier.new)`
class FakeActiveBroadcastRecordingNotifier
    extends BroadcastRecordingNotifier {
  @override
  BroadcastSessionState build() => const BroadcastActiveState(
        sessionId: 'test-session',
        perEngineStates: {'mic-0': EngineActiveState()},
      );

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  void clearSession() {}
}

/// Fake [ObsConnectionNotifier] returning [ObsConnectionStatus.disconnected].
///
/// Usage: `obsConnectionNotifierProvider.overrideWith(FakeDisconnectedObsConnectionNotifier.new)`
class FakeDisconnectedObsConnectionNotifier extends ObsConnectionNotifier {
  @override
  ObsConnectionStatus build() => ObsConnectionStatus.disconnected;

  @override
  Future<ObsConnectionStatus> testConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      ObsConnectionStatus.error;
}

/// Fake [ObsConnectionNotifier] returning [ObsConnectionStatus.connected].
///
/// Usage: `obsConnectionNotifierProvider.overrideWith(FakeConnectedObsConnectionNotifier.new)`
class FakeConnectedObsConnectionNotifier extends ObsConnectionNotifier {
  @override
  ObsConnectionStatus build() => ObsConnectionStatus.connected;

  @override
  Future<ObsConnectionStatus> testConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async =>
      ObsConnectionStatus.connected;
}

/// Fake [BroadcastRecordingNotifier] stuck in [BroadcastPausedState].
///
/// Usage: `broadcastRecordingNotifierProvider.overrideWith(FakePausedBroadcastRecordingNotifier.new)`
class FakePausedBroadcastRecordingNotifier extends BroadcastRecordingNotifier {
  @override
  BroadcastSessionState build() => const BroadcastPausedState(
        sessionId: 'test-session',
        perEngineStates: {'mic-0': EngineActiveState()},
      );

  @override
  Future<void> start() async {}

  @override
  Future<void> pause() async {}

  @override
  Future<void> resume() async {}

  @override
  Future<void> stop() async {}

  @override
  void clearSession() {}
}

/// Fake [AudioInputConfigNotifier] that returns two default inputs.
///
/// Usage: `audioInputConfigNotifierProvider.overrideWith(FakeTwoInputAudioInputConfigNotifier.new)`
class FakeTwoInputAudioInputConfigNotifier extends AudioInputConfigNotifier {
  @override
  List<AudioInputConfig> build() => const [
        AudioInputConfig(deviceId: 'mic-0', name: 'Mic 0'),
        AudioInputConfig(deviceId: 'mic-1', name: 'Mic 1'),
      ];
}
