// Tests for BR-U8.1-06: an overlay launch is its own engine and never
// initialises the app's services.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_captions/src/bootstrap.dart';
import 'package:zip_captions/src/services/stt_engine_registration.dart';
import 'package:zip_core/overlay.dart';
import 'package:zip_core/zip_core.dart';

/// A real pop-out launch payload: `encodeLaunch` with [PopOutMode], which is
/// the shape the main engine actually sends (0.2.1: always three arguments).
OverlayWindowLaunch _popOutLaunch() => OverlayWindowLaunch(
  config: const OverlayConfig(mode: PopOutMode()),
  snapshot: CaptionOverlaySnapshot(
    activity: OverlayActivity.live,
    entries: const <CaptionDisplayEntry>[],
    settings: DisplaySettings.defaults(),
  ),
);

/// The arguments a sub-window launch carries (window id and encoded payload).
List<String> _overlayArgs({
  OverlayWindowLaunch? launch,
  String windowId = '7',
}) => <String>[
  'multi_window',
  windowId,
  encodeLaunch(launch ?? _popOutLaunch()),
];

/// A stand-in for the platform engine, distinguished only by `engineId`.
class _PlatformEngineStub implements SttEngine {
  @override
  String get engineId => 'platform';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// The engine factories only hold the audio service; nothing here calls it.
class _FakeAudioDeviceService implements AudioDeviceService {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<MethodCall> platformCalls;

  setUp(() {
    // The window applies its own properties through this channel, inside its
    // own engine, before it pumps. The device under test has no native side.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel(WindowConfiguratorChannel.name),
          (call) async => null,
        );
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
      ..setMockMethodCallHandler(SystemChannels.platform, null)
      ..setMockMethodCallHandler(
        const MethodChannel(WindowConfiguratorChannel.name),
        null,
      );
  });

