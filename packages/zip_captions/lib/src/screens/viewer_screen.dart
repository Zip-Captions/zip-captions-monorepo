import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_captions/src/widgets/viewer_status_presenter.dart';
import 'package:zip_captions/src/widgets/viewer_status_region.dart';
import 'package:zip_core/zip_core.dart';

/// The viewer screen (F-7.1-F-7.9): joins a broadcast, shows the status
/// region plus the remote captions, and leaves on explicit user action.
///
/// Navigation-resilient: the session is owned by the app-lifetime
/// [viewerSessionNotifierProvider], so this screen only reflects it and
/// re-joins on entry (F-7.2). It never manipulates `transport` itself.
class ViewerScreen extends ConsumerStatefulWidget {
  /// Creates the viewer screen.
  const ViewerScreen({
    required this.broadcastId,
    this.initialBroadcastId,
    super.key,
  });

  /// The route name, used by the join screen after parsing.
  static const routeName = 'viewer';

  /// The route path pattern.
  static const routePath = '/b/:broadcastId';

  /// The broadcast ID from the route path.
  final String broadcastId;

  /// An ID already parsed by the join screen; `null` for deep-link entry,
  /// where the route segment is parsed again by the notifier.
  final BroadcastId? initialBroadcastId;

  @override
  ConsumerState<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends ConsumerState<ViewerScreen> {
  StreamSubscription<CaptionEvent>? _captions;

  /// The bus [_captions] listens to: a new session allocates a fresh bus, so
  /// identity (not nullness) decides when to re-arm (Rule 7).
  CaptionBus? _watchingBus;

  ViewerSessionNotifier? _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(viewerSessionNotifierProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        _notifier!.join(widget.initialBroadcastId?.value ?? widget.broadcastId),
      );
    });
  }

  @override
  void dispose() {
    unawaited(_captions?.cancel());
    super.dispose();
  }

  void _watchViewerBus(CaptionBus? bus) {
    if (bus == null || identical(bus, _watchingBus)) return;
    unawaited(_captions?.cancel());
    _watchingBus = bus;
    _captions = bus.stream.listen((_) => _syncCaptions());
  }

  void _syncCaptions() {
    if (!mounted) return;
    setState(() {});
  }

  void _retry() {
    // A failed resolution intentionally leaves `currentBroadcastId` unset, so
    // the retry re-enters from the ID the route was opened with.
    unawaited(
      _notifier?.join(widget.initialBroadcastId?.value ?? widget.broadcastId),
    );
  }

  /// Leaves with confirmation while a session can still emit captions, and
  /// immediately from every terminal state (Rule 9).
  ///
  /// Returns whether the screen handled the request. A dismissed dialog
  /// leaves it unhandled so the platform gesture keeps its usual meaning
  /// (asking again, or popping) instead of being swallowed.
  Future<bool> _confirmLeave() async {
    final current = ref.read(viewerSessionNotifierProvider);
    final needsConfirmation =
        current is ResolvingState ||
        current is ConnectingState ||
        current is LiveViewState ||
        current is ViewerReconnectingState;

    if (needsConfirmation) {
      final confirmed = await _showLeaveDialog();
      if (confirmed != true) return false;
    }

    await _notifier?.leave();
    if (!mounted) return true;
    context.go('/');
    return true;
  }

  Future<bool?> _showLeaveDialog() async {
    final strings = ref.read(zcStringsProvider).valueOrNull;
    if (strings == null) return null;
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(strings.confirmLeaveTitle),
        content: Text(strings.confirmLeaveBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.confirmLeaveCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.confirmLeaveConfirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(zcStringsProvider);
    final viewer = ref.watch(viewerSessionNotifierProvider);
    final sessionName = ref
        .read(viewerSessionNotifierProvider.notifier)
        .sessionName;

    return status.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      data: (strings) {
        final presentation = presentViewerState(
          viewer,
          strings,
          sessionName: sessionName,
        );
        final notifier = ref.read(viewerSessionNotifierProvider.notifier);
        _watchViewerBus(notifier.viewerBus);

        final captions =
            notifier.viewerCaptionTarget?.visibleCaptions ??
            const <CaptionDisplayEntry>[];

        return BackButtonListener(
          onBackButtonPressed: _confirmLeave,
          child: Scaffold(
            appBar: AppBar(
              title: Text(strings.viewerTitle),
              actions: [
                TextButton(
                  onPressed: () => unawaited(_confirmLeave()),
                  child: Text(strings.viewerLeave),
                ),
              ],
            ),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: ViewerStatusRegion(
                    state: viewer,
                    text: presentation.title,
                    body: presentation.body,
                  ),
                ),
                if (isCaptionActivityPaused(viewer))
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      strings.captionsPausedNotice,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                if (presentation.canRetry)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: OutlinedButton(
                        onPressed: _retry,
                        child: Text(strings.tryAgain),
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: CaptionDisplayWidget(
                    entries: captions,
                    settings: ref.watch(displaySettingsProvider),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
