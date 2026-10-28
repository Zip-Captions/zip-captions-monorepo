import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/zip_core.dart';

/// The Android side of [SegmentedRecognizerBridge] (Unit 10, Amendment 03).
///
/// Pure transport between the `zip_core` contract and the runner's
/// `SpeechRecognizer` (G8): every call is one method-channel message, and
/// the recogniser's callbacks arrive on the event channel as small maps that
/// decode to the sealed [SegmentedRecognizerEvent]s. No policy lives here —
/// the engine owns the fail-closed and retry rules.
///
/// `start` answers `false` on a [PlatformException] (a refusal the engine
/// treats as a transient failure, BR-U10-45); every other method — and
/// every other error from `start` — propagates, so a broken channel is
/// never mistaken for a refusal.
///
/// **Security (SECURITY-03)**: an unknown event type or a malformed map is
/// dropped and logged by *type name only*. Recognised text travels only
/// inside the [SttResult]s the engine builds; no text, code value or
/// exception message is ever logged here.
class MethodChannelSegmentedRecognizerBridge
    implements SegmentedRecognizerBridge {
  /// Creates a bridge over the app's own segmented-speech channels.
  MethodChannelSegmentedRecognizerBridge();

  /// The method channel the Android runner answers on (BR-U10, G8).
  static const methodChannelName = 'app.zipcaptions/segmented_speech';

  /// The event channel the Android runner reports on.
  static const eventChannelName = 'app.zipcaptions/segmented_speech/events';

  static const _channel = MethodChannel(methodChannelName);
  static const _eventChannel = EventChannel(eventChannelName);

  static final _log = Logger(
    'zip_captions.MethodChannelSegmentedRecognizerBridge',
  );

  Stream<SegmentedRecognizerEvent>? _events;

  @override
  Stream<SegmentedRecognizerEvent> get events =>
      _events ??= _eventChannel.receiveBroadcastStream().expand(_decode);

  @override
  Future<bool> start({
    required String localeId,
    required int minimumLengthMs,
  }) async {
    try {
      // `minimumLengthMs` must cross as an int: the Android service ignores
      // the segmented session when it receives a long (Amendment 03
      // section 1).
      await _channel.invokeMethod<void>('start', <String, Object?>{
        'localeId': localeId,
        'minimumLengthMs': minimumLengthMs,
      });
      return true;
    } on PlatformException {
      _log.warning('Segmented start refused by the platform');
      return false;
    }
  }

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<void> cancel() => _channel.invokeMethod<void>('cancel');

  @override
  Future<void> recreate() => _channel.invokeMethod<void>('recreate');

  @override
  Future<void> dispose() => _channel.invokeMethod<void>('dispose');

  /// The locales the runner's recogniser reports, as BCP-47 tags (BR-U10-50).
  ///
  /// Errors propagate: the engine decides what an unanswered runner means.
  @override
  Future<List<String>> supportedLocales() async {
    final reply = await _channel.invokeMethod<Object?>('supportedLocales');
    return (reply! as List<Object?>).cast<String>();
  }

  /// Decodes one event-channel map, or drops it with a log line naming only
  /// its type.
  Iterable<SegmentedRecognizerEvent> _decode(Object? raw) {
    final map = raw is Map ? raw.cast<Object?, Object?>() : null;
    final type = map?['type'];
    if (map == null || type is! String) {
      _log.warning('Dropped malformed segmented event (no type)');
      return const [];
    }
    switch (type) {
      case 'ready':
        return const [SegmentedReady()];
      case 'partial':
        final text = map['text'];
        if (text is! String) {
          _log.warning('Dropped malformed segmented event: partial');
          return const [];
        }
        return [SegmentedPartial(text)];
      case 'segment':
        final text = map['text'];
        if (text is! String) {
          _log.warning('Dropped malformed segmented event: segment');
          return const [];
        }
        return [SegmentedSegment(text)];
      case 'endOfSession':
        return const [SegmentedEndOfSession()];
      case 'error':
        final code = map['code'];
        if (code is! int) {
          _log.warning('Dropped malformed segmented event: error');
          return const [];
        }
        return [SegmentedError(code)];
      default:
        _log.warning('Dropped unknown segmented event type: $type');
        return const [];
    }
  }
}
