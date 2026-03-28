// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_engine_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sttEngineNotifierHash() => r'34c6db6d0c5ed3434d8454b61b9f8fdab2d877e2';

/// Provider for the active STT engine.
///
/// Phase 0: throws [UnimplementedError].
/// Phase 1: returns the platform-appropriate engine.
///
/// Copied from [SttEngineNotifier].
@ProviderFor(SttEngineNotifier)
final sttEngineNotifierProvider =
    AsyncNotifierProvider<SttEngineNotifier, SttEngine>.internal(
      SttEngineNotifier.new,
      name: r'sttEngineNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sttEngineNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SttEngineNotifier = AsyncNotifier<SttEngine>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
