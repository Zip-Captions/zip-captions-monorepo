import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

part 'pop_out_providers.g.dart';

/// Whether Zip Captions can caption at all — the app's own gate, which the
/// pop-out's availability rule reuses (FD domain-entities §3.1, RQ-2 A).
///
/// This app builds its engine at startup and publishes it through
/// [sttEngineProvider]; nothing registers into the registry here either, so
/// the gate is that one value and nothing else (BR-PIP-13).
@riverpod
bool captionsEngineAvailable(Ref ref) => ref.watch(sttEngineProvider) != null;

/// The pop-out window controller, alive for the app container.
///
/// Built from the engine's one host (NFR Design §2), so the external display
/// and the pop-out share a router, a display observer and a close channel.
@Riverpod(keepAlive: true)
OverlayWindowController popOutWindowController(Ref ref) {
  final host = ref.watch(overlayWindowHostProvider);
  final controller = host.createController(
    mode: const PopOutMode(),
    prefix: 'zip_captions.PopOutWindowController',
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// The connected displays, per the enumerator's event contract.
@riverpod
Stream<List<DisplayInfo>> displayList(Ref ref) =>
    ref.watch(popOutWindowControllerProvider).enumerator.changes;

/// The frame the pop-out should occupy, as the shell computes it (R-M5).
///
/// The shell is the only component with the three inputs: a `BuildContext`
/// (hence the text theme and the text scaler), the resolved
/// [DisplaySettings], and the controller's display list.
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
