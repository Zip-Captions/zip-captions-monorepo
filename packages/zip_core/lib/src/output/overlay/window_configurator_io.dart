import 'package:zip_core/src/output/overlay/window_configurator.dart';

/// The io [WindowConfigurator]: the per-runner `configure` channel.
WindowConfigurator createWindowConfigurator() =>
    MethodChannelWindowConfigurator();
