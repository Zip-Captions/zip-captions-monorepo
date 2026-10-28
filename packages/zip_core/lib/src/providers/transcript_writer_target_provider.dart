import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/recording_state.dart';
import 'package:zip_core/src/output/transcript_writer_target.dart';
import 'package:zip_core/src/providers/caption_output_target_registry_provider.dart';
import 'package:zip_core/src/providers/recording_state_notifier.dart';
import 'package:zip_core/src/providers/session_stop_callback_provider.dart';
import 'package:zip_core/src/providers/transcript_providers.dart';
import 'package:zip_core/src/providers/transcript_save_outcome_provider.dart';

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
  final stopCallback = ref.read(sessionStopCallbackProvider);
  // The target owns the outcome's lifetime (Step 29b): it records the
  // session's result on stop and forgets it when the next session starts, so
  // RecordingScreen only ever reads its own session's value and never has to
  // write to the provider from inside its Stopped listener.
  final target = TranscriptWriterTarget(
    repository: repo,
    settings: settings,
    onSaveOutcome: (saved) {
      // The provider may be replayed from its own build (a capture toggle
      // mid-session), and a provider must not write another during its own
      // initialisation. The write is the same either way, so let the current
      // stack unwind first.
      unawaited(
        Future<void>.microtask(() {
          ref.read(transcriptSaveOutcomeProvider.notifier).record(saved);
        }),
      );
    },
  );
  registry.add(target);

  // Register finalize callback so RecordingStateNotifier can await it.
  // The save outcome (Q-2) is written to [transcriptSaveOutcomeProvider]
  // before the stopped state is published, so RecordingScreen can tell a
  // saved session from one that captioned nothing.
  stopCallback.callback = () async {
    final saved = await target.finalizeCurrentSession();
    ref.read(transcriptSaveOutcomeProvider.notifier).record(saved);
  };

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
    stopCallback.callback = null;
  });
});
