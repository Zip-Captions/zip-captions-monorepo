// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_identity_repository_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$broadcastIdentityRepositoryHash() =>
    r'98534a5f52638cf06c9aa2754f6c8a22364e6699';

/// Provides the app's [BroadcastIdentityRepository].
///
/// Unlike `authServiceProvider`/`audioDeviceServiceProvider`, this doesn't
/// need an app-startup override — the real implementation needs only
/// [supabaseClientProvider], already resolvable here.
///
/// Copied from [broadcastIdentityRepository].
@ProviderFor(broadcastIdentityRepository)
final broadcastIdentityRepositoryProvider =
    Provider<BroadcastIdentityRepository>.internal(
      broadcastIdentityRepository,
      name: r'broadcastIdentityRepositoryProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$broadcastIdentityRepositoryHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BroadcastIdentityRepositoryRef =
    ProviderRef<BroadcastIdentityRepository>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
