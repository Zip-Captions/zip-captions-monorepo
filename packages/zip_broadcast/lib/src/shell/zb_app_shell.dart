import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zip_broadcast/src/l10n/zip_broadcast_localizations.dart';
import 'package:zip_broadcast/src/models/browser_source_start_exception.dart';
import 'package:zip_broadcast/src/models/output_target_settings.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_server.dart';
import 'package:zip_broadcast/src/output/browser_source/browser_source_target.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_target.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';
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

  @override
  void initState() {
    super.initState();
    _browserSourceTarget = BrowserSourceTarget(
      server: BrowserSourceServer(),
    );
    _overlayTarget = CaptionOverlayTarget();
    _registry = ref.read(captionOutputTargetRegistryProvider);

    // Register transcript target (always active).
    ref.read(transcriptWriterTargetProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncTargets(ref.read(outputTargetSettingsNotifierProvider));
    });
  }

  @override
  void dispose() {
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
    _syncOverlay(settings.overlayEnabled);
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

  void _syncOverlay(bool enabled) {
    if (enabled && !_overlayRegistered) {
      _registry.add(_overlayTarget);
      _overlayRegistered = true;
    } else if (!enabled && _overlayRegistered) {
      _registry.remove(_overlayTarget);
      _overlayRegistered = false;
      unawaited(_overlayTarget.hide());
    }
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
    return l10n.appTitleDefault;
  }

  static int _railIndex(String location) {
    if (location == '/') return 0;
    if (location == '/recording') return 1;
    if (location == '/history') return 2;
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
    ref.listen<OutputTargetSettings>(
      outputTargetSettingsNotifierProvider,
      (prev, next) => _syncTargets(next),
    );

    final location = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.of(context).size.width;

    if (width > _desktopBreakpoint) {
      return Row(
        children: [
          ZbNavRail(
            selectedIndex: _railIndex(location),
            onDestinationSelected: (i) => context.go(_railDestination(i)),
            onSettingsTap: () => context.go('/settings'),
            onAudioInputsTap: () => context.go('/audio-inputs'),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: widget.child),
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
        ),
      ),
    );
  }
}
