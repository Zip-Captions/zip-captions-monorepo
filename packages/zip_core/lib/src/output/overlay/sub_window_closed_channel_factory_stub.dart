import 'package:logging/logging.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';

/// The web/mobile close channel: nothing installs and nothing emits.
SubWindowClosedChannel createMethodChannelSubWindowClosedChannel({
  Logger? log,
}) =>
    const NoopSubWindowClosedChannel();
