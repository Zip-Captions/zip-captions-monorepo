import 'dart:typed_data';

import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'package:zip_core/src/stt/adapters/online_recognizer_adapter.dart';

/// Production [OnlineRecognizerAdapter] that delegates to the real
/// sherpa_onnx [sherpa.OnlineRecognizer].
///
/// Coverage excluded — pure pass-through with no logic (TEST-U2.6).
class SherpaOnlineRecognizerAdapter implements OnlineRecognizerAdapter {
  /// Creates a [SherpaOnlineRecognizerAdapter] wrapping [recognizer].
  SherpaOnlineRecognizerAdapter(this._recognizer);

  final sherpa.OnlineRecognizer _recognizer;

  @override
  Object createStream() => _recognizer.createStream();

  @override
  void acceptWaveform(
    Object stream, {
    required int sampleRate,
    required Float32List samples,
  }) =>
      (stream as sherpa.OnlineStream).acceptWaveform(
        samples: samples,
        sampleRate: sampleRate,
      );

  @override
  bool isReady(Object stream) =>
      _recognizer.isReady(stream as sherpa.OnlineStream);

  @override
  void decode(Object stream) =>
      _recognizer.decode(stream as sherpa.OnlineStream);

  @override
  String getResult(Object stream) =>
      _recognizer.getResult(stream as sherpa.OnlineStream).text;

  @override
  void reset(Object stream) =>
      _recognizer.reset(stream as sherpa.OnlineStream);

  @override
  void dispose() => _recognizer.free();
}
