import 'dart:async';

import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:zip_core/zip_core.dart';

/// The runners' side of [LanguagePackService] (Unit 10, Amendment 04).
///
/// Pure transport: `status` and `download` are one method-channel message
/// each, and the download's progress and outcome arrive on the event channel
/// as small maps that decode to the sealed [LanguagePackEvent]s. The panel
/// owns every policy (when to ask, when to give up).
///
/// A reply the app cannot read is [LanguagePackStatus.unknown] with the locale
/// tag as the display name, and so is a [PlatformException] from `status`.
/// `download` lets its errors through, so the panel can show the failed state.
///
/// **Security (SECURITY-03)**: an unknown event type or a malformed map is
/// dropped and logged by *type name only*. No locale, display name or
/// exception message is logged here.
class MethodChannelLanguagePackService implements LanguagePackService {
  /// Creates a service over the app's own language-pack channels.
  MethodChannelLanguagePackService();

  /// The method channel both runners answer on.
  static const methodChannelName = 'app.zipcaptions/language_pack';

  /// The event channel both runners report downloads on.
  static const eventChannelName = 'app.zipcaptions/language_pack/events';

  static const _channel = MethodChannel(methodChannelName);
  static const _eventChannel = EventChannel(eventChannelName);

  static final _log = Logger('zip_captions.MethodChannelLanguagePackService');

  Stream<LanguagePackEvent>? _events;

  @override
  Stream<LanguagePackEvent> get events =>
      _events ??= _eventChannel.receiveBroadcastStream().expand(_decode);

  @override
  Future<LanguagePackInfo> status(String localeId) async {
    final Object? reply;
    try {
      reply = await _channel.invokeMethod<Object?>('status', <String, Object?>{
        'localeId': localeId,
      });
    } on PlatformException {
      _log.warning('Language-pack status failed in the platform');
      return _unknown(localeId);
    }
    if (reply is! Map) {
      _log.warning('Language-pack status reply was not a map');
      return _unknown(localeId);
    }
    final map = reply.cast<Object?, Object?>();
    final name = map['status'];
    final status = name is String
        ? LanguagePackStatus.values.asNameMap()[name]
        : null;
    if (status == null) {
      _log.warning('Language-pack status reply had no known status');
      return _unknown(localeId);
    }
    final displayName = map['displayName'];
    return LanguagePackInfo(
      status: status,
      displayName: displayName is String && displayName.isNotEmpty
          ? displayName
          : localeId,
    );
  }

  @override
  Future<void> download(String localeId) =>
      _channel.invokeMethod<void>('download', <String, Object?>{
        'localeId': localeId,
      });

  LanguagePackInfo _unknown(String localeId) => LanguagePackInfo(
    status: LanguagePackStatus.unknown,
    displayName: localeId,
  );

  /// Decodes one event-channel map, or drops it with a log line naming only
  /// its type.
  Iterable<LanguagePackEvent> _decode(Object? raw) {
    final map = raw is Map ? raw.cast<Object?, Object?>() : null;
    final type = map?['type'];
    if (map == null || type is! String) {
      _log.warning('Dropped malformed language-pack event (no type)');
      return const [];
    }
    final localeId = map['localeId'];
    if (localeId is! String) {
      _log.warning('Dropped malformed language-pack event: $type');
      return const [];
    }
    switch (type) {
      case 'progress':
        final percent = map['percent'];
        if (percent != null && percent is! int) {
          _log.warning('Dropped malformed language-pack event: progress');
          return const [];
        }
        return [LanguagePackProgress(localeId, percent: percent as int?)];
      case 'scheduled':
        return [LanguagePackScheduled(localeId)];
      case 'done':
        return [LanguagePackDone(localeId)];
      case 'failed':
        final code = map['code'];
        if (code != null && code is! int) {
          _log.warning('Dropped malformed language-pack event: failed');
          return const [];
        }
        return [LanguagePackFailed(localeId, code: code as int?)];
      default:
        _log.warning('Dropped unknown language-pack event type: $type');
        return const [];
    }
  }
}
