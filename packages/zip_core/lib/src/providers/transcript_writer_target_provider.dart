import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/output/transcript_writer_target.dart';
import 'package:zip_core/src/providers/caption_output_target_registry_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/transcript_providers.dart';

/// Registers a [TranscriptWriterTarget] with
/// [captionOutputTargetRegistryProvider] whenever transcript capture is
/// enabled, and wires [sessionStopCallbackProvider] so that
/// [RecordingStateNotifier.stop] can await finalization before emitting
/// [StoppedState].
///
/// Kept alive for the app lifetime. Rebuilds when [TranscriptSettingsNotifier]
/// changes (e.g. user toggles "Save transcripts"); on each rebuild the
/// previous target is disposed and deregistered before the new one is created.
///
/// Requires [transcriptRepositoryProvider] to already be in
/// `AsyncValue.data` state when this provider is first read — call
/// `await container.read(transcriptRepositoryProvider.future)` in `main.dart`
/// before reading this provider.
final transcriptWriterTargetProvider = Provider<void>((ref) {
  final settings = ref.watch(transcriptSettingsNotifierProvider);
  if (!settings.captureEnabled) {
    ref.read(sessionStopCallbackProvider).callback = null;
    return;
  }

  final repo = ref.watch(transcriptRepositoryProvider).valueOrNull;
  if (repo == null) return;

  final registry = ref.read(captionOutputTargetRegistryProvider);
  final target = TranscriptWriterTarget(repository: repo, settings: settings);
  registry.add(target);

  // Register finalize callback so RecordingStateNotifier can await it.
  ref.read(sessionStopCallbackProvider).callback =
      target.finalizeCurrentSession;

  // If saving is re-enabled while a session is already active, replay the
  // session-start event so the target initialises and captures remaining
  // segments. createSession uses insertOnConflictUpdate, so replaying is safe.
  final currentState = ref.read(recordingStateNotifierProvider);
  if (currentState is RecordingActiveState ||
      currentState is PausedState ||
      currentState is ReconnectingState) {
    target.onCaptionEvent(
      SessionStateEvent(
        RecordingState.recording(
          sessionId: (currentState as ActiveSessionState).sessionId,
        ),
      ),
    );
  }

  ref.onDispose(() {
    registry.remove(target);
    ref.read(sessionStopCallbackProvider).callback = null;
  });
});
