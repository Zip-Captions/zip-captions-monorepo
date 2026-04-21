import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'device_auth_provider.g.dart';

/// Returns true if the device has any authentication configured
/// (PIN, pattern, password, or biometrics).
///
/// Transcript saving is blocked when this returns false — a device with no
/// lock screen cannot protect locally stored transcript data.
@Riverpod(keepAlive: true)
Future<bool> deviceSecured(Ref ref) =>
    LocalAuthentication().isDeviceSupported();
