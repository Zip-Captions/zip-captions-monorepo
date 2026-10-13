// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'captioning_starter_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$captioningStarterHash() => r'e30a35a9a6bd7b2d5f35a3cb9c44840daad34282';

/// The [CaptioningStarter] seam (Functional Design Q1). Default value
/// wraps `zip_captions`' single-engine `RecordingStateNotifier`;
/// `zip_broadcast`'s `main.dart` overrides this with a
/// `BroadcastRecordingNotifier`-backed implementation (same override
/// pattern as `authServiceProvider`/`supabaseClientProvider`, Unit 2).
///
/// Copied from [captioningStarter].
@ProviderFor(captioningStarter)
final captioningStarterProvider = Provider<CaptioningStarter>.internal(
  captioningStarter,
  name: r'captioningStarterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$captioningStarterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CaptioningStarterRef = ProviderRef<CaptioningStarter>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
