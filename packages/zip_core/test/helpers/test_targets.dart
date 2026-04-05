import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/services/caption/caption_output_target.dart';

/// Collects all received events for assertion.
class CollectingTarget implements CaptionOutputTarget {
  CollectingTarget({this.targetId = 'collecting'});

  @override
  final String targetId;

  final received = <CaptionEvent>[];
  bool isDisposed = false;

  @override
  void onCaptionEvent(CaptionEvent event) => received.add(event);

  @override
  void dispose() {
    isDisposed = true;
  }
}

/// Throws on every event.
class ThrowingTarget implements CaptionOutputTarget {
  ThrowingTarget({this.targetId = 'throwing'});

  @override
  final String targetId;

  bool isDisposed = false;

  @override
  void onCaptionEvent(CaptionEvent event) =>
      throw Exception('ThrowingTarget failure');

  @override
  void dispose() {
    isDisposed = true;
  }
}
