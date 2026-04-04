// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sherpa_model_catalog_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sherpaModelCatalogNotifierHash() =>
    r'0acd2c57d74f237222c6cf1c38f3584ec22aee03';

/// User-facing model catalog + download lifecycle notifier.
///
/// Wraps [SherpaModelManager] and adds reactive download-state tracking,
/// confirmation gating (USA-U2.1), and engine registration on first
/// download (BR-U2-36).
///
/// Copied from [SherpaModelCatalogNotifier].
@ProviderFor(SherpaModelCatalogNotifier)
final sherpaModelCatalogNotifierProvider =
    NotifierProvider<
      SherpaModelCatalogNotifier,
      SherpaModelCatalogState
    >.internal(
      SherpaModelCatalogNotifier.new,
      name: r'sherpaModelCatalogNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$sherpaModelCatalogNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$SherpaModelCatalogNotifier = Notifier<SherpaModelCatalogState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
