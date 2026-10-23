import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zip_core/src/models/overlay_position.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_core/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_core/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/src/output/overlay/overlay_window_mode.dart';
import 'package:zip_core/src/widgets/pop_out_window_body.dart';
import 'package:zip_core/zip_core.dart';

/// The fixed frame shown when the window was launched with a payload that does
/// not decode (ID-1, BR-U8.19).
///
/// It is deliberately plain: this frame has to render even when the launch
/// configuration, including the theme setting, is unavailable.
///
/// `zip_core` has no ARB, so the copy arrives as [message] from the app that
/// pumped the window (FD BLM §7 shape change 1). The default is the external
/// display's shipped wording.
class OverlayWindowUnavailableApp extends StatelessWidget {
  /// Creates an [OverlayWindowUnavailableApp].
  const OverlayWindowUnavailableApp({
    required this.message,
    super.key,
  });

  /// The one line this frame shows. Never caption text (BR-U8.1-09).
  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(
        backgroundColor: const Color(0xFF0B141D),
        body: Center(
          child: Text(
            message,
            style: const TextStyle(color: Color(0xFFDAE3F0)),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

/// Renders one caption window: the external display or the pop-out (F21).
///
/// Standby shows the surface and nothing else. Live shows the caption buffer
/// through the shipped [CaptionDisplayWidget], so the window looks exactly
/// like the on-screen one. Paused keeps the frozen buffer on screen; the
/// `__pause__` row travels as an ordinary entry, so no special case is needed
/// here.
///
/// The surface is opaque and its colours come from [AppTheme], never a
/// literal (BR-U8-20).
class OverlayWindowApp extends StatelessWidget {
  /// Creates an [OverlayWindowApp].
  const OverlayWindowApp({
    required this.launch,
    required this.snapshot,
    this.controls,
    this.onPopOutToggle,
    super.key,
  });

  /// The launch configuration and the first frame.
  final OverlayWindowLaunch launch;

  /// The current frame, replaced on every `captionUpdate`.
  final ValueListenable<CaptionOverlaySnapshot> snapshot;

  /// An optional control row rendered **outside** the scrolling list (R-M4).
  ///
  /// The external display passes nothing; the pop-out passes its in-surface
  /// toggle through [PopOutWindowBody].
  final Widget? controls;

  /// Invoked by [PopOutWindowBody]'s in-surface toggle.
  ///
  /// Only the pop-out uses it, and only the sub-engine's bridge implementation
  /// supplies it (`PopOutWindowBody`'s `onTogglePopOut`).
  final VoidCallback? onPopOutToggle;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CaptionOverlaySnapshot>(
      valueListenable: snapshot,
      builder: (context, frame, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: overlayThemeModeOf(frame.settings.themeModeSetting),
          home: launch.config.mode is PopOutMode
              ? PopOutWindowBody(
                  activity: frame.activity,
                  entries: frame.entries,
                  interim: frame.interim,
                  settings: frame.settings,
                  onTogglePopOut: onPopOutToggle,
                  toggleLabel:
                      launch.config.popOutToggleLabel ?? popOutWindowExitLabel,
                )
              : OverlayWindowBody(
                  activity: frame.activity,
                  entries: frame.entries,
                  interim: frame.interim,
                  settings: frame.settings,
                  position: launch.config.position,
                  controls: controls,
                ),
        );
      },
    );
  }
}

/// Maps a [ThemeModeSetting] onto Flutter's [ThemeMode].
///
/// One helper shared by both window bodies (FD frontend-components §7), so a
/// theme change cannot mean two different things in two windows.
ThemeMode overlayThemeModeOf(ThemeModeSetting setting) => switch (setting) {
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.system => ThemeMode.system,
    };

/// The external display's contents, split out so it can be tested without a
/// launch payload.
class OverlayWindowBody extends StatelessWidget {
  /// Creates an [OverlayWindowBody].
  const OverlayWindowBody({
    required this.activity,
    required this.entries,
    required this.interim,
    required this.settings,
    required this.position,
    this.controls,
    super.key,
  });

  /// What the session is doing, which decides whether captions are shown.
  final OverlayActivity activity;

  /// The final captions, oldest first.
  final List<CaptionDisplayEntry> entries;

  /// The trailing non-final caption, if any.
  final CaptionDisplayEntry? interim;

  /// The caption appearance settings.
  final DisplaySettings settings;

  /// Where the caption block sits on the display.
  final OverlayPosition position;

  /// An optional control row outside the scrolling list (R-M4).
  final Widget? controls;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = ColoredBox(
      color: scheme.surface,
      child: activity == OverlayActivity.standby
          ? const SizedBox.expand()
          : SafeArea(
              child: Align(
                alignment: position is OverlayPositionTop
                    ? Alignment.topCenter
                    : Alignment.bottomCenter,
                child: CaptionDisplayWidget(
                  entries: [...entries, ?interim],
                  settings: settings,
                  controls: controls,
                ),
              ),
            ),
    );
    return Scaffold(
      backgroundColor: scheme.surface,
      // Opaque on purpose: the display is shown to a room, not composited over
      // the desktop (BR-U8-20).
      body: body,
    );
  }
}
