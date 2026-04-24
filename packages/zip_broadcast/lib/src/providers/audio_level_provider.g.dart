// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'audio_level_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$audioLevelHash() => r'c990bcd3b6de25ea6807cde573564e4adc7be422';

/// Per-source RMS audio level map (deviceId → 0.0–1.0).
///
/// Production: wired to [AudioDeviceService] level stream when that API is
/// available. Currently returns an empty map (placeholder).
/// Tests override with a fixed map via [audioLevelProvider.overrideWithValue].
///
/// Copied from [audioLevel].
@ProviderFor(audioLevel)
final audioLevelProvider = AutoDisposeProvider<Map<String, double>>.internal(
  audioLevel,
  name: r'audioLevelProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$audioLevelHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef AudioLevelRef = AutoDisposeProviderRef<Map<String, double>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
