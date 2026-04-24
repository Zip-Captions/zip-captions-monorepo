// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_recording_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$broadcastRecordingNotifierHash() =>
    r'68b290d7b4c5fdf84d67a434bb2e57a157032eef';

/// Multi-engine recording state machine for Zip Broadcast (Q1=A, FD B2).
///
/// Starts one [SttEngine] per configured [AudioInputConfig]. Tags each
/// [SttResult] with the config's [AudioInputConfig.deviceId] before
/// publishing to [CaptionBus] (sourceId tagging).
///
/// Partial failure: if some engines fail to initialise, recording continues
/// with the engines that succeeded (REL-U6.1, P1–P3). If all fail, transitions
/// to [BroadcastIdleState] with a non-null [BroadcastIdleState.lastError].
///
/// Copied from [BroadcastRecordingNotifier].
@ProviderFor(BroadcastRecordingNotifier)
final broadcastRecordingNotifierProvider =
    NotifierProvider<
      BroadcastRecordingNotifier,
      BroadcastSessionState
    >.internal(
      BroadcastRecordingNotifier.new,
      name: r'broadcastRecordingNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$broadcastRecordingNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BroadcastRecordingNotifier = Notifier<BroadcastSessionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
