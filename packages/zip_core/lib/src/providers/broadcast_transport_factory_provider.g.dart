// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_transport_factory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$broadcastTransportFactoryHash() =>
    r'1b40c7d04420e171e8c4ae3f5a360f701be3495d';

/// Provides a factory for the app's [BroadcastTransport].
///
/// Not `transportSelectorProvider` returning [TransportSelector] directly:
/// `TransportSelector.broadcastTransport()`'s declared return type is the
/// concrete `WebRtcBroadcastTransport` (fixed shape, Application Design,
/// Unit 5), not the [BroadcastTransport] interface — overriding a provider
/// typed to that concrete class could never substitute a fake in
/// `BroadcastSessionNotifier`'s own tests (NFR Requirements Q1). This
/// provider's declared return type is the interface; the real factory
/// closure still just calls `TransportSelector().broadcastTransport()` —
/// a `WebRtcBroadcastTransport` is a `BroadcastTransport`, so no cast is
/// needed, only a wider declared type.
///
/// Copied from [broadcastTransportFactory].
@ProviderFor(broadcastTransportFactory)
final broadcastTransportFactoryProvider =
    Provider<BroadcastTransport Function()>.internal(
      broadcastTransportFactory,
      name: r'broadcastTransportFactoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$broadcastTransportFactoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BroadcastTransportFactoryRef =
    ProviderRef<BroadcastTransport Function()>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
