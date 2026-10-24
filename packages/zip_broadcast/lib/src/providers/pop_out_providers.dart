import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

part 'pop_out_providers.g.dart';

/// The pop-out window controller, alive for the app container.
///
/// Built from the engine's one host (NFR Design §2), so the external display
/// and the pop-out share a router, a display observer and a close channel.
@Riverpod(keepAlive: true)
OverlayWindowController popOutWindowController(Ref ref) {
  final host = ref.watch(overlayWindowHostProvider);
  final controller = host.createController(
    mode: const PopOutMode(),
    prefix: 'zip_broadcast.PopOutWindowController',
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// The pop-out's status, replaying the current one first (the stream is a
/// broadcast, and the controller starts `Off`).
@riverpod
Stream<ExternalDisplayStatus> popOutStatus(Ref ref) async* {
  final controller = ref.watch(popOutWindowControllerProvider);
  yield controller.status;
  yield* controller.statusChanges;
}

/// The pop-out's lifecycle events. The shell is the only listener.
@riverpod
Stream<OverlayEvent> popOutEvents(Ref ref) =>
    ref.watch(popOutWindowControllerProvider).events;

/// The frame the pop-out should occupy, as the shell computes it (R-M5).
///
/// The shell is the only component with the three inputs: a `BuildContext`
/// (hence the text theme and the text scaler), the resolved
/// [DisplaySettings], and the controller's display list. It passes the result
/// into `open(frame: ...)`; the controller never calls the geometry itself.
///
/// `mainWindowCentre` is null this unit (NFR-R §10.3, Q2 C), so the geometry's
/// own fallback picks the primary display.
({Rect frame, String? displayId}) popOutFrameFor({
  required BuildContext context,
  required List<DisplayInfo> displays,
  required DisplaySettings settings,
  TargetPlatform? platform,
}) {
  final theme = Theme.of(context);
  return computePopOutFrame(
    displays: displays,
    mainWindowCentre: null,
    settings: settings,
    textTheme: theme.textTheme,
    textScaler: MediaQuery.textScalerOf(context).scale(1),
    platform: platform ?? theme.platform,
  );
}
