import 'dart:typed_data';

/// Test seam for sherpa_onnx OnlineRecognizer (TEST-U2.2, Q1=A).
///
/// A thin abstract interface mirroring only the `OnlineRecognizer` methods
/// used by `SherpaOnnxSttEngine`. The production implementation
/// (`SherpaOnlineRecognizerAdapter`) delegates to the real native class.
///
/// Coverage excluded — pure pass-through with no logic.
abstract interface class OnlineRecognizerAdapter {
  /// Creates a new recognition stream.
  Object createStream();

  /// Feeds PCM16 audio samples to the stream.
  void acceptWaveform(
    Object stream, {
    required int sampleRate,
    required Float32List samples,
  });

  /// Returns true if enough audio has been buffered to run a decode step.
  bool isReady(Object stream);

  /// Runs one decode step on the stream.
  void decode(Object stream);

  /// Returns the current partial/final result text.
  String getResult(Object stream);

  /// Resets the stream state for the next utterance.
  void reset(Object stream);

  /// Frees native resources.
  void dispose();
}
