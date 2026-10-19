// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'viewer_transport_factory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$viewerTransportFactoryHash() =>
    r'513b10e324f843d7ac949233328d147150bbc18d';

/// Provides a factory for the app's [ViewerTransport] (mirrors
/// `broadcast_transport_factory_provider.dart`).
///
/// Not `TransportSelector` directly: `TransportSelector.viewerTransport()`'s
/// declared return type is the concrete `WebRtcViewerTransport` (fixed
/// shape, Application Design), which a test fake could never substitute.
/// This provider's declared return type is the interface; the real factory
/// closure still just calls `TransportSelector().viewerTransport()` — the
/// concrete class is a [ViewerTransport], so no cast is needed, only a wider
/// declared type. Overridden in tests with a fake (NFR Requirements Q1).
///
/// Copied from [viewerTransportFactory].
@ProviderFor(viewerTransportFactory)
final viewerTransportFactoryProvider =
    Provider<ViewerTransport Function()>.internal(
      viewerTransportFactory,
      name: r'viewerTransportFactoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$viewerTransportFactoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ViewerTransportFactoryRef = ProviderRef<ViewerTransport Function()>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
