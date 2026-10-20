import 'package:zip_broadcast/src/output/overlay/display_info.dart';

/// The display BR-U8-07 opens the window on, and whether the persisted id
/// still names a connected display.
typedef OpenDisplayResolution = ({
  DisplayInfo? target,
  bool persistedIdPresent,
});

/// Resolves which display the external display window opens on (BR-U8-07).
///
/// The persisted selection wins when it still names a connected display;
/// otherwise the primary display, otherwise the first display in platform
/// order. The result reports whether the persisted id was found so the caller
/// can keep it — an absent id is what `WaitingForDisplay` waits for (D-4) and
/// is cleared only by an explicit user selection, never here. This function
/// has no write path for that reason.
OpenDisplayResolution resolveOpenDisplay(
  List<DisplayInfo> displays,
  String? persistedId,
) {
  if (persistedId != null && persistedId.isNotEmpty) {
    for (final display in displays) {
      if (display.id == persistedId) {
        return (target: display, persistedIdPresent: true);
      }
    }
  }

  for (final display in displays) {
    if (display.isPrimary) {
      return (target: display, persistedIdPresent: false);
    }
  }

  return (
    target: displays.isEmpty ? null : displays.first,
    persistedIdPresent: false,
  );
}
