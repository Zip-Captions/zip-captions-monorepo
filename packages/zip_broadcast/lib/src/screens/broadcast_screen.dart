import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/audio_input_config.dart';
import 'package:zip_broadcast/src/models/audio_input_visual_style.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart'
    as recording;
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';
import 'package:zip_broadcast/src/providers/audio_level_provider.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/widgets/output_targets_panel.dart';
import 'package:zip_core/zip_core.dart'
    hide AudioInputConfig, AudioInputVisualStyle;

/// The Broadcast UI (S-17) — one route whose content switches on
/// [BroadcasterSessionState] (Functional Design Q8): the setup form while
/// [OfflineState]/[StartingState]/[BroadcastFailedState], the live
/// dashboard while [LiveState]/[EndingState].
class BroadcastScreen extends ConsumerWidget {
  /// Creates a [BroadcastScreen].
  const BroadcastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(broadcastSessionNotifierProvider);
    return switch (sessionState) {
      LiveState(:final broadcast) => _LiveDashboardView(broadcast: broadcast),
      EndingState() => const Center(child: CircularProgressIndicator()),
      OfflineState() ||
      StartingState() ||
      BroadcastFailedState() => const _SetupView(),
    };
  }
}

// ---------------------------------------------------------------------------
// Setup view (F-6.1)
// ---------------------------------------------------------------------------

class _SetupView extends ConsumerStatefulWidget {
  const _SetupView();

  @override
  ConsumerState<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<_SetupView> {
  late final TextEditingController _nameController;
  Future<BroadcastId>? _idFuture;
  bool _idFetchedWhileSignedIn = false;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(broadcastSettingsNotifierProvider);
    _nameController = TextEditingController(text: settings.sessionName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _maybeFetchId(bool signedIn) {
    if (!signedIn || _idFetchedWhileSignedIn) return;
    _idFetchedWhileSignedIn = true;
    _idFuture = ref.read(broadcastIdentityRepositoryProvider).getOrCreateMine();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final settings = ref.watch(broadcastSettingsNotifierProvider);
    final authState = ref.watch(authNotifierProvider);
    final sessionState = ref.watch(broadcastSessionNotifierProvider);
    final signedIn = authState is SignedInState;
    _maybeFetchId(signedIn);

    ref.listen<BroadcastSettings>(broadcastSettingsNotifierProvider, (
      prev,
      next,
    ) {
      if (next.sessionName != _nameController.text) {
        _nameController.text = next.sessionName;
      }
    });

    final nameError = BroadcastSettings.validateSessionName(
      settings.sessionName,
    );
    final isStarting = sessionState is StartingState;
    final failure = sessionState is BroadcastFailedState
        ? sessionState.reason
        : null;

    return Scaffold(
      body: Stack(
        children: [
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.homeOutputTargets,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const OutputTargetsPanel(),
                  const SizedBox(height: 24),
                  TextField(
                    key: const Key('broadcast-session-name-field'),
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: l10n.broadcastSessionNameLabel,
                      border: const OutlineInputBorder(),
                      errorText: switch (nameError) {
                        SessionNameError.empty =>
                          l10n.broadcastSessionNameErrorEmpty,
                        SessionNameError.tooLong =>
                          l10n.broadcastSessionNameErrorTooLong,
                        SessionNameError.controlChar =>
                          l10n.broadcastSessionNameErrorControlChar,
                        null => null,
                      },
                    ),
                    onChanged: (value) => unawaited(
                      ref
                          .read(broadcastSettingsNotifierProvider.notifier)
                          .updateSessionName(value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('broadcast-auto-start-switch'),
                    title: Text(l10n.broadcastAutoStartCaptioning),
                    value: settings.autoStartCaptioning,
                    onChanged: (v) => unawaited(
                      ref
                          .read(broadcastSettingsNotifierProvider.notifier)
                          .setAutoStartCaptioning(autoStartCaptioning: v),
                    ),
                  ),
                  if (signedIn) ...[
                    const SizedBox(height: 16),
                    _BroadcastUrlRow(idFuture: _idFuture, l10n: l10n),
                  ],
                  const SizedBox(height: 24),
                  if (failure != null)
                    _FailureCard(failure: failure, l10n: l10n),
                  const SizedBox(height: 8),
                  FilledButton(
                    key: const Key('broadcast-go-live-button'),
                    onPressed: (isStarting || !signedIn || nameError != null)
                        ? null
                        : () => unawaited(
                            ref
                                .read(broadcastSessionNotifierProvider.notifier)
                                .goLive(),
                          ),
                    child: isStarting
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.broadcastGoingLive),
                            ],
                          )
                        : Text(l10n.broadcastGoLiveAction),
                  ),
                ],
              ),
            ),
          ),
          if (!signedIn) _SignedOutOverlay(l10n: l10n),
        ],
      ),
    );
  }
}

