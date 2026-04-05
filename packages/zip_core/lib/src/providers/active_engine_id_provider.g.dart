// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'active_engine_id_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$activeEngineIdNotifierHash() =>
    r'7e3fe44f795e302611153088bcf15587e1955603';

/// User-selected STT engine ID, persisted in SharedPreferences.
///
/// `null` means no explicit selection — the app uses the default engine.
///
/// Copied from [ActiveEngineIdNotifier].
@ProviderFor(ActiveEngineIdNotifier)
final activeEngineIdNotifierProvider =
    NotifierProvider<ActiveEngineIdNotifier, String?>.internal(
      ActiveEngineIdNotifier.new,
      name: r'activeEngineIdNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$activeEngineIdNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$ActiveEngineIdNotifier = Notifier<String?>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
