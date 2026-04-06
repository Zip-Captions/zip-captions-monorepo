import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';

part 'stt_engine_registry_provider.g.dart';

/// Singleton [SttEngineRegistry] instance for the app lifetime.
///
/// Concrete STT engines are registered in Unit 2.
@Riverpod(keepAlive: true)
SttEngineRegistry sttEngineRegistry(Ref ref) {
  return SttEngineRegistry();
}
