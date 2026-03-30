import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:zip_core/src/models/caption_event.dart';
import 'package:zip_core/src/models/stt_result.dart';
import 'package:zip_core/src/services/caption/caption_bus.dart';
import 'package:zip_core/src/services/caption/caption_output_target_registry.dart';

import '../helpers/test_targets.dart';

void main() {
  group('CaptionBus + Registry PBT', () {
    Glados(any.intInRange(1, 20)).test(
      'all targets receive every published event',
      (targetCount) async {
        final bus = CaptionBus();
        final registry = CaptionOutputTargetRegistry(bus);
        addTearDown(() {
          registry.dispose();
          bus.dispose();
        });

        final targets = List.generate(
          targetCount,
          (i) => CollectingTarget(targetId: 'target-$i'),
        );
        for (final t in targets) {
          registry.add(t);
        }

        final event = SttResultEvent(SttResult(
          text: 'test',
          isFinal: false,
          confidence: 1.0,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ));

        bus.publish(event);
        await Future<void>.delayed(Duration.zero);

        for (final t in targets) {
          expect(
            t.received,
            hasLength(1),
            reason: 'Target ${t.targetId} should have received 1 event',
          );
        }
      },
    );

    Glados(any.intInRange(1, 10)).test(
      'error isolation: throwing targets do not block healthy targets',
      (healthyCount) async {
        final bus = CaptionBus();
        final registry = CaptionOutputTargetRegistry(bus);
        addTearDown(() {
          registry.dispose();
          bus.dispose();
        });

        final healthyTargets = List.generate(
          healthyCount,
          (i) => CollectingTarget(targetId: 'healthy-$i'),
        );
        final throwingTarget = ThrowingTarget(targetId: 'thrower');

        // Add throwing first, then healthy — worst case ordering
        registry.add(throwingTarget);
        for (final t in healthyTargets) {
          registry.add(t);
        }

        final event = SttResultEvent(SttResult(
          text: 'test',
          isFinal: false,
          confidence: 1.0,
          timestamp: DateTime.utc(2026),
          sourceId: 'default',
        ));

        bus.publish(event);
        await Future<void>.delayed(Duration.zero);

        for (final t in healthyTargets) {
          expect(
            t.received,
            hasLength(1),
            reason:
                'Target ${t.targetId} should receive event despite thrower',
          );
        }

        // All targets still registered
        expect(
          registry.activeTargets,
          hasLength(healthyCount + 1),
        );
      },
    );

    test('bus sustains 20 events/sec (PERF-U1.1)', () async {
      final bus = CaptionBus();
      final registry = CaptionOutputTargetRegistry(bus);
      final target = CollectingTarget();
      registry.add(target);

      final events = List.generate(
        20,
        (i) => SttResultEvent(SttResult(
          text: 'word $i',
          isFinal: false,
          confidence: 1.0,
          timestamp: DateTime.utc(2026),
          sourceId: 'test',
        )),
      );

      final sw = Stopwatch()..start();
      for (final event in events) {
        bus.publish(event);
      }
      await Future<void>.delayed(Duration.zero);
      sw.stop();

      expect(target.received, hasLength(20));
      expect(sw.elapsedMilliseconds, lessThan(1000));

      registry.dispose();
      bus.dispose();
    });
  });
}
