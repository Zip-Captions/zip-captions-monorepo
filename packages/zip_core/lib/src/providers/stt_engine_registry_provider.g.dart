// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_engine_registry_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sttEngineRegistryHash() => r'77ec533587a7b18c43d9f89f8afe55f942a64b63';

/// Singleton [SttEngineRegistry] instance for the app lifetime.
///
/// Concrete STT engines are registered in Unit 2.
///
/// Copied from [sttEngineRegistry].
@ProviderFor(sttEngineRegistry)
final sttEngineRegistryProvider = Provider<SttEngineRegistry>.internal(
  sttEngineRegistry,
  name: r'sttEngineRegistryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sttEngineRegistryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SttEngineRegistryRef = ProviderRef<SttEngineRegistry>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
