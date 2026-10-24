// Compile-only test for the two public libraries (NFR-R §5.2; R-M7).
//
// `package:zip_core/overlay.dart` and `package:zip_core/zip_core.dart` each
// export a `Failed` (the status variant and the connection-state variant). This
// file imports both without hiding either, so it stops compiling the moment
// the barrel is re-exported from `zip_core.dart` and every importer's `Failed`
// becomes ambiguous.
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

void main() {
  test('the overlay barrel and the main library coexist', () {
    // Both names resolve to their own library's declaration. A re-export would
    // make these two lines a compile error rather than a test failure.
    expect(const OverlayWindowConfig(), isA<OverlayWindowConfig>());
    expect(popOutSessionActive(const RecordingState.idle()), isFalse);
  });

  test('the barrel exports the geometry and availability seams', () {
    // The status types are still `zip_broadcast`'s until the move, so only the
    // parts this library already owns are exercised here.
    expect(PopOutGeometry.minWidth, 320);
    expect(PopOutUnavailableReason.values, hasLength(2));
  });
}
