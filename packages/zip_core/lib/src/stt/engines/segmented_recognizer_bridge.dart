import 'package:flutter/foundation.dart';

/// One thing the platform's recogniser reported during a segmented session.
///
/// Sealed so a bridge implementation cannot invent an event the engine does
/// not understand, and so the engine can switch exhaustively.
@immutable
sealed class SegmentedRecognizerEvent {
  const SegmentedRecognizerEvent();
}

/// The recogniser is listening and will deliver partials and segments.
final class SegmentedReady extends SegmentedRecognizerEvent {
  /// Creates an event.
  const SegmentedReady();
}

/// A partial result: the words so far in the current segment.
final class SegmentedPartial extends SegmentedRecognizerEvent {
  /// Creates an event.
  const SegmentedPartial(this.text);

  /// The words so far. Untrimmed: the engine trims what it delivers.
  final String text;
}

/// A finished segment: one phrase, already final.
final class SegmentedSegment extends SegmentedRecognizerEvent {
  /// Creates an event.
  const SegmentedSegment(this.text);

  /// The segment's words. Later segments begin with a space on Android, so
  /// the engine trims before delivering.
  final String text;
}

/// The segmented session ended, normally. On Android this is
/// `onEndOfSegmentedSession`, which the recogniser sends when the requested
/// minimum length is reached.
final class SegmentedEndOfSession extends SegmentedRecognizerEvent {
  /// Creates an event.
  const SegmentedEndOfSession();
}

/// The recogniser reported an error code (Android's `ERROR_*` numbering).
final class SegmentedError extends SegmentedRecognizerEvent {
  /// Creates an event.
  const SegmentedError(this.code);

  /// The platform's error code, never inspected for text.
  final int code;
}

/// The platform side of a segmented recogniser session.
///
/// Declared here and implemented by the app (a method and event channel on
/// Android), the same split as the on-device support checker: the contract
/// lives in `zip_core`, the platform code in the runner.
///
/// Every method may throw, and an exception is the same as the platform
/// reporting a failure: the engine treats it as a transient error or a
/// failed start and never logs the exception's message.
abstract interface class SegmentedRecognizerBridge {
  /// Events from the recogniser, in order.
  ///
  /// A single broadcast stream for the lifetime of the bridge; the engine
  /// listens once, in its constructor.
  Stream<SegmentedRecognizerEvent> get events;

  /// Starts one segmented session for [localeId], ending it by itself after
  /// [minimumLengthMs] (Android needs an `int`, not a `long`).
  ///
  /// Returns `true` when the recogniser accepted the session.
  Future<bool> start({required String localeId, required int minimumLengthMs});

  /// Ends the session, keeping what was recognised.
  Future<void> stop();

  /// Ends the session, discarding it.
  Future<void> cancel();

  /// Destroys the recogniser and creates a new one (O-3).
  ///
  /// Used after the client or server connection died, where a stale
  /// recogniser would keep failing.
  Future<void> recreate();

  /// The on-device languages the recogniser knows, as BCP-47 tags
  /// (installed, pending and downloadable: BR-U10-50).
  Future<List<String>> supportedLocales();

  /// Releases the platform resources.
  Future<void> dispose();
}
