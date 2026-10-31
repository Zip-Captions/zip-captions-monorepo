// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'language_pack_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$languagePackServiceHash() =>
    r'7c93b7c0dd04cc3dae11a6a161f0cc6876854608';

/// The language-pack service (Amendment 04).
///
/// Wired to `MethodChannelLanguagePackService` in `runZipCaptions`; a test
/// overrides it with a fake. Reading it unwired is a programming error, which
/// the panel treats as an `unknown` status rather than a crash.
///
/// Copied from [languagePackService].
@ProviderFor(languagePackService)
final languagePackServiceProvider = Provider<LanguagePackService>.internal(
  languagePackService,
  name: r'languagePackServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$languagePackServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LanguagePackServiceRef = ProviderRef<LanguagePackService>;
String _$languagePackOsVersionHash() =>
    r'c3451c2df4c55a0337df31794392d92c53c849bb';

/// The OS version the panel decides on (TP-28): the iOS major version, or
/// null when unreadable. Android's SDK level is never needed: the panel's
/// Android answer does not depend on it, so it reads null there.
///
/// An injectable value, so a test can pin any version without a platform.
///
/// Copied from [languagePackOsVersion].
@ProviderFor(languagePackOsVersion)
final languagePackOsVersionProvider = Provider<int?>.internal(
  languagePackOsVersion,
  name: r'languagePackOsVersionProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$languagePackOsVersionHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef LanguagePackOsVersionRef = ProviderRef<int?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