class _BroadcastUrlRow extends StatelessWidget {
  const _BroadcastUrlRow({required this.idFuture, required this.l10n});

  final Future<BroadcastId>? idFuture;
  final ZipBroadcastLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final future = idFuture;
    if (future == null) return const SizedBox.shrink();
    return FutureBuilder<BroadcastId>(
      future: future,
      builder: (context, snapshot) {
        final id = snapshot.data;
        if (id == null) return const SizedBox.shrink();
        final url = BroadcastLink.toUrl(id).toString();
        return Card(
          key: const Key('broadcast-url-row'),
          child: ListTile(
            title: Text(l10n.broadcastUrlLabel),
            subtitle: Text(url),
            trailing: TextButton(
              key: const Key('broadcast-url-copy-button'),
              onPressed: () {
                unawaited(Clipboard.setData(ClipboardData(text: url)));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.broadcastUrlCopied)),
                );
              },
              child: Text(l10n.broadcastUrlCopyAction),
            ),
          ),
        );
      },
    );
  }
}

class _SignedOutOverlay extends StatelessWidget {
  const _SignedOutOverlay({required this.l10n});

  final ZipBroadcastLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        child: Center(
          child: Card(
            key: const Key('broadcast-signed-out-overlay'),
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.broadcastSignedOutTitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.broadcastSignedOutCopy,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure, required this.l10n});

  final BroadcastFailure failure;
  final ZipBroadcastLocalizations l10n;

  String _message(BroadcastFailure failure) => switch (failure) {
    BroadcastFailure.signedOut => l10n.broadcastFailureSignedOut,
    BroadcastFailure.signalingUnavailable =>
      l10n.broadcastFailureSignalingUnavailable,
    BroadcastFailure.relayUnavailable => l10n.broadcastFailureRelayUnavailable,
    BroadcastFailure.identityUnavailable =>
      l10n.broadcastFailureIdentityUnavailable,
    BroadcastFailure.unknown => l10n.broadcastFailureUnknown,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('broadcast-failure-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.broadcastFailedTitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _message(failure),
            style: TextStyle(
              color: Theme.of(context).colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Live dashboard view (F-6.5)
// ---------------------------------------------------------------------------

class _LiveDashboardView extends ConsumerWidget {
  const _LiveDashboardView({required this.broadcast});

  final LiveBroadcast broadcast;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final recordingState = ref.watch(broadcastRecordingNotifierProvider);
    final configs = ref.watch(audioInputConfigNotifierProvider);
    final audioLevels = ref.watch(audioLevelProvider);
    final isFull = broadcast.viewers.length == broadcast.maxViewers;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.broadcastDashboardTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      key: const Key('broadcast-viewer-count-stat'),
                      label: l10n.broadcastViewerCount(
                        broadcast.viewers.length,
                        broadcast.maxViewers,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _DurationStatCard(
                      key: const Key('broadcast-duration-stat'),
                      startedAt: broadcast.startedAt,
                      label: l10n.broadcastDurationLabel,
                    ),
                  ),
                ],
              ),
              if (isFull) ...[
                const SizedBox(height: 12),
                _InfoBanner(
                  key: const Key('broadcast-full-banner'),
                  text: l10n.broadcastFullBanner(broadcast.maxViewers),
                ),
              ],
              _CaptionActivityBanner(
                activity: broadcast.captionActivity,
                l10n: l10n,
              ),
              const SizedBox(height: 16),
              _CaptionPreview(l10n: l10n),
              const SizedBox(height: 16),
              _CaptioningControls(recordingState: recordingState, l10n: l10n),
              const SizedBox(height: 16),
              Text(
                l10n.homeAudioInputs,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final config in configs)
                _AudioInputRow(
                  config: config,
                  level: audioLevels[config.deviceId] ?? 0,
                  recordingState: recordingState,
                ),
              const SizedBox(height: 16),
              Text(
                '${l10n.broadcastViewers} · ${broadcast.viewers.length}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final viewer in broadcast.viewers)
                ListTile(
                  key: Key('broadcast-viewer-${viewer.peerId}'),
                  leading: const Icon(Icons.person),
                  title: Text(viewer.peerId),
                  trailing: Text(viewer.connectionType.name),
                ),
              const SizedBox(height: 24),
              OutlinedButton(
                key: const Key('broadcast-end-button'),
                onPressed: () => unawaited(
                  ref
                      .read(broadcastSessionNotifierProvider.notifier)
                      .endBroadcast(),
                ),
                child: Text(l10n.broadcastEndAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ),
    );
  }
}

class _DurationStatCard extends StatefulWidget {
  const _DurationStatCard({
    required this.startedAt,
    required this.label,
    super.key,
  });

  final DateTime startedAt;
  final String label;

  @override
  State<_DurationStatCard> createState() => _DurationStatCardState();
}

class _DurationStatCardState extends State<_DurationStatCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = DateTime.now().difference(widget.startedAt);
    final h = elapsed.inHours.toString().padLeft(2, '0');
    final m = (elapsed.inMinutes % 60).toString().padLeft(2, '0');
    final s = (elapsed.inSeconds % 60).toString().padLeft(2, '0');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          '${widget.label}: $h:$m:$s',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text),
    );
  }
}

