// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'speech_inactivity_timeout_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$speechInactivityTimeoutHash() =>
    r'bc8f77d30eea6eb56bd76a6c91d59e57c9d8eb23';

/// The inactivity timeout in force (BR-U10-52).
///
/// Returns [defaultSpeechInactivityTimeout]. A future user setting overrides
/// this provider; the recording notifier and the notice read it and nothing
/// else.
///
/// Copied from [speechInactivityTimeout].
@ProviderFor(speechInactivityTimeout)
final speechInactivityTimeoutProvider = Provider<Duration>.internal(
  speechInactivityTimeout,
  name: r'speechInactivityTimeoutProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$speechInactivityTimeoutHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SpeechInactivityTimeoutRef = ProviderRef<Duration>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
