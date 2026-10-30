import 'dart:async';

import 'package:zip_core/zip_core.dart';

import 'call_log.dart';

/// A hand-written stand-in for [SegmentedRecognizerBridge].
///
/// Every call is logged to the shared [CallLog], so a test can assert what
/// happened *before* what — for example "a check precedes every start". The
/// test drives the platform side by sending events through [send].
///
/// A default `start` answers `true`; script [startOk] to answer `false`, and
/// [startError] (an exception) to throw instead. `stop` and `cancel` never
/// throw unless [stopError] or [cancelError] is set; `recreate` never throws.
class FakeSegmentedRecognizerBridge implements SegmentedRecognizerBridge {
  /// Creates a bridge, optionally sharing a [CallLog].
  FakeSegmentedRecognizerBridge([CallLog? log]) : log = log ?? CallLog();

  /// The shared call log.
  final CallLog log;

  final _events = StreamController<SegmentedRecognizerEvent>.broadcast();

  /// The locale of every `start`, oldest first.
  final startedLocales = <String>[];

  /// The minimum length of every `start`, in milliseconds, oldest first.
  final startedMinimumLengths = <int>[];

  /// What `start` answers when it does not throw.
  bool startOk = true;

  /// When set, `start` throws this [Exception].
  Exception? startError;

  /// When set, `stop` throws this [Exception].
  Exception? stopError;

  /// When set, `cancel` throws this [Exception].
  Exception? cancelError;

  /// When set, the next `start` waits for this before answering (consumed
  /// after one call), so a test can hold a start open.
  Future<void>? startGate;

  /// When set, the next `stop` waits for this before returning (consumed
  /// after one call), so a test can hold a stop open.
  Future<void>? stopGate;

  /// What `supportedLocales` answers when it does not throw.
  List<String> supportedLocaleTags = const [];

  /// When set, `supportedLocales` throws this [Exception].
  Exception? supportedLocalesError;

  @override
  Stream<SegmentedRecognizerEvent> get events => _events.stream;

  @override
  Future<List<String>> supportedLocales() async {
    log.add('segment-supported-locales');
    final error = supportedLocalesError;
    if (error != null) throw error;
    return supportedLocaleTags;
  }

  @override
  Future<bool> start({
    required String localeId,
    required int minimumLengthMs,
  }) async {
    startedLocales.add(localeId);
    startedMinimumLengths.add(minimumLengthMs);
    log.add('segment-start:$localeId:$minimumLengthMs');
    final gate = startGate;
    startGate = null;
    if (gate != null) await gate;
    final error = startError;
    if (error != null) throw error;
    return startOk;
  }

  @override
  Future<void> stop() async {
    log.add('segment-stop');
    final gate = stopGate;
    stopGate = null;
    if (gate != null) await gate;
    final error = stopError;
    if (error != null) throw error;
  }

  @override
  Future<void> cancel() async {
    log.add('segment-cancel');
    final error = cancelError;
    if (error != null) throw error;
  }

  @override
  Future<void> recreate() async {
    log.add('segment-recreate');
  }

  @override
  Future<void> dispose() async {
    log.add('segment-dispose');
    await _events.close();
  }

  /// Sends [event] to the engine, as the platform would.
  void send(SegmentedRecognizerEvent event) => _events.add(event);

  /// Sends a partial result.
  void sendPartial(String text) => send(SegmentedPartial(text));

  /// Sends a finished segment.
  void sendSegment(String text) => send(SegmentedSegment(text));

  /// Sends a normal end of session.
  void sendEndOfSession() => send(const SegmentedEndOfSession());

  /// Sends an error code.
  void sendError(int code) => send(SegmentedError(code));

  /// Sends an error on the event stream itself, as a broken channel would.
  void sendStreamError(Object error) => _events.addError(error);

  /// Completes the event stream, as a platform teardown would.
  Future<void> close() => _events.close();
}
