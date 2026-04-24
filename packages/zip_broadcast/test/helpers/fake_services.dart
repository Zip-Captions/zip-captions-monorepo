import 'package:zip_core/zip_core.dart';

/// No-op [WakeLockService] for unit tests.
class FakeWakeLockService implements WakeLockService {
  @override
  WakeLockSettings get settings => const WakeLockSettings();

  @override
  void updateSettings(WakeLockSettings settings) {}

  @override
  Future<void> acquire() async {}

  @override
  Future<void> release() async {}

  @override
  Future<void> onPause() async {}
}
