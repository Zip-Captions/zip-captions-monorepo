import 'package:zip_core/src/output/overlay/window_configurator.dart';

/// The web/mobile [WindowConfigurator]: a no-op (BR-U8.1-11).
WindowConfigurator createWindowConfigurator() => const NoopWindowConfigurator();
