import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/audio/audio_device_service.dart';

part 'audio_device_service_provider.g.dart';

/// Provides the platform [AudioDeviceService].
///
/// The concrete implementation is registered at app startup via
/// provider overrides. This provider throws by default if no
/// override is supplied.
@Riverpod(keepAlive: true)
AudioDeviceService audioDeviceService(Ref ref) {
  throw UnimplementedError(
    'AudioDeviceService must be overridden at app startup '
    'with a platform-specific implementation.',
  );
}
