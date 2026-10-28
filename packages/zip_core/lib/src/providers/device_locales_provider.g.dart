// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'device_locales_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$deviceLocalesHash() => r'1aa5c7791a2ad86c48f1d3210717253d1ee9bace';

/// The phone's preferred languages, most preferred first, as BCP-47 tags
/// (e.g. `['en-CA', 'fr-CA']`).
///
/// The default reads the platform dispatcher's locale list. Tests override
/// this provider so the locale resolution order
/// ([resolvedLocaleIdProvider], Amendment 03 section 6) is deterministic and
/// driver-free.
///
/// Copied from [deviceLocales].
@ProviderFor(deviceLocales)
final deviceLocalesProvider = Provider<List<String>>.internal(
  deviceLocales,
  name: r'deviceLocalesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$deviceLocalesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DeviceLocalesRef = ProviderRef<List<String>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
