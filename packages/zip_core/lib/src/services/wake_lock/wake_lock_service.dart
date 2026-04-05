import 'package:zip_core/src/models/wake_lock_settings.dart';

/// Abstract wake lock service for keeping the screen on during captioning.
///
/// Production: `WakelockPlusService` (delegates to static `WakelockPlus` API).
/// Tests: `MockWakeLockService` (mocktail).
abstract interface class WakeLockService {
  /// Current wake lock settings.
  WakeLockSettings get settings;

  /// Enable the screen wake lock if `settings.enabled` is true.
  ///
  /// Called on `start()` and `resume()` transitions.
  Future<void> acquire();

  /// Disable the screen wake lock unconditionally.
  ///
  /// Called on `stop()` transition.
  Future<void> release();

  /// Conditionally release the wake lock based on `settings.releaseOnPause`.
  ///
  /// Called on `pause()` transition.
  Future<void> onPause();

  /// Replace the current settings. Effect applies on the next transition.
  void updateSettings(WakeLockSettings settings);
}
