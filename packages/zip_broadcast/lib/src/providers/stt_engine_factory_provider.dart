import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:zip_core/zip_core.dart';

part 'stt_engine_factory_provider.g.dart';

/// Factory that creates an [SttEngine] for a given [sourceId] (device ID).
///
/// Must be overridden at app startup (e.g. in `main.dart`) with a concrete
/// implementation, typically [PlatformSttEngine]. Tests override with
/// `MockSttEngine` instances.
///
/// The returned engine is NOT managed by Riverpod's lifecycle.
/// `BroadcastRecordingNotifier` owns and disposes engines directly.
@riverpod
SttEngine sttEngineFactory(Ref ref, String sourceId) {
  if (kDebugMode) return FakeSttEngine();
  throw UnimplementedError(
    'sttEngineFactoryProvider must be overridden at app startup.',
  );
}
