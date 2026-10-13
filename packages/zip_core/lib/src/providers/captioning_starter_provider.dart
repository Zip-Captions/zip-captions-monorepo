import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/services/caption/captioning_starter.dart';

part 'captioning_starter_provider.g.dart';

/// The [CaptioningStarter] seam (Functional Design Q1). Default value
/// wraps `zip_captions`' single-engine `RecordingStateNotifier`;
/// `zip_broadcast`'s `main.dart` overrides this with a
/// `BroadcastRecordingNotifier`-backed implementation (same override
/// pattern as `authServiceProvider`/`supabaseClientProvider`, Unit 2).
@Riverpod(keepAlive: true)
CaptioningStarter captioningStarter(Ref ref) =>
    DefaultCaptioningStarter(ref);
