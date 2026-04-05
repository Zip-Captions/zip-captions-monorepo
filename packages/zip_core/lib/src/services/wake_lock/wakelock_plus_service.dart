import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zip_core/src/models/wake_lock_settings.dart';
import 'package:zip_core/src/services/wake_lock/wake_lock_service.dart';

/// Production [WakeLockService] implementation using `wakelock_plus`.
///
/// Delegates to static `WakelockPlus.enable()` / `WakelockPlus.disable()`.
/// Wrapped behind the [WakeLockService] interface because the static API
/// cannot be mocked directly (Q5=A).
class WakelockPlusService implements WakeLockService {
  /// Creates a [WakelockPlusService] with optional initial settings.
  WakelockPlusService({
    WakeLockSettings settings = const WakeLockSettings(),
  }) : _settings = settings;

  WakeLockSettings _settings;

  @override
  WakeLockSettings get settings => _settings;

  @override
  Future<void> acquire() async {
    if (_settings.enabled) {
      await WakelockPlus.enable();
    }
  }

  @override
  Future<void> release() async {
    await WakelockPlus.disable();
  }

  @override
  Future<void> onPause() async {
    if (_settings.releaseOnPause) {
      await release();
    }
  }

  @override
  void updateSettings(WakeLockSettings settings) {
    _settings = settings;
  }
}
