import 'dart:ui';

import 'package:zip_broadcast/src/output/overlay/display_info.dart';

export 'package:zip_broadcast/src/output/overlay/display_info.dart';

/// Enumerates the connected displays and reports changes to them.
///
/// The rest of the package sees only this type: the `screen_retriever` API
/// lives in the io adapter alone (ID-3, SECURITY-10 section 5 item 4).
///
/// ### Event contract (BR-U8-05)
///
/// [changes] is a **broadcast** stream:
///
/// - **First emission.** The current display list is delivered to a listener
///   that subscribes at any time, not only to listeners present before the
///   first platform event.
/// - **Connect / disconnect.** A list with the new display or without the
///   removed one, in platform order.
/// - **Rearrangement.** A list with the same ids but different bounds or
///   primary flag. Consumers must not treat a same-id list as "no change": a
///   geometry change re-frames the open window (BR-U8-09).
/// - **No change.** No emission; the adapter does not synthesise a poll.
/// - **Error.** A platform failure is logged at `warning` with a fixed string.
///   The stream does not emit an error and does not close: a transient
///   platform hiccup must not kill the fallback listener.
/// - **Close.** Only on [dispose], which is idempotent.
/// - **Duplicates.** Adjacent equal lists are coalesced; a same-id list with
///   changed geometry is not equal and is emitted.
abstract interface class DisplayEnumerator {
  /// The displays connected right now, in platform order.
  Future<List<DisplayInfo>> displays();

  /// Display-list changes, per the contract above.
  Stream<List<DisplayInfo>> get changes;

  /// The primary display's **full** size, menu bar included.
  ///
  /// Only macOS's frame conversion needs it: `setFrame` takes Cocoa
  /// bottom-left coordinates, so the flip is against the primary's full height
  /// rather than its visible height (B-1). `null` when no display is known.
  Future<Size?> primarySize();

  /// Releases the platform listener. Idempotent.
  Future<void> dispose();
}
