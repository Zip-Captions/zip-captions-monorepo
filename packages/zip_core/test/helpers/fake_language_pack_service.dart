import 'dart:async';

import 'package:zip_core/zip_core.dart';

/// A hand-written stand-in for [LanguagePackService].
///
/// Scripts the status per locale ([statuses], with [defaultInfo] for any
/// other), records every call, and lets a test drive the platform side by
/// sending events through [send].
class FakeLanguagePackService implements LanguagePackService {
  /// Creates a fake whose every locale is `unknown` until scripted.
  FakeLanguagePackService();

  /// The status answered for a locale that is not in [statuses].
  LanguagePackInfo defaultInfo = const LanguagePackInfo(
    status: LanguagePackStatus.unknown,
    displayName: '',
  );

  /// The status answered per locale id.
  final statuses = <String, LanguagePackInfo>{};

  /// When set, `status` throws this [Exception].
  Exception? statusError;

  /// When set, `download` throws this [Exception].
  Exception? downloadError;

  /// When set, `download` waits for this before answering, so a test can hold
  /// a download open.
  Future<void>? downloadGate;

  /// The locale of every `status` call, oldest first.
  final statusCalls = <String>[];

  /// The locale of every `download` call, oldest first.
  final downloadCalls = <String>[];

  final _events = StreamController<LanguagePackEvent>.broadcast();

  /// Scripts the answer for [localeId].
  void setStatus(
    String localeId,
    LanguagePackStatus status, {
    String? displayName,
  }) {
    statuses[localeId] = LanguagePackInfo(
      status: status,
      displayName: displayName ?? localeId,
    );
  }

  @override
  Future<LanguagePackInfo> status(String localeId) async {
    statusCalls.add(localeId);
    final error = statusError;
    if (error != null) throw error;
    return statuses[localeId] ??
        LanguagePackInfo(
          status: defaultInfo.status,
          displayName: defaultInfo.displayName.isEmpty
              ? localeId
              : defaultInfo.displayName,
        );
  }

  @override
  Future<void> download(String localeId) async {
    downloadCalls.add(localeId);
    final gate = downloadGate;
    if (gate != null) await gate;
    final error = downloadError;
    if (error != null) throw error;
  }

  @override
  Stream<LanguagePackEvent> get events => _events.stream;

  /// Sends [event] to the listeners, as the platform would.
  void send(LanguagePackEvent event) => _events.add(event);

  /// Closes the event stream.
  Future<void> close() => _events.close();
}
