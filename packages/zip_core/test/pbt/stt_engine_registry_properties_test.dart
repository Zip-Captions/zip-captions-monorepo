import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';

import '../helpers/generators.dart';
import '../helpers/mock_stt_engine.dart';

void main() {
  group('SttEngineRegistry PBT', () {
    Glados(arbitraryRegistryOps).test(
      'register/get round-trip: registered engines are always retrievable',
      (ops) {
        final registry = SttEngineRegistry();
        final registeredIds = <String>{};

        for (final op in ops) {
          switch (op) {
            case RegistryOp.register:
              final id = 'engine-${registeredIds.length}';
              registry.register(MockSttEngine(engineId: id));
              registeredIds.add(id);
            case RegistryOp.unregister:
              if (registeredIds.isNotEmpty) {
                final id = registeredIds.first;
                registry.unregister(id);
                registeredIds.remove(id);
              }
            case RegistryOp.get:
              for (final id in registeredIds) {
                expect(
                  registry.getEngine(id),
                  isNotNull,
                  reason: 'Engine $id should be retrievable',
                );
              }
          }
        }

        // Final invariant: all remaining registered IDs are retrievable
        for (final id in registeredIds) {
          expect(registry.getEngine(id), isNotNull);
        }
      },
    );

    Glados(arbitraryRegistryOps).test(
      'defaultEngine is null iff registry is empty',
      (ops) {
        final registry = SttEngineRegistry();
        final registeredIds = <String>{};

        for (final op in ops) {
          switch (op) {
            case RegistryOp.register:
              final id = 'engine-${registeredIds.length}';
              registry.register(MockSttEngine(engineId: id));
              registeredIds.add(id);
            case RegistryOp.unregister:
              if (registeredIds.isNotEmpty) {
                final id = registeredIds.first;
                registry.unregister(id);
                registeredIds.remove(id);
              }
            case RegistryOp.get:
              break;
          }
        }

        if (registeredIds.isEmpty) {
          expect(registry.defaultEngine, isNull);
        } else {
          expect(registry.defaultEngine, isNotNull);
        }
      },
    );

    Glados(any.intInRange(1, 20)).test(
      'listAvailable length matches registered count',
      (count) {
        final registry = SttEngineRegistry();
        for (var i = 0; i < count; i++) {
          registry.register(MockSttEngine(engineId: 'e-$i'));
        }
        expect(registry.listAvailable(), hasLength(count));
      },
    );
  });
}
