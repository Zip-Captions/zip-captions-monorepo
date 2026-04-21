// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$deviceSecuredHash() => r'786dc6293ef696f50dba3896940a6ac147124469';

/// Returns true if the device has any authentication configured
/// (PIN, pattern, password, or biometrics).
///
/// Transcript saving is blocked when this returns false — a device with no
/// lock screen cannot protect locally stored transcript data.
///
/// Always returns false on web and Linux (unsupported platforms).
///
/// Copied from [deviceSecured].
@ProviderFor(deviceSecured)
final deviceSecuredProvider = FutureProvider<bool>.internal(
  deviceSecured,
  name: r'deviceSecuredProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deviceSecuredHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DeviceSecuredRef = FutureProviderRef<bool>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
