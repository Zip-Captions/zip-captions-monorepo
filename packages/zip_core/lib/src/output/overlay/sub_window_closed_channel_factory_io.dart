import 'package:logging/logging.dart';
import 'package:zip_core/src/output/overlay/sub_window_closed_channel.dart';

/// The production close channel, on the main engine's `MethodChannel`.
SubWindowClosedChannel createMethodChannelSubWindowClosedChannel({
  Logger? log,
}) =>
    MethodChannelSubWindowClosedChannel(log: log);
