import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_broadcast/src/providers/audio_input_config_notifier.dart';

part 'broadcast_engine_available_provider.g.dart';

/// Whether Zip Broadcast can start captioning right now — the app's own gate,
/// which the pop-out's availability rule reuses (FD domain-entities §3.1,
/// R-M1 resolved: RQ-2 A).
///
/// It derives from the configured audio inputs, not from
/// `SttEngineRegistry`. Nothing in this app registers into the registry: it
/// builds one engine per audio source through `sttEngineFactoryProvider`, so
/// the registry is permanently empty here and would disable the pop-out with
/// "No speech recognition engine" on every machine. Watching the config list
/// also means the value rebuilds when the user adds or removes a source, which
/// watching the registry could not do.
///
/// It does not consult `sttEngineFactoryProvider`: that provider throws when
/// it has no override, and a provider that throws is not a value a control can
/// render. The factory is an app-startup precondition (main overrides it in
/// every build), so the gate is the source list and nothing else.
@riverpod
bool broadcastEngineAvailable(Ref ref) {
  final configs = ref.watch(audioInputConfigNotifierProvider);
  return configs.isNotEmpty;
}
