import 'package:zip_core/src/output/overlay/sub_window_closed_channel_io.dart';

/// The no-op close channel for platforms that cannot host a sub-window.
///
/// Nothing installs, nothing is ever emitted, and [dispose] does nothing
/// (BR-U8.1-11: web renders no pop-out and no external display at all).
class NoopSubWindowClosedChannel implements SubWindowClosedChannel {
  /// Creates the stub.
  const NoopSubWindowClosedChannel();

  /// Nothing to install.
  @override
  void install() {}

  /// Never emits.
  @override
  Stream<int> get closed => const Stream<int>.empty();

  /// Nothing to release.
  @override
  void dispose() {}
}
