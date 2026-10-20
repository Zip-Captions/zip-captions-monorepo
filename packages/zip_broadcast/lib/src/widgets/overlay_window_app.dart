import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:zip_broadcast/src/models/overlay_position.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_codec.dart';
import 'package:zip_broadcast/src/output/overlay/caption_overlay_snapshot.dart';
import 'package:zip_broadcast/src/output/overlay/overlay_activity.dart';
import 'package:zip_core/zip_core.dart';

/// The fixed frame shown when the window was launched with a payload that does
/// not decode (ID-1, BR-U8-19).
///
/// It is deliberately plain: this frame has to render even when the launch
/// configuration — including the theme setting — is unavailable.
class OverlayWindowUnavailableApp extends StatelessWidget {
  /// Creates an [OverlayWindowUnavailableApp].
  const OverlayWindowUnavailableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF0B141D),
        body: Center(
          child: Text(
            'Window unavailable',
            style: const TextStyle(color: Color(0xFFDAE3F0)),
            textScaler: MediaQuery.textScalerOf(context),
          ),
        ),
      ),
    );
  }
}

/// Renders one external display window (F21).
///
/// Standby shows the surface and nothing else. Live shows the caption buffer
/// through the shipped [CaptionDisplayWidget], so the external display looks
/// exactly like the on-screen one. Paused keeps the frozen buffer on screen;
/// the `__pause__` row travels as an ordinary entry, so no special case is
/// needed here.
///
/// The surface is opaque and its colours come from `AppTheme`, never a
/// literal (BR-U8-20).
class OverlayWindowApp extends StatelessWidget {
  /// Creates an [OverlayWindowApp].
  const OverlayWindowApp({
    required this.launch,
    required this.snapshot,
    super.key,
  });

  /// The launch configuration and the first frame.
  final OverlayWindowLaunch launch;

  /// The current frame, replaced on every `captionUpdate`.
  final ValueListenable<CaptionOverlaySnapshot> snapshot;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CaptionOverlaySnapshot>(
      valueListenable: snapshot,
      builder: (context, frame, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: _themeModeOf(frame.settings.themeModeSetting),
          home: OverlayWindowBody(
            activity: frame.activity,
            entries: frame.entries,
            interim: frame.interim,
            settings: frame.settings,
            position: launch.config.position,
          ),
        );
      },
    );
  }
}

/// The window contents, split out so it can be tested without a launch payload.
class OverlayWindowBody extends StatelessWidget {
  /// Creates an [OverlayWindowBody].
  const OverlayWindowBody({
    required this.activity,
    required this.entries,
    required this.interim,
    required this.settings,
    required this.position,
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

ThemeMode _themeModeOf(ThemeModeSetting setting) => switch (setting) {
      ThemeModeSetting.dark => ThemeMode.dark,
      ThemeModeSetting.light => ThemeMode.light,
      ThemeModeSetting.system => ThemeMode.system,
    };
