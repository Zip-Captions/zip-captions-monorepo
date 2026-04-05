import 'dart:async';

import 'package:logging/logging.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/src/constants/catalog_constants.dart';
import 'package:zip_core/src/models/sherpa_model_catalog_state.dart';
import 'package:zip_core/src/models/sherpa_model_download_progress.dart';
import 'package:zip_core/src/providers/sherpa_model_manager_provider.dart';
import 'package:zip_core/src/providers/stt_engine_registry_provider.dart';
import 'package:zip_core/src/services/catalog/sherpa_model_manager.dart';

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
    // Manager is async — load catalog as soon as it resolves.
    // fireImmediately: true ensures the catalog loads even when the manager
    // is already resolved before this notifier is created.
    ref
      ..onDispose(() {
        for (final entry in _activeSubscriptions.entries) {
          unawaited(entry.value.cancel());
          _manager?.cancelDownload(entry.key);
        }
        _activeSubscriptions.clear();
      })
      ..listen(
        sherpaModelManagerProvider,
        (_, next) {
          next.whenData((manager) {
            _manager = manager;
            unawaited(() async {
              try {
                await _loadCatalog();
              } on Object catch (e, st) {
                _log.warning('Failed to load catalog on manager ready', e, st);
              }
            }());
          });
        },
        fireImmediately: true,
      );
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
  ///
  /// No-op if [modelId] does not match the current pending confirmation.
  void confirmDownload(String modelId) {
    if (state.pendingConfirmationModelId != modelId) return;
    state = state.copyWith(pendingConfirmationModelId: null);
    _beginDownload(modelId);
  }

  /// Cancels a pending confirmation without starting the download.
  void cancelPendingConfirmation() {
    state = state.copyWith(pendingConfirmationModelId: null);
  }

  /// Cancels an in-progress download.
  void cancelDownload(String modelId) {
    unawaited(_activeSubscriptions[modelId]?.cancel());
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

  /// Begins an active download and tracks the subscription.
  ///
  /// Engine registration on first download is handled at app startup;
  /// this notifier tracks download state only.
  void _beginDownload(String modelId) {
    if (_manager == null) return;

    // The subscription is tracked in _activeSubscriptions — not a leak.
    // ignore: cancel_subscriptions
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
}
