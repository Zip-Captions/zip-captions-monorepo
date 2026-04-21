import 'dart:io';

import 'package:local_auth/local_auth.dart';

/// Returns true if the device has any screen lock configured.
///
/// Returns false on Linux (unsupported by local_auth) and on any error.
Future<bool> hasConfiguredDeviceAuthentication() async {
  if (Platform.isLinux) return false;
  try {
    return await LocalAuthentication().isDeviceSupported();
  } on Object {
    return false;
  }
}
