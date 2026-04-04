// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sttEngineHash() => r'8e7c4f379b4eb6c9c421259836bcd52d800064c7';

/// Resolves the active [SttEngine] from the registry.
///
/// Uses [activeEngineIdNotifierProvider] to pick the user-selected engine.
/// Falls back to [SttEngineRegistry.defaultEngine] when no explicit selection
/// exists. Returns `null` if no engines are registered.
///
/// Copied from [sttEngine].
@ProviderFor(sttEngine)
final sttEngineProvider = Provider<SttEngine?>.internal(
  sttEngine,
  name: r'sttEngineProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$sttEngineHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef SttEngineRef = ProviderRef<SttEngine?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
