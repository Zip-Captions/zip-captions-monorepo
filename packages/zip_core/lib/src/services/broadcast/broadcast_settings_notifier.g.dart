// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_settings_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$broadcastSettingsNotifierHash() =>
    r'de4abc744444721522fb3c7c5679fecdede6f45d';

/// Loads and persists [BroadcastSettings] (Phase 1 settings pattern — load
/// on build, persist on update). Read by `BroadcastSetupScreen`
/// (two-way bound form) and `BroadcastSessionNotifier` (`goLive()` reads
/// the current settings; it never writes them).
///
/// Copied from [BroadcastSettingsNotifier].
@ProviderFor(BroadcastSettingsNotifier)
final broadcastSettingsNotifierProvider =
    NotifierProvider<BroadcastSettingsNotifier, BroadcastSettings>.internal(
      BroadcastSettingsNotifier.new,
      name: r'broadcastSettingsNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$broadcastSettingsNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BroadcastSettingsNotifier = Notifier<BroadcastSettings>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
