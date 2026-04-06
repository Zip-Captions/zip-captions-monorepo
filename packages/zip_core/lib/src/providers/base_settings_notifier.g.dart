// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'base_settings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sharedPreferencesHash() => r'99dc291a066f4625c5b0713dfe47d7c14d7f0720';

/// Provider for a pre-initialized [SharedPreferences] instance.
///
/// Must be overridden in the app's `ProviderScope` with a pre-initialized
/// instance. In tests, use `SharedPreferences.setMockInitialValues()` before
/// creating the `ProviderContainer`.
///
/// Copied from [sharedPreferences].
@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = Provider<SharedPreferences>.internal(
  sharedPreferences,
  name: r'sharedPreferencesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sharedPreferencesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SharedPreferencesRef = ProviderRef<SharedPreferences>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
