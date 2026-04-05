import 'package:logging/logging.dart';
import 'package:zip_core/src/stt/stt_engine.dart';

/// Registry of available STT engine instances.
///
/// A plain Dart service class managing registered engines keyed by
/// [SttEngine.engineId]. Last-write-wins for duplicate IDs.
class SttEngineRegistry {
  static final _log = Logger('zip_core.SttEngineRegistry');

  final Map<String, SttEngine> _engines = {};

  /// Register an available engine.
  ///
  /// If an engine with the same [SttEngine.engineId] is already registered,
  /// it is replaced (last-write-wins).
  void register(SttEngine engine) {
    _engines[engine.engineId] = engine;
    _log.info('Engine registered: ${engine.engineId}');
  }

  /// Remove an engine from the registry. No-op if not found.
  void unregister(String engineId) {
    final removed = _engines.remove(engineId);
    if (removed != null) {
      _log.info('Engine unregistered: $engineId');
    }
  }

  /// All registered engines as an unmodifiable list.
  List<SttEngine> listAvailable() =>
      List.unmodifiable(_engines.values);

  /// Get engine by ID, or `null` if not registered.
  SttEngine? getEngine(String engineId) => _engines[engineId];

  /// First registered engine, or `null` if empty.
  /// Insertion-order (LinkedHashMap).
  SttEngine? get defaultEngine =>
      _engines.isEmpty ? null : _engines.values.first;
}
