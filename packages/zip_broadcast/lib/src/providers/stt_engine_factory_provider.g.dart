// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stt_engine_factory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$sttEngineFactoryHash() => r'3bacfb54ebb366c361a8363aafbb654887946f3a';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// Factory that creates an [SttEngine] for a given [sourceId] (device ID).
///
/// Must be overridden at app startup (e.g. in `main.dart`) with a concrete
/// implementation, typically [PlatformSttEngine]. Tests override with
/// [MockSttEngine] instances.
///
/// The returned engine is NOT managed by Riverpod's lifecycle.
/// [BroadcastRecordingNotifier] owns and disposes engines directly.
///
/// Copied from [sttEngineFactory].
@ProviderFor(sttEngineFactory)
const sttEngineFactoryProvider = SttEngineFactoryFamily();

/// Factory that creates an [SttEngine] for a given [sourceId] (device ID).
///
/// Must be overridden at app startup (e.g. in `main.dart`) with a concrete
/// implementation, typically [PlatformSttEngine]. Tests override with
/// [MockSttEngine] instances.
///
/// The returned engine is NOT managed by Riverpod's lifecycle.
/// [BroadcastRecordingNotifier] owns and disposes engines directly.
///
/// Copied from [sttEngineFactory].
class SttEngineFactoryFamily extends Family<SttEngine> {
  /// Factory that creates an [SttEngine] for a given [sourceId] (device ID).
  ///
  /// Must be overridden at app startup (e.g. in `main.dart`) with a concrete
  /// implementation, typically [PlatformSttEngine]. Tests override with
  /// [MockSttEngine] instances.
  ///
  /// The returned engine is NOT managed by Riverpod's lifecycle.
  /// [BroadcastRecordingNotifier] owns and disposes engines directly.
  ///
  /// Copied from [sttEngineFactory].
  const SttEngineFactoryFamily();

  /// Factory that creates an [SttEngine] for a given [sourceId] (device ID).
  ///
  /// Must be overridden at app startup (e.g. in `main.dart`) with a concrete
  /// implementation, typically [PlatformSttEngine]. Tests override with
  /// [MockSttEngine] instances.
  ///
  /// The returned engine is NOT managed by Riverpod's lifecycle.
  /// [BroadcastRecordingNotifier] owns and disposes engines directly.
  ///
  /// Copied from [sttEngineFactory].
  SttEngineFactoryProvider call(String sourceId) {
    return SttEngineFactoryProvider(sourceId);
  }

  @override
  SttEngineFactoryProvider getProviderOverride(
    covariant SttEngineFactoryProvider provider,
  ) {
    return call(provider.sourceId);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'sttEngineFactoryProvider';
}

/// Factory that creates an [SttEngine] for a given [sourceId] (device ID).
///
/// Must be overridden at app startup (e.g. in `main.dart`) with a concrete
/// implementation, typically [PlatformSttEngine]. Tests override with
/// [MockSttEngine] instances.
///
/// The returned engine is NOT managed by Riverpod's lifecycle.
/// [BroadcastRecordingNotifier] owns and disposes engines directly.
///
/// Copied from [sttEngineFactory].
class SttEngineFactoryProvider extends AutoDisposeProvider<SttEngine> {
  /// Factory that creates an [SttEngine] for a given [sourceId] (device ID).
  ///
  /// Must be overridden at app startup (e.g. in `main.dart`) with a concrete
  /// implementation, typically [PlatformSttEngine]. Tests override with
  /// [MockSttEngine] instances.
  ///
  /// The returned engine is NOT managed by Riverpod's lifecycle.
  /// [BroadcastRecordingNotifier] owns and disposes engines directly.
  ///
  /// Copied from [sttEngineFactory].
  SttEngineFactoryProvider(String sourceId)
    : this._internal(
        (ref) => sttEngineFactory(ref as SttEngineFactoryRef, sourceId),
        from: sttEngineFactoryProvider,
        name: r'sttEngineFactoryProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$sttEngineFactoryHash,
        dependencies: SttEngineFactoryFamily._dependencies,
        allTransitiveDependencies:
            SttEngineFactoryFamily._allTransitiveDependencies,
        sourceId: sourceId,
      );

  SttEngineFactoryProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.sourceId,
  }) : super.internal();

  final String sourceId;

  @override
  Override overrideWith(
    SttEngine Function(SttEngineFactoryRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SttEngineFactoryProvider._internal(
        (ref) => create(ref as SttEngineFactoryRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        sourceId: sourceId,
      ),
    );
  }

  @override
  AutoDisposeProviderElement<SttEngine> createElement() {
    return _SttEngineFactoryProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SttEngineFactoryProvider && other.sourceId == sourceId;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, sourceId.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin SttEngineFactoryRef on AutoDisposeProviderRef<SttEngine> {
  /// The parameter `sourceId` of this provider.
  String get sourceId;
}

class _SttEngineFactoryProviderElement
    extends AutoDisposeProviderElement<SttEngine>
    with SttEngineFactoryRef {
  _SttEngineFactoryProviderElement(super.provider);

  @override
  String get sourceId => (origin as SttEngineFactoryProvider).sourceId;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
