import 'package:zip_core/zip_core.dart';

/// Navigation arguments handed to the viewer route.
///
/// A parsed [BroadcastId] from the join screen, or `null` when the viewer
/// was reached from a deep link that still has to be parsed (and may be
/// invalid — the viewer then settles on `ViewerInvalidInputState`).
class ViewerRouteArgs {
  /// Creates the route arguments.
  const ViewerRouteArgs({this.broadcastId});

  /// The already-parsed ID, when the join screen supplied one.
  final BroadcastId? broadcastId;
}
