import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';

part 'caption_bus_provider.g.dart';

/// Singleton [CaptionBus] instance for the app lifetime.
///
/// All caption events flow through this bus.
@Riverpod(keepAlive: true)
CaptionBus captionBus(Ref ref) {
  final bus = CaptionBus();
  ref.onDispose(bus.dispose);
  return bus;
}
