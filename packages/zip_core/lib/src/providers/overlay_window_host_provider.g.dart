// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_window_host_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$overlayWindowHostHash() => r'6a1f958ee1893829b87a9eb16b7f3097e0f95751';

/// The engine's one [OverlayWindowHost] (NFR Design §2).
///
/// Keep-alive so both window controllers share one router, one display
/// observer and one close channel for the container's lifetime; the host is
/// disposed with the container.
///
/// Copied from [overlayWindowHost].
@ProviderFor(overlayWindowHost)
final overlayWindowHostProvider = Provider<OverlayWindowHost>.internal(
  overlayWindowHost,
  name: r'overlayWindowHostProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$overlayWindowHostHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OverlayWindowHostRef = ProviderRef<OverlayWindowHost>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
