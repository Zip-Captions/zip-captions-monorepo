import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/stt/stt_engine.dart';

part 'stt_engine_provider.g.dart';

/// Provider for the active STT engine.
///
/// Phase 0: throws [UnimplementedError].
/// Phase 1: returns the platform-appropriate engine.
@Riverpod(keepAlive: true)
class SttEngineNotifier extends _$SttEngineNotifier {
  @override
  Future<SttEngine> build() {
    throw UnimplementedError(
      'STT engine implementation is Phase 1',
    );
  }
}
