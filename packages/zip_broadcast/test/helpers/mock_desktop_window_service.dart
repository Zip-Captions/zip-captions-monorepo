import 'package:mocktail/mocktail.dart';
import 'package:zip_core/overlay.dart';

/// Mocktail mock for [DesktopWindowService].
///
/// Inject into `CaptionOverlayTarget` to test window management without
/// a native platform runner (Pattern 7, TEST-U3.2).
///
/// `setFrame` and `show` (added with the external display unit) are covered
/// by mocktail's `noSuchMethod`: each test stubs only the calls it exercises
/// and an unstubbed call fails the test. The class shape is unchanged.
class MockDesktopWindowService extends Mock implements DesktopWindowService {}
