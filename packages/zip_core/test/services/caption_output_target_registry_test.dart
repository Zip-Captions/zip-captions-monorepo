import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';

import '../helpers/test_targets.dart';

void main() {
  late CaptionBus bus;
  late CaptionOutputTargetRegistry registry;

  setUp(() {
    bus = CaptionBus();
    registry = CaptionOutputTargetRegistry(bus);
  });

  tearDown(() {
    registry.dispose();
    bus.dispose();
  });

  SttResultEvent _makeEvent([String text = 'test']) => SttResultEvent(
        SttResult(
          text: text,
          isFinal: false,
          confidence: 1.0,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ),
      );

  group('CaptionOutputTargetRegistry', () {
    test('starts with no active targets', () {
      expect(registry.activeTargets, isEmpty);
    });

    test('add registers a target', () {
      final target = CollectingTarget();
      registry.add(target);

      expect(registry.activeTargets, contains(target));
      expect(registry.activeTargets, hasLength(1));
    });

    test('duplicate add is no-op', () {
      final target = CollectingTarget();
      registry.add(target);
      registry.add(target);

      expect(registry.activeTargets, hasLength(1));
    });

    test('remove unregisters and disposes target', () {
      final target = CollectingTarget();
      registry.add(target);
      registry.remove(target);

      expect(registry.activeTargets, isEmpty);
      expect(target.isDisposed, isTrue);
    });

    test('remove is no-op for unregistered target', () {
      final target = CollectingTarget();
      registry.remove(target);
      expect(registry.activeTargets, isEmpty);
    });

    test('events are delivered to registered targets', () async {
      final target = CollectingTarget();
      registry.add(target);

      bus.publish(_makeEvent());
      await Future<void>.delayed(Duration.zero);

      expect(target.received, hasLength(1));
    });

    test('events delivered to multiple targets', () async {
      final target1 = CollectingTarget(targetId: 'a');
      final target2 = CollectingTarget(targetId: 'b');
      registry.add(target1);
      registry.add(target2);

      bus.publish(_makeEvent());
      await Future<void>.delayed(Duration.zero);

      expect(target1.received, hasLength(1));
      expect(target2.received, hasLength(1));
    });

    test('removed target does not receive events', () async {
      final target = CollectingTarget();
      registry.add(target);
      registry.remove(target);

      bus.publish(_makeEvent());
      await Future<void>.delayed(Duration.zero);

      expect(target.received, isEmpty);
    });

    group('error isolation (REL-U1.1)', () {
      test('error in one target does not affect others', () async {
        final healthy = CollectingTarget(targetId: 'healthy');
        final throwing = ThrowingTarget(targetId: 'throwing');

        registry.add(healthy);
        registry.add(throwing);

        bus.publish(_makeEvent());
        await Future<void>.delayed(Duration.zero);

        expect(healthy.received, hasLength(1));
        expect(registry.activeTargets, hasLength(2));
      });

      test('throwing target remains registered after error', () async {
        final throwing = ThrowingTarget();
        registry.add(throwing);

        bus.publish(_makeEvent());
        await Future<void>.delayed(Duration.zero);

        expect(registry.activeTargets, contains(throwing));
      });
    });

    group('lazy subscription (Q5=B)', () {
      test('no bus subscription when empty', () async {
        // Publish an event — no targets, no errors
        bus.publish(_makeEvent());
        await Future<void>.delayed(Duration.zero);
      });

      test('subscription activates on first add', () async {
        final target = CollectingTarget();
        registry.add(target);

        bus.publish(_makeEvent());
        await Future<void>.delayed(Duration.zero);

        expect(target.received, hasLength(1));
      });

      test('subscription deactivates on last remove', () async {
        final target = CollectingTarget();
        registry.add(target);
        registry.remove(target);

        // Re-add a new target — should get a fresh subscription
        final target2 = CollectingTarget(targetId: 'new');
        registry.add(target2);

        bus.publish(_makeEvent());
        await Future<void>.delayed(Duration.zero);

        expect(target2.received, hasLength(1));
      });
    });

    group('dispose', () {
      test('disposes all targets and clears set', () {
        final target1 = CollectingTarget(targetId: 'a');
        final target2 = CollectingTarget(targetId: 'b');
        registry.add(target1);
        registry.add(target2);

        registry.dispose();

        expect(target1.isDisposed, isTrue);
        expect(target2.isDisposed, isTrue);
        expect(registry.activeTargets, isEmpty);
      });

      test('add is no-op after dispose', () {
        registry.dispose();
        final target = CollectingTarget();
        registry.add(target);

        expect(registry.activeTargets, isEmpty);
      });
    });

    test('activeTargets returns unmodifiable set', () {
      final target = CollectingTarget();
      registry.add(target);

      expect(
        () => registry.activeTargets.add(CollectingTarget(targetId: 'hack')),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
