import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/broadcast_session_state.dart';
import 'package:zip_broadcast/src/models/browser_source_start_exception.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/models/overlay_config.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_server.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_target.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_target.dart';
import 'package:zip_broadcast/src/output/overlay/caption_position.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_event.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
import 'package:zip_broadcast/src/providers/broadcast_recording_notifier.dart';
import 'package:zip_broadcast/src/providers/overlay_window_controller_provider.dart';
import 'package:zip_broadcast/src/providers/settings_notifier.dart';
import 'package:zip_broadcast/src/shell/zb_nav_drawer.dart';
import 'package:zip_broadcast/src/shell/zb_nav_rail.dart';
import 'package:zip_core/zip_core.dart';

/// Platform-adaptive shell for Zip Broadcast.
///
/// - Width > 768 px: persistent [ZbNavRail] on the left.
/// - Width ≤ 768 px: [AppBar] with hamburger + [ZbNavDrawer].
///
/// Owns [BrowserSourceTarget] and [CaptionOverlayTarget] as fields and
/// registers/deregisters them with [CaptionOutputTargetRegistry] as the
/// user toggles output targets (H1). OBS lifecycle is self-managed by
/// `ObsConnectionNotifier` (H2).
class ZbAppShell extends ConsumerStatefulWidget {
  /// Creates a [ZbAppShell].
  const ZbAppShell({required this.child, super.key});

  /// The current route's page widget.
  final Widget child;

  @override
  ConsumerState<ZbAppShell> createState() => _ZbAppShellState();
}

class _ZbAppShellState extends ConsumerState<ZbAppShell> {
  static const _desktopBreakpoint = 768.0;

  late final BrowserSourceTarget _browserSourceTarget;
  late final CaptionOverlayTarget _overlayTarget;
  late final CaptionOutputTargetRegistry _registry;

  bool _browserSourceRegistered = false;
  bool _browserSourceStarting = false;
  bool _browserSourceDesiredEnabled = false;
  bool _overlayRegistered = false;
  String? _overlayDisplayId;
  StreamSubscription<OverlayEvent>? _overlayEvents;

