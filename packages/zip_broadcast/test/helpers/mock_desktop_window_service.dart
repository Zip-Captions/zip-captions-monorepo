import 'package:mocktail/mocktail.dart';
import 'package:zip_broadcast/src/output/overlay/desktop_window_service.dart';

/// Mocktail mock for [DesktopWindowService].
///
/// Inject into `CaptionOverlayTarget` to test window management without
/// a native platform runner (Pattern 7, TEST-U3.2).
class MockDesktopWindowService extends Mock implements DesktopWindowService {}
