import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/caption_bus_provider.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';

part 'caption_output_target_registry_provider.g.dart';

/// Singleton [CaptionOutputTargetRegistry] for the app lifetime.
///
/// Depends on [captionBusProvider] for the bus reference.
@Riverpod(keepAlive: true)
CaptionOutputTargetRegistry captionOutputTargetRegistry(Ref ref) {
  final bus = ref.read(captionBusProvider);
  final registry = CaptionOutputTargetRegistry(bus);
  ref.onDispose(registry.dispose);
  return registry;
}
