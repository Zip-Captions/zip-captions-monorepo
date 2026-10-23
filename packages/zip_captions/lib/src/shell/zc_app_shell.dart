import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_captions/src/l10n/zc_strings.dart';
import 'package:zip_captions/src/output/overlay/pop_out_caption_target.dart';
import 'package:zip_captions/src/providers/pop_out_providers.dart';
import 'package:zip_captions/src/providers/settings_notifier.dart';
import 'package:zip_captions/src/shell/zc_nav_drawer.dart';
import 'package:zip_captions/src/shell/zc_nav_rail.dart';
import 'package:zip_captions/src/widgets/pop_out_controls.dart';
import 'package:zip_captions/src/widgets/pop_out_scope.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

/// Platform-adaptive shell wrapping all routed screens with navigation chrome.
///
/// - Width > 768px: persistent [ZcNavRail] on the left.
/// - Width ≤ 768px: [AppBar] with hamburger + [ZcNavDrawer] on every screen.
class ZcAppShell extends ConsumerStatefulWidget {
  /// Creates a [ZcAppShell].
  const ZcAppShell({required this.child, super.key});

  /// The current route's page widget.
  final Widget child;

  @override
  ConsumerState<ZcAppShell> createState() => _ZcAppShellState();
}

class _ZcAppShellState extends ConsumerState<ZcAppShell> {
  static const _desktopBreakpoint = 768.0;

  late final PopOutCaptionTarget _popOutTarget;
  StreamSubscription<OverlayEvent>? _popOutEvents;

  // Q10 B: no persisted key and no settings write on any pop-out path, so the
  // flag is a pure function of this state and the controller's status.
  bool _popOutEnabled = false;

  @override
  void initState() {
    super.initState();
    _popOutTarget = PopOutCaptionTarget(
      controller: ref.read(popOutWindowControllerProvider),
      registry: ref.read(captionOutputTargetRegistryProvider),
      displaySettings: () => ref.read(displaySettingsProvider),
    );
    _popOutEvents = _popOutTarget.events.listen(_onPopOutEvent);
  }

  /// Every lifecycle event ends the popped-out state (BR-PIP-03): the window
  /// is gone or it never opened, and the banner must go with it.
  void _onPopOutEvent(OverlayEvent event) {
    switch (event) {
      case WindowClosed():
      case OpenFailed():
        _setPoppedOut(false);
      case DisplayLost():
        // A pop-out is never framed to a display, so it cannot lose one.
        break;
      case PopOutToggled():
        // The pop-out's in-surface toggle (FD BLM §3.3) asks to leave. The
        // shell owns the flag, so it closes through the same `_togglePopOut`
        // path the chrome toggle and the banner use. Closing needs no
        // geometry, so the shell's captured context is not needed here.
        _closePopOut();
    }
  }

  /// Maps the app's recording state onto the availability rule's vocabulary.
  static RecordingState _popOutRecordingState(RecordingState state) => state;

  /// Ends the popped-out state and the window behind it: the close half of
  /// `_togglePopOut`, for callers with no `BuildContext`.
  void _closePopOut() {
    _setPoppedOut(false);
    ref.read(captionOutputTargetRegistryProvider).remove(_popOutTarget);
    unawaited(_popOutTarget.hide());
  }

  void _setPoppedOut(bool value) {
    if (_popOutEnabled == value) return;
    if (!mounted) return;
    setState(() => _popOutEnabled = value);
  }

  /// The chrome toggle, the in-surface toggle and the banner's return all end
  /// up here (UX-PIP-01, UX-PIP-02, UX-PIP-05).
  void _togglePopOut(BuildContext context) {
    if (_popOutEnabled) {
      _closePopOut();
      return;
    }
    final controller = ref.read(popOutWindowControllerProvider);
    if (controller.status is Opening || controller.status is Open) return;
    final geometry = popOutFrameFor(
      context: context,
      displays: ref.read(displayListProvider).value ?? const <DisplayInfo>[],
      settings: ref.read(displaySettingsProvider),
    );
    _setPoppedOut(true);
    ref.read(captionOutputTargetRegistryProvider).add(_popOutTarget);
    unawaited(
      _popOutTarget.show(
        const OverlayConfig(mode: PopOutMode()),
        frame: geometry.displayId == null ? null : geometry.frame,
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_popOutEvents?.cancel());
    _popOutEvents = null;
    if (_popOutEnabled) {
      ref.read(captionOutputTargetRegistryProvider).remove(_popOutTarget);
      unawaited(_popOutTarget.hide());
    }
    super.dispose();
  }

  static String _screenTitle(String location, {ZcStrings? strings}) {
    if (location == '/') return 'Zip Captions';
    if (location == '/recording') return 'Caption';
    if (location == '/settings') return 'Settings';
    if (location == '/join') {
      return strings?.joinBroadcastSubmit ?? 'Join';
    }
    if (location == '/history') return 'History';
    if (location.startsWith('/history/')) return 'Transcript';
    return 'Zip Captions';
  }

  /// Maps the current location to a rail index. Returns -1 for non-rail
  /// screens (Settings, TranscriptViewer).
  static int _railIndex(String location) {
    if (location == '/') return 0;
    if (location == '/recording') return 1;
    if (location == '/history' || location.startsWith('/history/')) return 2;
    return -1;
  }

  static String _railDestination(int index) {
    switch (index) {
      case 0:
        return '/';
      case 1:
        return '/recording';
      case 2:
        return '/history';
      default:
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Keep transcriptWriterTargetProvider subscribed so it rebuilds eagerly
    // when captureEnabled changes (e.g. user re-enables Save Transcripts).
    ref.watch(transcriptWriterTargetProvider);

    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.of(context).size.width;
    final strings = ref.watch(zcStringsProvider).valueOrNull;
    final recording = ref.watch(recordingStateNotifierProvider);
    final popOutStatus = ref.watch(popOutWindowControllerProvider).status;
    final engineAvailable = ref.watch(captionsEngineAvailableProvider);

    // The copy is loaded from the ARB before the shell renders its chrome, so
    // the pop-out widgets can read it non-nullably through `PopOutScope`.
    if (strings == null) return widget.child;

    final recordingState = _popOutRecordingState(recording);
    final availability = popOutAvailability(
      status: popOutStatus,
      recording: recordingState,
      engineAvailable: engineAvailable,
    );
    final chrome = PopOutChrome(
      status: popOutStatus,
      recording: recordingState,
      engineAvailable: engineAvailable,
      isPoppedOut: _popOutEnabled,
      onToggle: () => _togglePopOut(context),
    );

    return PopOutScope(
      enabled: _popOutEnabled,
      onToggle: () => _togglePopOut(context),
      available: availability.enabled,
      strings: strings,
      child: _buildScaffold(context, location, width, strings, chrome),
    );
  }

  Widget _buildScaffold(
    BuildContext context,
    String location,
    double width,
    ZcStrings strings,
    Widget chrome,
  ) {
    final child = widget.child;
    if (width > _desktopBreakpoint) {
      return Row(
        children: [
          ZcNavRail(
            selectedIndex: _railIndex(location),
            onDestinationSelected: (i) => context.go(_railDestination(i)),
            onSettingsTap: () => context.go('/settings'),
            headerAction: chrome,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: child),
        ],
      );
    }

    return BackButtonListener(
      onBackButtonPressed: () async {
        if (location == '/') return false;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
        } else {
          context.go('/');
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_screenTitle(location, strings: strings)),
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
            ),
          ),
          actions: [chrome],
        ),
        body: child,
        drawer: ZcNavDrawer(
          currentLocation: location,
          onTap: (route) {
            context.go(route);
            Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}
