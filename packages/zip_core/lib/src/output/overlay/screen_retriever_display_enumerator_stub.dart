import 'dart:ui';

import 'package:zip_core/src/output/overlay/display_enumerator.dart';

/// Web/mobile [DisplayEnumerator]: there are no displays to enumerate.
///
/// Reports an empty list and a stream that never emits, which is what makes
/// the external display target render nothing rather than fail (BR-U8-11).
/// No `screen_retriever` symbol is imported here (ID-3).
class ScreenRetrieverDisplayEnumerator implements DisplayEnumerator {
  bool _disposed = false;

  @override
  Future<List<DisplayInfo>> displays() async => const <DisplayInfo>[];

  @override
  Stream<List<DisplayInfo>> get changes =>
      const Stream<List<DisplayInfo>>.empty();

  @override
  Future<Size?> primarySize() async => null;

  @override
  Future<void> dispose() async {
    _disposed = true;
  }

  /// Whether [dispose] has been called. Test seam only.
  bool get isDisposed => _disposed;
}
