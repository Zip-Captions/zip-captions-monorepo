import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_core/src/models/caption_display_entry.dart';
import 'package:zip_core/src/output/on_screen_caption_target.dart';
import 'package:zip_core/src/providers/caption_output_target_registry_provider.dart';

/// Provides the live caption display buffer as a stream of
/// [List<CaptionDisplayEntry>].
///
/// Creates a single [OnScreenCaptionTarget], registers it with
/// [captionOutputTargetRegistryProvider], and streams updates from it.
/// The stream emits on every 50ms debounce tick from the target.
///
/// Consumers that need a synchronous `List<CaptionDisplayEntry>` should use
/// `.valueOrNull ?? const []` on the [AsyncValue].
final onScreenCaptionTargetProvider =
    StreamProvider<List<CaptionDisplayEntry>>((ref) {
  final registry = ref.read(captionOutputTargetRegistryProvider);
  final target = OnScreenCaptionTarget(targetId: 'on_screen');
  registry.add(target);
  ref.onDispose(() => registry.remove(target));
  return target.onVisibleCaptionsChanged;
});
