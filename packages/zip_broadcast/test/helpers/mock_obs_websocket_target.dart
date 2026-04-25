import 'dart:async';

import 'package:zip_broadcast/src/models/obs_connection_status.dart';
import 'package:zip_broadcast/src/providers/obs_web_socket_target.dart';

/// Controllable [ObsWebSocketTarget] for `ObsConnectionNotifier` unit tests
/// (TEST-U6.3). Injects via `obsWebSocketTargetProvider.overrideWithValue`.
class MockObsWebSocketTarget implements ObsWebSocketTarget {
  bool shouldFailConnect = false;
  bool shouldTimeoutTest = false;
  Duration testDelay = Duration.zero;

  int connectCount = 0;
  int disconnectCount = 0;
  int testCount = 0;

  final List<String> sentCaptions = [];

  final _statusController =
      StreamController<ObsConnectionStatus>.broadcast();

  @override
  Stream<ObsConnectionStatus> get statusStream => _statusController.stream;

  @override
  Future<void> connect() async {
    connectCount++;
    if (shouldFailConnect) {
      throw const ObsConnectionException('mock fail');
    }
    _statusController.add(ObsConnectionStatus.connected);
  }

  @override
  Future<void> disconnect() async {
    disconnectCount++;
    _statusController.add(ObsConnectionStatus.disconnected);
  }

  @override
  Future<ObsConnectionStatus> testConnection({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    testCount++;
    if (shouldTimeoutTest) {
      final delay = testDelay == Duration.zero ? timeout : testDelay;
      await Future<void>.delayed(delay);
      return ObsConnectionStatus.error;
    }
    return ObsConnectionStatus.connected;
  }

  @override
  Future<void> send(String captionText) async =>
      sentCaptions.add(captionText);

  /// Push an arbitrary status update to the notifier's listener.
  void pushStatus(ObsConnectionStatus status) =>
      _statusController.add(status);

  @override
  void dispose() {}

  /// Close the status stream.
  void close() => unawaited(_statusController.close());
}
