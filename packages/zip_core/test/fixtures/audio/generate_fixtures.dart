// ignore_for_file: avoid_print
/// Generates PCM16 audio fixture files for STT engine tests.
///
/// Run: `dart test/fixtures/audio/generate_fixtures.dart`
///
/// Produces:
/// - silence_16k.pcm — 1 second of silence at 16 kHz, 16-bit mono LE
/// - tone_440hz_16k.pcm — 1 second of 440 Hz sine at 16 kHz, 16-bit mono LE
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

void main() {
  const sampleRate = 16000;
  const durationSeconds = 1;
  const numSamples = sampleRate * durationSeconds;

  final scriptDir = File(Platform.script.toFilePath()).parent.path;

  // --- silence_16k.pcm ---
  final silence = Int16List(numSamples); // all zeros
  final silenceBytes = ByteData.sublistView(silence);
  File('$scriptDir/silence_16k.pcm')
      .writeAsBytesSync(silenceBytes.buffer.asUint8List());
  print('Generated silence_16k.pcm (${numSamples * 2} bytes)');

  // --- tone_440hz_16k.pcm ---
  final tone = Int16List(numSamples);
  const frequency = 440.0;
  const amplitude = 0.8 * 32767; // ~80% of max int16
  for (var i = 0; i < numSamples; i++) {
    tone[i] = (amplitude * sin(2 * pi * frequency * i / sampleRate)).round();
  }
  final toneBytes = ByteData.sublistView(tone);
  File('$scriptDir/tone_440hz_16k.pcm')
      .writeAsBytesSync(toneBytes.buffer.asUint8List());
  print('Generated tone_440hz_16k.pcm (${numSamples * 2} bytes)');
}
