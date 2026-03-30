import 'package:zip_core/src/models/caption_event.dart';

/// Abstract interface for any consumer of caption events.
///
/// Implementations receive events via [onCaptionEvent] when registered
/// with the [CaptionOutputTargetRegistry].
///
/// **Security (SECURITY-03)**: Implementations must not log transcript
/// text from [SttResultEvent].
abstract interface class CaptionOutputTarget {
  /// Unique identifier for this target instance.
  String get targetId;

  /// Handle an incoming caption event.
  void onCaptionEvent(CaptionEvent event);

  /// Release resources.
  void dispose();
}
