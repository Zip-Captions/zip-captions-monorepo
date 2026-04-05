// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'wake_lock_service_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$wakeLockServiceHash() => r'1d050fd54ba645a1d9634de5d2f1a1cc92df0da6';

/// Provides the singleton [WakeLockService].
///
/// Defaults to [WakelockPlusService]. Can be overridden in tests.
///
/// Copied from [wakeLockService].
@ProviderFor(wakeLockService)
final wakeLockServiceProvider = Provider<WakeLockService>.internal(
  wakeLockService,
  name: r'wakeLockServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$wakeLockServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef WakeLockServiceRef = ProviderRef<WakeLockService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
