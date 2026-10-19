import 'dart:ui' show FlutterView;

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'viewer_announcer_provider.g.dart';

/// The app's single status-announcement seam (Design Q5).
///
/// The view is passed by the widget using `View.of(context)` — the
/// underlying `SemanticsService.sendAnnouncement` API requires it, and
/// keeping it out of the provider lets widget tests record announcements
/// without a live view.
typedef ViewerAnnouncer = void Function(FlutterView view, String message);

/// Default announcer: a polite semantic announcement in left-to-right order.
@Riverpod(keepAlive: true)
ViewerAnnouncer viewerAnnouncer(Ref ref) =>
    (view, message) => SemanticsService.sendAnnouncement(
      view,
      message,
      TextDirection.ltr,
    );