class _CaptionActivityBanner extends StatefulWidget {
  const _CaptionActivityBanner({required this.activity, required this.l10n});

  final CaptionActivity activity;
  final ZipBroadcastLocalizations l10n;

  @override
  State<_CaptionActivityBanner> createState() => _CaptionActivityBannerState();
}

class _CaptionActivityBannerState extends State<_CaptionActivityBanner> {
  bool _everActive = false;

  @override
  void didUpdateWidget(_CaptionActivityBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activity == CaptionActivity.active) _everActive = true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.activity == CaptionActivity.active) {
      return const SizedBox.shrink();
    }
    // `paused` always uses the "not running" copy (F-6.4 banner matrix) —
    // only `inactive` distinguishes "never started" from "stopped after
    // having been active" based on history.
    final text = widget.activity == CaptionActivity.paused || _everActive
        ? widget.l10n.broadcastCaptionsNotRunning
        : widget.l10n.broadcastCaptionsNeverStarted;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: _InfoBanner(
        key: const Key('broadcast-captions-banner'),
        text: text,
      ),
    );
  }
}

class _CaptionPreview extends ConsumerStatefulWidget {
  const _CaptionPreview({required this.l10n});

  final ZipBroadcastLocalizations l10n;

  @override
  ConsumerState<_CaptionPreview> createState() => _CaptionPreviewState();
}

class _CaptionPreviewState extends ConsumerState<_CaptionPreview> {
  String? _latestText;
  StreamSubscription<CaptionEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(captionBusProvider).stream.listen((event) {
      if (event is SttResultEvent && mounted) {
        setState(() => _latestText = event.result.text);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('broadcast-caption-preview'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(_latestText ?? widget.l10n.broadcastCaptionPreviewEmpty),
      ),
    );
  }
}

class _CaptioningControls extends ConsumerWidget {
  const _CaptioningControls({required this.recordingState, required this.l10n});

  final recording.BroadcastSessionState recordingState;
  final ZipBroadcastLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(broadcastRecordingNotifierProvider.notifier);
    return switch (recordingState) {
      recording.BroadcastIdleState() => FilledButton(
        key: const Key('broadcast-start-captioning-button'),
        onPressed: () => unawaited(notifier.start()),
        child: Text(l10n.broadcastStartCaptioningAction),
      ),
      recording.BroadcastActiveState() => OutlinedButton(
        key: const Key('broadcast-pause-captioning-button'),
        onPressed: () => unawaited(notifier.pause()),
        child: Text(l10n.broadcastPauseCaptioningAction),
      ),
      recording.BroadcastPausedState() => FilledButton(
        key: const Key('broadcast-resume-captioning-button'),
        onPressed: () => unawaited(notifier.resume()),
        child: Text(l10n.broadcastResumeCaptioningAction),
      ),
      recording.BroadcastReconnectingState() ||
      recording.BroadcastStoppedState() => const SizedBox.shrink(),
    };
  }
}

class _AudioInputRow extends StatelessWidget {
  const _AudioInputRow({
    required this.config,
    required this.level,
    required this.recordingState,
  });

  final AudioInputConfig config;
  final double level;
  final recording.BroadcastSessionState recordingState;

  String _status(
    recording.BroadcastSessionState state,
    ZipBroadcastLocalizations l10n,
  ) {
    final perEngine = switch (state) {
      recording.BroadcastActiveState(:final perEngineStates) => perEngineStates,
      recording.BroadcastPausedState(:final perEngineStates) => perEngineStates,
      _ => const <String, recording.EngineSessionState>{},
    };
    final engineState = perEngine[config.deviceId];
    return switch (engineState) {
      recording.EngineActiveState() => l10n.broadcastAudioInputStatusActive,
      recording.EngineErrorState() => l10n.broadcastAudioInputStatusError,
      null => l10n.broadcastAudioInputStatusInactive,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    final style = AudioInputVisualStyle.forIndex(config.colorIndex);
    return ListTile(
      leading: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(color: style.accent, shape: BoxShape.circle),
      ),
      title: Text(config.label.isNotEmpty ? config.label : config.name),
      subtitle: Text(
        '${_status(recordingState, l10n)} · ${(level * 100).round()}%',
      ),
      dense: true,
    );
  }
}
