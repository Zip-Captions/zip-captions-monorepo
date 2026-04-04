import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/active_engine_id_provider.dart';
import 'package:zip_core/src/providers/stt_engine_registry_provider.dart';
import 'package:zip_core/src/stt/stt_engine.dart';

part 'stt_engine_provider.g.dart';

/// Resolves the active [SttEngine] from the registry.
///
/// Uses [activeEngineIdNotifierProvider] to pick the user-selected engine.
/// Falls back to [SttEngineRegistry.defaultEngine] when no explicit selection
/// exists. Returns `null` if no engines are registered.
@Riverpod(keepAlive: true)
SttEngine? sttEngine(Ref ref) {
  final activeId = ref.watch(activeEngineIdNotifierProvider);
  final registry = ref.watch(sttEngineRegistryProvider);

  if (activeId != null) {
    final engine = registry.getEngine(activeId);
    if (engine != null) return engine;
  }

  return registry.defaultEngine;
}
