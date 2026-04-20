import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/stt/stt_engine.dart';

/// Scripted STT engine for UI review and development.
///
/// Cycles through a fixed list of phrases, emitting each one first as an
/// interim result and then as a final result on a timer. Requires no microphone
/// and no model download.
///
/// **Only use in debug builds.** Register via `SttEngineRegistry` before
/// calling `RecordingStateNotifier.start`.
@visibleForTesting
class FakeSttEngine implements SttEngine {
  static const _phrases = [
    'Hello and welcome to Zip Captions.',
    'This is a scripted caption for UI review.',
    'The quick brown fox jumps over the lazy dog.',
    'Caption text scrolls from bottom to top by default.',
    'You can change the scroll direction in Settings.',
    'Try resizing the window to test the mobile layout.',
    'Tap Stop when you are done to save the session.',
  ];

  /// How long each interim phase is shown before it becomes final.
  static const _interimDuration = Duration(milliseconds: 1200);

  /// Delay between a final result and the start of the next phrase.
  ///
  /// Must exceed `TranscriptWriterTarget._mergeWindowMs` (2000 ms) when
  /// added to [_interimDuration] — each phrase becomes a distinct segment.
  /// 1000 + 1200 = 2200 ms > 2000 ms merge window.
  static const _pauseDuration = Duration(milliseconds: 1000);

  Timer? _timer;
  int _phraseIndex = 0;
  bool _showingInterim = false;
  void Function(SttResult)? _onResult;

  @override
  String get engineId => 'fake';

  @override
  String get displayName => 'Fake (Dev)';

  @override
  bool get requiresNetwork => false;

  @override
  bool get requiresDownload => false;

  @override
  bool get requiresMicrophone => false;

  @override
  Future<bool> initialize() async => true;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<List<SpeechLocale>> supportedLocales() async => const [
        SpeechLocale(localeId: 'en-US', displayName: 'English (US)'),
      ];

  @override
  Future<bool> startListening({
    required String localeId,
    required void Function(SttResult result) onResult,
  }) async {
    _onResult = onResult;
    _phraseIndex = 0;
    _showingInterim = false;
    _scheduleNext();
    return true;
  }

  @override
  Future<void> stopListening() async => _cancel();

  @override
  Future<bool> pause() async {
    _cancel();
    return true;
  }

  @override
  Future<bool> resume() async {
    _scheduleNext();
    return true;
  }

  @override
  void dispose() => _cancel();

  void _scheduleNext() {
    _cancel();
    final delay = _showingInterim ? _interimDuration : _pauseDuration;
    _timer = Timer(delay, _tick);
  }

  void _tick() {
    final cb = _onResult;
    if (cb == null) return;

    final index = _phraseIndex % _phrases.length;
    final phrase = '[$_phraseIndex] ${_phrases[index]}';

    if (!_showingInterim) {
      // Emit interim.
      cb(
        SttResult(
          text: phrase,
          isFinal: false,
          confidence: 1,
          timestamp: DateTime.now().toUtc(),
          sourceId: 'default',
        ),
      );
      _showingInterim = true;
      _scheduleNext();
    } else {
      // Commit as final.
      cb(
        SttResult(
          text: phrase,
          isFinal: true,
          confidence: 1,
          timestamp: DateTime.now().toUtc(),
          sourceId: 'default',
        ),
      );
      _phraseIndex++;
      _showingInterim = false;
      _scheduleNext();
    }
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
