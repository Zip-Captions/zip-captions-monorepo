// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stop_finalise_timeout_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$stopFinaliseTimeoutHash() =>
    r'8de34940e7b03eec914eaccbc515245645e26272';

/// The bound on Stop in force (BR-U10-58).
///
/// Returns [defaultStopFinaliseTimeout]. It follows
/// `speechInactivityTimeoutProvider`: the recording notifier reads it and
/// nothing else, and a test overrides it.
///
/// Copied from [stopFinaliseTimeout].
@ProviderFor(stopFinaliseTimeout)
final stopFinaliseTimeoutProvider = Provider<Duration>.internal(
  stopFinaliseTimeout,
  name: r'stopFinaliseTimeoutProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$stopFinaliseTimeoutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef StopFinaliseTimeoutRef = ProviderRef<Duration>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
