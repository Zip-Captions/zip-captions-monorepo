// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pop_out_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$popOutWindowControllerHash() =>
    r'0391e8779ab4fce6af8a8f16a2c2a1c92bdd74d2';

/// The pop-out window controller, alive for the app container.
///
/// Built from the engine's one host (NFR Design §2), so the external display
/// and the pop-out share a router, a display observer and a close channel.
///
/// Copied from [popOutWindowController].
@ProviderFor(popOutWindowController)
final popOutWindowControllerProvider =
    Provider<OverlayWindowController>.internal(
      popOutWindowController,
      name: r'popOutWindowControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$popOutWindowControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PopOutWindowControllerRef = ProviderRef<OverlayWindowController>;
String _$popOutStatusHash() => r'2423e201a14b9009f016481f0801f4076354df06';

/// The pop-out's status, replaying the current one first (the stream is a
/// broadcast, and the controller starts `Off`).
///
/// Copied from [popOutStatus].
@ProviderFor(popOutStatus)
final popOutStatusProvider =
    AutoDisposeStreamProvider<ExternalDisplayStatus>.internal(
      popOutStatus,
      name: r'popOutStatusProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$popOutStatusHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PopOutStatusRef = AutoDisposeStreamProviderRef<ExternalDisplayStatus>;
String _$popOutEventsHash() => r'80fdcde009861c9bd486a91052ba3217726f6321';

/// The pop-out's lifecycle events. The shell is the only listener.
///
/// Copied from [popOutEvents].
@ProviderFor(popOutEvents)
final popOutEventsProvider = AutoDisposeStreamProvider<OverlayEvent>.internal(
  popOutEvents,
  name: r'popOutEventsProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$popOutEventsHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PopOutEventsRef = AutoDisposeStreamProviderRef<OverlayEvent>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
