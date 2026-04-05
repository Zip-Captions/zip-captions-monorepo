import 'dart:async';
import 'dart:typed_data';

import 'package:logging/logging.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/audio/audio_device_service.dart';
import 'package:zip_core/src/services/catalog/sherpa_model_manager.dart';
import 'package:zip_core/src/stt/adapters/online_recognizer_adapter.dart';
import 'package:zip_core/src/stt/stt_engine.dart';

/// Wraps Sherpa-ONNX for Tier 2 platforms (Windows/Linux primary,
/// available elsewhere).
///
/// Implements [SttEngine]. Requires a downloaded model to function.
/// Uses [OnlineRecognizerAdapter] as a test seam (TEST-U2.2, Q1=A).
///
/// **Security (SECURITY-03)**: Never logs transcript text.
class SherpaOnnxSttEngine implements SttEngine {
  /// Creates a [SherpaOnnxSttEngine].
  SherpaOnnxSttEngine({
    required SherpaModelManager modelManager,
    required AudioDeviceService deviceService,
    OnlineRecognizerAdapter? recognizerAdapter,
  })  : _modelManager = modelManager,
        _deviceService = deviceService,
        _adapter = recognizerAdapter;

  static final _log = Logger('zip_core.SherpaOnnxSttEngine');

  final SherpaModelManager _modelManager;
  final AudioDeviceService _deviceService;
  OnlineRecognizerAdapter? _adapter;

  Object? _stream;
  void Function(SttResult)? _onResult;
  Timer? _decodeTimer;
  bool _listening = false;

  @override
  String get engineId => 'sherpa-onnx';

  @override
  String get displayName => 'Offline Speech Recognition';

  @override
  bool get requiresNetwork => false;

  @override
  bool get requiresDownload => true;

  @override
  Future<bool> isAvailable() async =>
      _modelManager.downloadedModels.isNotEmpty;

  @override
  Future<bool> initialize() async {
    // Model selection and adapter creation are implementation details
    // that depend on the sherpa_onnx native API. In production, the
    // adapter is created here from the model path. In tests, it is
    // injected via the constructor.
    if (_adapter != null) {
      _log.info('Sherpa-ONNX engine initialized (adapter pre-injected)');
      return true;
    }

    // Production path: resolve model and create native recognizer.
    // This is a placeholder — full native setup requires sherpa_onnx
    // config objects built from the model directory.
    _log.info('Sherpa-ONNX engine initialize — model setup required');
    return false;
  }

  @override
  Future<List<SpeechLocale>> supportedLocales() async {
    final downloaded = _modelManager.downloadedModels;
    final localeIds = <String>{};
    for (final model in downloaded) {
      localeIds.add(model.catalogEntry.primaryLocaleId);
    }
    return localeIds
        .map((id) => SpeechLocale(localeId: id, displayName: id))
        .toList();
  }

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    if (_adapter == null) return false;

    _onResult = onResult;
    _listening = true;

    // Set preferred device before listening.
    final preferredDevice = _deviceService.currentPreferredDeviceId;
    if (preferredDevice != null) {
      await _deviceService.setPreferredInputDevice(preferredDevice);
    }

    _stream = _adapter!.createStream();

    // Start the decode loop — polls for results at regular intervals.
    _decodeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _decodeStep(),
    );

    _log.info('Sherpa-ONNX listening for locale $localeId');
    return true;
  }

  /// Feeds a PCM16 audio chunk to the recognizer.
  ///
  /// Called by the audio capture pipeline. Converts Int16 PCM to Float32.
  void feedAudio(Uint8List pcm16Bytes, {int sampleRate = 16000}) {
    if (!_listening || _adapter == null || _stream == null) return;

    // Convert Int16 PCM to Float32 samples.
    final int16Data = pcm16Bytes.buffer.asInt16List();
    final float32Samples = Float32List(int16Data.length);
    for (var i = 0; i < int16Data.length; i++) {
      float32Samples[i] = int16Data[i] / 32768.0;
    }

    _adapter!.acceptWaveform(
      _stream!,
      sampleRate: sampleRate,
      samples: float32Samples,
    );
  }

  @override
  Future<void> stopListening() async {
    _decodeTimer?.cancel();
    _decodeTimer = null;
    _listening = false;

    // Flush final result.
    if (_adapter != null && _stream != null) {
      _decodeStep(flush: true);
      _adapter!.reset(_stream!);
    }
    _stream = null;

    _log.info('Sherpa-ONNX stopped listening');
  }

  @override
  Future<bool> pause() async {
    _decodeTimer?.cancel();
    _decodeTimer = null;
    _listening = false;
    _log.info('Sherpa-ONNX paused');
    return true;
  }

  @override
  Future<bool> resume() async {
    if (_adapter == null || _stream == null) return false;
    _listening = true;
    _decodeTimer = Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _decodeStep(),
    );
    _log.info('Sherpa-ONNX resumed');
    return true;
  }

  @override
  void dispose() {
    _decodeTimer?.cancel();
    _decodeTimer = null;
    _listening = false;
    _adapter?.dispose();
    _adapter = null;
    _stream = null;
    _onResult = null;
  }

  // --- Private helpers ---

  void _decodeStep({bool flush = false}) {
    if (_adapter == null || _stream == null) return;

    while (_adapter!.isReady(_stream!)) {
      _adapter!.decode(_stream!);
    }

    final text = _adapter!.getResult(_stream!);
    if (text.isNotEmpty) {
      _onResult?.call(
        SttResult(
          text: text,
          isFinal: flush,
          confidence: 1,
          timestamp: DateTime.now(),
          sourceId: engineId,
        ),
      );

      if (flush) {
        _adapter!.reset(_stream!);
      }
    }
  }
}
