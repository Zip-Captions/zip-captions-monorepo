import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/wake_lock/wake_lock_service.dart';
import 'package:zip_core/src/services/wake_lock/wakelock_plus_service.dart';

part 'wake_lock_service_provider.g.dart';

/// Provides the singleton [WakeLockService].
///
/// Defaults to [WakelockPlusService]. Can be overridden in tests.
@Riverpod(keepAlive: true)
WakeLockService wakeLockService(Ref ref) {
  return WakelockPlusService();
}