  group('runZipCaptions (Z20)', () {
    test(
      'an overlay launch pumps one frame and starts no app service',
      () async {
        final pumped = <Widget>[];

        await runZipCaptions(
          _overlayArgs(),
          runApp: pumped.add,
          isWeb: false,
        );

        expect(pumped, hasLength(1));
        // The frame is the window, not the app: it carries no shell/router.
        expect(pumped.single, isNot(const Text('x')));
        // The preferences plugin is never asked for a store, so no key was
        // read or written through the platform channel.
        final preferenceCalls = platformCalls.where(
          (call) =>
              call.method.contains('SharedPreferences') ||
              call.method.contains('shared_preferences'),
        );
        expect(preferenceCalls, isEmpty);
      },
    );

    testWidgets('a real pop-out payload decodes and reaches the window', (
      tester,
    ) async {
      // A payload that does not decode builds "Window unavailable", so this
      // proves the branch is the window and the payload is a real launch.
      expect(decodeLaunch(_overlayArgs().last), isNotNull);

      // A decoded launch builds the window body; the unavailable frame is
      // never reached. The entry calls `pump` after it configures, so mounting
      // the recorded widget here is deterministic.
      final pumped = <Widget>[];

      await runZipCaptions(
        _overlayArgs(),
        runApp: pumped.add,
        isWeb: false,
      );

      expect(pumped, hasLength(1));
      await tester.pumpWidget(pumped.single);
      await tester.pump();

      expect(find.byType(OverlayWindowEntry), findsOneWidget);
      expect(find.text(overlayWindowUnavailableMessage), findsNothing);
    });

    testWidgets('a good payload configures the window before it pumps', (
      tester,
    ) async {
      // The window applies its own properties, in its own engine, before it
      // signals ready or draws (BR-U8.1-05, FD BLM §3.2 step 6).
      final order = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel(WindowConfiguratorChannel.name),
            (call) async {
              if (call.method == WindowConfiguratorChannel.method) {
                order.add('configure');
              }
              return null;
            },
          );

      final pumped = <Widget>[];
      await runZipCaptions(
        _overlayArgs(),
        runApp: (widget) {
          order.add('pump');
          pumped.add(widget);
        },
        isWeb: false,
      );
      await tester.pump();

      expect(pumped, hasLength(1));
      expect(order.first, 'configure');
      expect(
        order.where((step) => step == 'configure'),
        hasLength(1),
        reason: 'the window configures itself exactly once',
      );
      // `configure` rides its own channel, not the platform channel the
      // app services would use.
      expect(
        platformCalls.where(
          (call) => call.method == WindowConfiguratorChannel.method,
        ),
        isEmpty,
      );
    });

    test('the launch predicate routes every payload shape it claims', () {
      final args = _overlayArgs();
      expect(isOverlayWindowLaunch(args), isTrue);
      expect(isOverlayWindowLaunch(const []), isFalse);
      expect(isOverlayWindowLaunch(const ['multi_window']), isFalse);
      // 0.2.1 always passes three arguments, so a two-argument launch is not
      // the contract any more and is not routed as one.
      expect(
        isOverlayWindowLaunch(['multi_window', '7']),
        isFalse,
      );
      // The window id is a parse, not a passthrough.
      expect(
        int.tryParse(args[1]),
        7,
      );
    });
  });

  // Unit 10, Step 23 (P5, P6; BR-U10-03, 05) and Step G7: the app build wires
  // the audio service, the engine registry and the on-device checker.
  group('registerSttEngines wiring (Unit 10)', () {
    test('the registration is driven only by its arguments, iOS taking the '
        'platform closure', () {
      // The seam is pure, so the bootstrap can pass compile-time constants
      // and a release build strips the fake. This pins the two flag shapes the
      // bootstrap is required to pass.
      final registry = SttEngineRegistry();
      var platformCalls = 0;
      var segmentedCalls = 0;
      registerSttEngines(
        registry,
        platform: TargetPlatform.iOS,
        isWeb: false,
        allowDevEngines: false,
        forceFake: false,
        createPlatformEngine: () {
          platformCalls++;
          return _PlatformEngineStub();
        },
        createSegmentedEngine: () {
          segmentedCalls++;
          return _PlatformEngineStub();
        },
      );
      expect(registry.listAvailable(), hasLength(1));
      expect(registry.getEngine('fake'), isNull);
      expect(platformCalls, 1);
      expect(segmentedCalls, 0, reason: 'iOS keeps PlatformSttEngine');
    });

    test('the Android registration takes the segmented closure, not the '
        'platform one (G7)', () {
      final registry = SttEngineRegistry();
      var platformCalls = 0;
      var segmentedCalls = 0;
      registerSttEngines(
        registry,
        platform: TargetPlatform.android,
        isWeb: false,
        allowDevEngines: false,
        forceFake: false,
        createPlatformEngine: () {
          platformCalls++;
          return _PlatformEngineStub();
        },
        createSegmentedEngine: () {
          segmentedCalls++;
          return _PlatformEngineStub();
        },
      );
      expect(registry.listAvailable(), hasLength(1));
      expect(registry.getEngine('platform')!.engineId, 'platform');
      expect(registry.getEngine('fake'), isNull);
      expect(platformCalls, 0, reason: 'Android never reaches speech_to_text');
      expect(segmentedCalls, 1);
    });

    // Q-7: the call site, not only the seam. The old tests passed a typed
    // literal, so a bootstrap that handed over a differently spelled platform
    // name went unseen and an iOS debug build captioned with the dev fake.
    // `runZipCaptions` itself cannot run here: it opens the on-disk transcript
    // database (native path and SQLite plugins) and keeps its container
    // private, so the registration call it makes is `registerAppSttEngines`,
    // run under the platform override. `flutter test` is a debug build, so the
    // dev fake is allowed and the registry must still not choose it.
    test('Q-7: on iOS the app registers the platform engine, not the fake', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final registry = SttEngineRegistry();

      registerAppSttEngines(
        registry,
        audioDeviceService: _FakeAudioDeviceService(),
      );

      expect(registry.getEngine('fake'), isNull);
      expect(registry.getEngine('platform'), isA<PlatformSttEngine>());
      expect(registry.listAvailable(), hasLength(1));
    });

    test('Q-7: on Android the app registers the segmented engine, not the '
        'fake', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final registry = SttEngineRegistry();

      registerAppSttEngines(
        registry,
        audioDeviceService: _FakeAudioDeviceService(),
      );

      expect(registry.getEngine('fake'), isNull);
      expect(registry.getEngine('platform'), isA<SegmentedSpeechEngine>());
    });

    test('Q-7: on macOS the app registers only the dev fake', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final registry = SttEngineRegistry();

      registerAppSttEngines(
        registry,
        audioDeviceService: _FakeAudioDeviceService(),
      );

      expect(registry.listAvailable().map((e) => e.engineId), ['fake']);
    });

    test('audioDeviceServiceProvider throws without an override', () {
      // Bootstrap's contract is to override it on every platform; if it ever
      // stops, this is the failure a user would see.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(audioDeviceServiceProvider),
        throwsA(isA<UnimplementedError>()),
      );
    });
  });
}
