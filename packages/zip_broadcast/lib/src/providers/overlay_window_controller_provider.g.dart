// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_window_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$overlayWindowControllerHash() =>
    r'8fcd0cfe2774c01f96172008f4b6294c87d619a1';

/// The one external display window controller, alive for the app container.
///
/// Kept alive: the controller owns a window, a timer and a platform display
/// observer, so it is a long-lived resource rather than a per-watch value.
///
/// Copied from [overlayWindowController].
@ProviderFor(overlayWindowController)
final overlayWindowControllerProvider =
    Provider<OverlayWindowController>.internal(
      overlayWindowController,
      name: r'overlayWindowControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$overlayWindowControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef OverlayWindowControllerRef = ProviderRef<OverlayWindowController>;
String _$externalDisplayStatusHash() =>
    r'586d0ce072209f2b6b6aedc78d09f3928e53098c';

/// The state the external display controls render.
///
/// Replays the current status first: [OverlayWindowController.statusChanges]
/// is a broadcast stream, so a plain subscription would stay in
/// `AsyncLoading` on a capable machine (the controller starts `Off` and emits
/// nothing until a transition), and the controls would never render.
///
/// Copied from [externalDisplayStatus].
@ProviderFor(externalDisplayStatus)
final externalDisplayStatusProvider =
    AutoDisposeStreamProvider<ExternalDisplayStatus>.internal(
      externalDisplayStatus,
      name: r'externalDisplayStatusProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$externalDisplayStatusHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef ExternalDisplayStatusRef =
    AutoDisposeStreamProviderRef<ExternalDisplayStatus>;
String _$displayListHash() => r'dbc98a7ea53cf517cde4f82c4724c56b495705d4';

/// The connected displays, per the enumerator's event contract.
///
/// Copied from [displayList].
@ProviderFor(displayList)
final displayListProvider =
    AutoDisposeStreamProvider<List<DisplayInfo>>.internal(
      displayList,
      name: r'displayListProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$displayListHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DisplayListRef = AutoDisposeStreamProviderRef<List<DisplayInfo>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
