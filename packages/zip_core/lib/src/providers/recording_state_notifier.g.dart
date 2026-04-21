// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recording_state_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$recordingStateNotifierHash() =>
    r'be0b6206ff6117778558d2fc5c7561faa5a43495';

/// Recording state machine (BR-01, BR-02, BR-03).
///
/// Integrates [SttSessionManager] for engine lifecycle and [WakeLockService]
/// to keep the screen on during captioning. Handles the one-attempt
/// auto-restart recovery flow (REL-U2.1) via the `reconnecting` state.
///
/// Invalid transitions are silently ignored (no exception, no error).
/// This prevents UI race conditions (e.g., user double-taps a button).
///
/// **Security (SR-01)**: No method may log, emit, or surface any text
/// content from speech recognition results. State transitions may be
/// logged at debug level; segment text may not appear in any log output.
///
/// Copied from [RecordingStateNotifier].
@ProviderFor(RecordingStateNotifier)
final recordingStateNotifierProvider =
    NotifierProvider<RecordingStateNotifier, RecordingState>.internal(
      RecordingStateNotifier.new,
      name: r'recordingStateNotifierProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$recordingStateNotifierHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$RecordingStateNotifier = Notifier<RecordingState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
