import 'package:zip_core/zip_core.dart';

/// [CaptionBus] subclass that records published events for assertion.
///
/// Backs `BroadcastRecordingNotifier` unit tests verifying that [SttResult]
/// events carry the correct `sourceId` before publication (TEST-U6.2 row 7).
class MockCaptionBus extends CaptionBus {
  /// All events published via [publish].
  final List<CaptionEvent> published = [];

  @override
  void publish(CaptionEvent event) {
    published.add(event);
    super.publish(event); // keep stream subscribers notified
  }
}