  @override
  void initState() {
    super.initState();
    _browserSourceTarget = BrowserSourceTarget(
      server: BrowserSourceServer(),
    );
    _overlayTarget = CaptionOverlayTarget(
      controller: ref.read(overlayWindowControllerProvider),
      registry: ref.read(captionOutputTargetRegistryProvider),
      displaySettings: () => ref.read(displaySettingsProvider),
    );
    _registry = ref.read(captionOutputTargetRegistryProvider);

    // BR-U8-15: the shell is what switches the output off when the window
    // goes away on its own. Display loss keeps the output on (D-4): the
    // controller waits for the saved display to come back.
    _overlayEvents = _overlayTarget.events.listen(_onOverlayEvent);

    // Register transcript target (always active).
    ref.read(transcriptWriterTargetProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTargets(ref.read(outputTargetSettingsNotifierProvider));
    });
  }

  /// Reacts to the controller's lifecycle events (BR-U8-15).
  void _onOverlayEvent(OverlayEvent event) {
    switch (event) {
      case WindowClosed():
      case OpenFailed():
        // Unregister and switch the output off, but do not send a toggle-off
        // close back to the controller: after `OpenFailed` the controller is
        // already `Failed` with no window, and that state is what the failure
        // banner renders (BR-U8-03).
        _unregisterOverlay();
        unawaited(_switchOverlayOff());
      case DisplayLost():
        // Bookkeeping only: the target stays registered, `overlayEnabled`
        // stays true, and the controller reopens on the saved display when
        // it returns (T11).
        // No state change: the target stays registered.
    }
  }

  void _unregisterOverlay() {
    if (!_overlayRegistered) return;
    _registry.remove(_overlayTarget);
    _overlayRegistered = false;
    _overlayDisplayId = null;
  }

  Future<void> _switchOverlayOff() async {
    if (!mounted) return;
    final notifier = ref.read(outputTargetSettingsNotifierProvider.notifier);
    final current = ref.read(outputTargetSettingsNotifierProvider);
    await notifier.update(current.copyWith(overlayEnabled: false));
  }

  @override
  void dispose() {
    unawaited(_overlayEvents?.cancel());
    _overlayEvents = null;
    _browserSourceDesiredEnabled = false;
    if (_browserSourceRegistered) {
      _registry.remove(_browserSourceTarget);
      unawaited(_browserSourceTarget.stop());
    } else if (_browserSourceStarting) {
      unawaited(_browserSourceTarget.stop());
    }
    if (_overlayRegistered) {
      _registry.remove(_overlayTarget);
      unawaited(_overlayTarget.hide());
    }
    super.dispose();
  }

  void _syncTargets(OutputTargetSettings settings) {
    _syncBrowserSource(
      settings.browserSourceEnabled,
      settings.browserSourcePort,
    );
    _syncOverlay(settings);
  }

  void _syncBrowserSource(bool enabled, int port) {
    _browserSourceDesiredEnabled = enabled;
    if (enabled && !_browserSourceRegistered && !_browserSourceStarting) {
      unawaited(_startBrowserSource(port));
    } else if (!enabled && _browserSourceRegistered) {
      _registry.remove(_browserSourceTarget);
      _browserSourceRegistered = false;
      unawaited(_browserSourceTarget.stop());
    }
  }

  void _syncOverlay(OutputTargetSettings settings) {
    final enabled = settings.overlayEnabled;
    final config = OverlayConfig(
      position: settings.externalDisplayCaptionPosition == CaptionPosition.top
          ? const OverlayPositionTop()
          : const OverlayPositionBottom(),
    );
    if (enabled && !_overlayRegistered) {
      _registry.add(_overlayTarget);
      _overlayRegistered = true;
      _overlayDisplayId = settings.externalDisplayId;
      // After the registry add, so the first snapshot already reads the
      // on-screen buffer. The launch carries the persisted caption position
      // and display selection (BR-U8-07, BR-U8-26); the controller resolves
      // the selection and never writes it back.
      unawaited(
        _overlayTarget.show(
          config,
          persistedDisplayId: settings.externalDisplayId,
        ),
      );
    } else if (enabled && settings.externalDisplayId != _overlayDisplayId) {
      // The broadcaster picked a different display while the output is on.
      // Closing first is what lets the controller accept the re-open (its
      // open guard refuses a second window); the window then opens on the new
      // display with the current position.
      _overlayDisplayId = settings.externalDisplayId;
      unawaited(
        _retarget(
          () => _overlayTarget.show(
            config,
            persistedDisplayId: settings.externalDisplayId,
          ),
        ),
      );
    } else if (!enabled) {
      // Only a window that still exists needs closing. After an open failure
      // the event handler has already unregistered and released it, and the
      // controller stays `Failed` so the banner can explain why (BR-U8-03).
      _unregisterOverlay();
      if (_overlayTarget.isVisible) unawaited(_overlayTarget.hide());
    }
  }

  /// Closes the open window, then applies [reopen].
  ///
  /// The close is skipped when there is no window: an open that failed leaves
  /// the controller `Failed` with nothing to close, and a toggle-off close
  /// would replace that state with `Off` (BR-U8-03).
  Future<void> _retarget(Future<void> Function() reopen) async {
    if (_overlayTarget.isVisible) await _overlayTarget.hide();
    if (!mounted || !_overlayRegistered) return;
    await reopen();
  }

  Future<void> _startBrowserSource(int port) async {
    _browserSourceStarting = true;
    try {
      await _browserSourceTarget.start(port: port);
      if (!_browserSourceDesiredEnabled || !mounted) {
        unawaited(_browserSourceTarget.stop());
        return;
      }
      _registry.add(_browserSourceTarget);
      _browserSourceRegistered = true;
    } on BrowserSourceStartException catch (e) {
      if (!mounted) return;
      final l10n = ZipBroadcastLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.browserSourceFailedToStart(e.reason)),
        ),
      );
    } finally {
      _browserSourceStarting = false;
    }
  }

  String _screenTitle(BuildContext context, String location) {
    final l10n = ZipBroadcastLocalizations.of(context)!;
    if (location == '/') return l10n.appTitleDefault;
    if (location == '/recording') return l10n.appTitleBroadcast;
    if (location == '/settings') return l10n.appTitleSettings;
    if (location == '/history') return l10n.appTitleHistory;
    if (location == '/audio-inputs') return l10n.appTitleAudioInputs;
    if (location == '/broadcast') return l10n.appTitleGoLive;
    return l10n.appTitleDefault;
  }

  /// Rule 9's sign-out guard (F-6.9): the sole call path to
  /// `authNotifierProvider.notifier.signOut()` within `zip_broadcast`.
  /// Refuses outright — the call is not made, not merely a disabled
  /// button — while `BroadcasterSessionState` is `StartingState`,
  /// `LiveState`, or `EndingState`.
  ///
  /// NFR Design Q2: the state read and the subsequent act (the `signOut()`
  /// call, or the refusal) happen in the same synchronous span — no
  /// `await` of any kind between them — so no concurrent `goLive()` can
  /// be interleaved between the check and the decision it makes.
  Future<void> _requestSignOut() async {
    final sessionState = ref.read(broadcastSessionNotifierProvider);
    if (sessionState is StartingState ||
        sessionState is LiveState ||
        sessionState is EndingState) {
      if (!mounted) return;
      final l10n = ZipBroadcastLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.broadcastSignOutRefused)),
      );
      return;
    }
    await ref.read(authNotifierProvider.notifier).signOut();
  }

  static int _railIndex(String location) {
    if (location == '/') return 0;
    if (location == '/recording') return 1;
    if (location == '/history') return 2;
    if (location == '/broadcast') return 3;
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
      case 3:
        return '/broadcast';
      default:
        return '/';
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<OutputTargetSettings>(
      outputTargetSettingsNotifierProvider,
      (prev, next) => _syncTargets(next),
    );

    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.of(context).size.width;
    final broadcastState = ref.watch(broadcastRecordingNotifierProvider);
    final isBroadcastActive = broadcastState is BroadcastActiveState ||
        broadcastState is BroadcastPausedState ||
        broadcastState is BroadcastReconnectingState;

    final Widget content;
    if (width > _desktopBreakpoint) {
      content = Row(
        children: [
          ZbNavRail(
            selectedIndex: _railIndex(location),
            onDestinationSelected: (i) {
              final destination = _railDestination(i);
              if (destination == location) return;
              context.go(destination);
            },
            onSettingsTap: () {
              if (location == '/settings') return;
              context.go('/settings');
            },
            isBroadcastActive: isBroadcastActive,
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
        ],
      );
    } else {
      content = BackButtonListener(
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
            title: Text(_screenTitle(context, location)),
            leading: Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
          ),
          body: widget.child,
          drawer: ZbNavDrawer(
            currentLocation: location,
            onTap: (route) {
              context.go(route);
              Navigator.of(context).pop();
            },
            isBroadcastActive: isBroadcastActive,
          ),
        ),
      );
    }

    return ZbSignOutScope(requestSignOut: _requestSignOut, child: content);
  }
}

/// Exposes [ZbAppShell]'s Rule 9 sign-out guard to descendants —
/// `AccountSection`'s sign-out button reaches it via [ZbSignOutScope.of]
/// instead of calling `authNotifierProvider.notifier.signOut()` directly
/// (Functional Design Q6).
class ZbSignOutScope extends InheritedWidget {
  /// Creates a [ZbSignOutScope] wrapping [child].
  const ZbSignOutScope({
    required this.requestSignOut,
    required super.child,
    super.key,
  });

  /// `_ZbAppShellState._requestSignOut`, bound to the current shell
  /// instance.
  final Future<void> Function() requestSignOut;

  /// Requests sign-out. Refuses (shows feedback, never calls `signOut()`)
  /// while the broadcast session is non-idle (`business-rules.md` Rule 9).
  static Future<void> of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ZbSignOutScope>();
    assert(scope != null, 'No ZbSignOutScope found in context');
    return scope!.requestSignOut();
  }

  @override
  bool updateShouldNotify(ZbSignOutScope oldWidget) =>
      oldWidget.requestSignOut != requestSignOut;
}
