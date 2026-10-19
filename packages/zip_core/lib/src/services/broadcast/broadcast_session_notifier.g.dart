// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'broadcast_session_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$broadcastSessionNotifierHash() =>
    r'85649e014f01ba12dbe6207126b356dfc145f135';

/// The broadcaster's own session orchestration (fixed shape, Application
/// Design; behavior designed in `business-logic-model.md`).
///
/// Explicit calls into already-shipped services (Units 2–5) — no reactive
/// watcher triggers a side effect (the project Riverpod convention).
/// Failure handling implements `business-rules.md` Rule 2's table exactly,
/// including its deliberate per-step unwind choices (e.g. step 6's target
/// create/register/prime failure is documented as "local operation;
/// failure = programming error" with no unwind — not an oversight).
///
/// Copied from [BroadcastSessionNotifier].
@ProviderFor(BroadcastSessionNotifier)
final broadcastSessionNotifierProvider =
    NotifierProvider<
      BroadcastSessionNotifier,
      BroadcasterSessionState
    >.internal(
      BroadcastSessionNotifier.new,
      name: r'broadcastSessionNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$broadcastSessionNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$BroadcastSessionNotifier = Notifier<BroadcasterSessionState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
