import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_captions/src/services/device_auth_status.dart';

part 'device_auth_provider.g.dart';

/// Returns true if the device has any authentication configured
/// (PIN, pattern, password, or biometrics).
///
/// Transcript saving is blocked when this returns false — a device with no
/// lock screen cannot protect locally stored transcript data.
///
/// Always returns false on web and Linux (unsupported platforms).
@Riverpod(keepAlive: true)
Future<bool> deviceSecured(Ref ref) =>
    hasConfiguredDeviceAuthentication();
