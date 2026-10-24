// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_window_host_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$overlayWindowHostHash() => r'8e40b5802dc141a640de8a4289f52f6d9c191c5f';

/// The engine's one [OverlayWindowHost] (NFR Design §2).
///
/// Keep-alive so both window controllers share one router, one display
/// observer and one close channel for the container's lifetime; the host is
/// disposed with the container.
///
/// The host is built on a named logger so its router, enumerator and
/// controllers log beneath it, and a debug build prints that subtree to the
/// console (R6-5). A release build adds no route.
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
