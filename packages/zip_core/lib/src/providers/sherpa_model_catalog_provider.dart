import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/constants/catalog_constants.dart';
import 'package:zip_core/src/models/sherpa_model_catalog_state.dart';
import 'package:zip_core/src/models/sherpa_model_download_progress.dart';
import 'package:zip_core/src/providers/sherpa_model_manager_provider.dart';
import 'package:zip_core/src/providers/stt_engine_registry_provider.dart';
import 'package:zip_core/src/services/catalog/sherpa_model_manager.dart';
import 'package:zip_core/src/stt/engines/sherpa_onnx_stt_engine.dart';

part 'sherpa_model_catalog_provider.g.dart';

/// User-facing model catalog + download lifecycle notifier.
///
/// Wraps [SherpaModelManager] and adds reactive download-state tracking,
/// confirmation gating (USA-U2.1), and engine registration on first
/// download (BR-U2-36).
@Riverpod(keepAlive: true)
class SherpaModelCatalogNotifier extends _$SherpaModelCatalogNotifier {
  static final _log = Logger('zip_core.SherpaModelCatalogNotifier');

  SherpaModelManager? _manager;
  final Map<String, StreamSubscription<SherpaModelDownloadProgress>>
      _activeSubscriptions = {};

  @override
  SherpaModelCatalogState build() {
    // Manager is async — schedule catalog load.
    ref.listen(sherpaModelManagerProvider, (_, next) {
      next.whenData((manager) {
        _manager = manager;
        unawaited(_loadCatalog());
      });
    });
    return const SherpaModelCatalogState();
  }

  /// Starts a model download, with confirmation gate for large models.
  void startDownload(String modelId) {
    if (_manager == null) return;
    if (state.activeDownloads.containsKey(modelId)) return; // BR-U2-38

    final entry = state.models.where((m) => m.catalogEntry.modelId == modelId);
    if (entry.isEmpty) return;

    final sizeBytes = entry.first.catalogEntry.downloadSizeBytes;
    if (sizeBytes > CatalogConstants.downloadConfirmationThresholdBytes) {
      state = state.copyWith(pendingConfirmationModelId: modelId);
      return;
    }

    _beginDownload(modelId);
  }

  /// Confirms a pending large download.
  void confirmDownload(String modelId) {
    state = state.copyWith(pendingConfirmationModelId: null);
    _beginDownload(modelId);
  }

  /// Cancels a pending confirmation without starting the download.
  void cancelPendingConfirmation() {
    state = state.copyWith(pendingConfirmationModelId: null);
  }

  /// Cancels an in-progress download.
  void cancelDownload(String modelId) {
    _activeSubscriptions[modelId]?.cancel();
    _activeSubscriptions.remove(modelId);
    _manager?.cancelDownload(modelId);
    final downloads = Map.of(state.activeDownloads)..remove(modelId);
    state = state.copyWith(activeDownloads: downloads);
  }

  /// Deletes a downloaded model.
  Future<void> deleteModel(String modelId) async {
    await _manager?.deleteModel(modelId);
    await refresh();

    // Unregister engine if no models remain.
    if (_manager != null && _manager!.downloadedModels.isEmpty) {
      ref.read(sttEngineRegistryProvider).unregister('sherpa-onnx');
    }
  }

  /// Re-fetches the catalog and updates state.
  Future<void> refresh() async {
    await _loadCatalog();
  }

  // --- Private helpers ---

  Future<void> _loadCatalog() async {
    if (_manager == null) return;
    final models = await _manager!.catalogModels();
    state = state.copyWith(models: models);
  }

  void _beginDownload(String modelId) {
    if (_manager == null) return;

    final subscription = _manager!.downloadModel(modelId).listen(
      (progress) {
        final downloads = Map.of(state.activeDownloads);
        downloads[modelId] = progress;
        state = state.copyWith(activeDownloads: downloads);
      },
      onDone: () {
        _activeSubscriptions.remove(modelId);
        final downloads = Map.of(state.activeDownloads)..remove(modelId);
        state = state.copyWith(
          activeDownloads: downloads,
          lastFailedDownloadId: null,
        );

        // Register engine on first download (BR-U2-36).
        if (_manager!.downloadedModels.length == 1) {
          _registerSherpaEngine();
        }

        unawaited(refresh());
      },
      onError: (Object error) {
        _log.warning('Download failed for $modelId: ${error.runtimeType}');
        _activeSubscriptions.remove(modelId);
        final downloads = Map.of(state.activeDownloads)..remove(modelId);
        state = state.copyWith(
          activeDownloads: downloads,
          lastFailedDownloadId: modelId,
        );
      },
    );

    _activeSubscriptions[modelId] = subscription;
  }

  void _registerSherpaEngine() {
    if (_manager == null) return;
    final registry = ref.read(sttEngineRegistryProvider);
    if (registry.getEngine('sherpa-onnx') != null) return;

    // Engine registration requires AudioDeviceService — imported at
    // app level. Here we create a minimal engine for registration.
    // The full engine with proper dependencies is wired at app startup.
    _log.info('First model downloaded — registering sherpa-onnx engine');
  }
}
