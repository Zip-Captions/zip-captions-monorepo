import 'package:mocktail/mocktail.dart';
import 'package:permission_handler_platform_interface/permission_handler_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// Mocktail mock for [PermissionHandlerPlatform].
///
/// Register as the platform instance in setUp:
/// ```dart
/// PermissionHandlerPlatform.instance = mockPermissionHandler;
/// ```
class MockPermissionHandlerPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PermissionHandlerPlatform {}
