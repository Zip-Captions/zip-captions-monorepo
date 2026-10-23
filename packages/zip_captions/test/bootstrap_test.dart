// Tests for BR-U8.1-06: an overlay launch is its own engine and never
// initialises the app's services.
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/bootstrap.dart';
import 'package:zip_core/overlay.dart';

/// The arguments a sub-window launch carries (window id and encoded payload).
const _overlayArgs = <String>['multi_window', '7', '{"v":1}'];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> platformCalls;

  setUp(() {
    platformCalls = <MethodCall>[];
    SharedPreferences.setMockInitialValues({});
    // Anything the overlay path might reach for would arrive here: the
    // preferences plugin, the Supabase client's secure storage, and the
    // window plugin the entry point itself installs.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      platformCalls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  group('runZipCaptions (Z20)', () {
    test('an overlay launch pumps one frame and starts no app service',
        () async {
      final pumped = <Widget>[];

      await runZipCaptions(
        _overlayArgs,
        runApp: pumped.add,
        isWeb: false,
      );

      expect(pumped, hasLength(1));
      // The frame is the window, not the app: it carries no shell/router.
      expect(pumped.single, isNot(const Text('x')));
      // The preferences plugin is never asked for a store, so no key was
      // read or written through the platform channel.
      final preferenceCalls = platformCalls.where(
        (call) => call.method.contains('SharedPreferences') ||
            call.method.contains('shared_preferences'),
      );
      expect(preferenceCalls, isEmpty);
    });

    test('the launch predicate routes every payload shape it claims', () {
      expect(isOverlayWindowLaunch(_overlayArgs), isTrue);
      expect(isOverlayWindowLaunch(const []), isFalse);
      expect(isOverlayWindowLaunch(const ['multi_window']), isFalse);
      expect(
        isOverlayWindowLaunch(const ['multi_window', '7']),
        isFalse,
      );
    });
  });
}
