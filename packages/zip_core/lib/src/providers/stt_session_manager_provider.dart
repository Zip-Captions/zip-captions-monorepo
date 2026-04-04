import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/providers/stt_engine_registry_provider.dart';
import 'package:zip_core/src/services/stt/stt_session_manager.dart';

part 'stt_session_manager_provider.g.dart';

/// Provides the singleton [SttSessionManager].
@Riverpod(keepAlive: true)
SttSessionManager sttSessionManager(Ref ref) {
  return SttSessionManager(
    registry: ref.read(sttEngineRegistryProvider),
  );
}
