// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_resolver_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$broadcastResolverHash() => r'277889330c6695977d9883dd0ffb094a70c86e42';

/// Provides the app's [BroadcastResolver].
///
/// No app-startup override needed — the real implementation needs only
/// [supabaseClientProvider] and [signalingServiceProvider].
///
/// Copied from [broadcastResolver].
@ProviderFor(broadcastResolver)
final broadcastResolverProvider = Provider<BroadcastResolver>.internal(
  broadcastResolver,
  name: r'broadcastResolverProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$broadcastResolverHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef BroadcastResolverRef = ProviderRef<BroadcastResolver>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
