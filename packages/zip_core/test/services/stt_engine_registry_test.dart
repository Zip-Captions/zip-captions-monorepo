import 'package:flutter_test/flutter_test.dart';
import 'package:zip_core/src/services/stt/stt_engine_registry.dart';

import '../helpers/mock_stt_engine.dart';

void main() {
  late SttEngineRegistry registry;

  setUp(() {
    registry = SttEngineRegistry();
  });

  group('SttEngineRegistry', () {
    test('starts empty', () {
      expect(registry.listAvailable(), isEmpty);
      expect(registry.defaultEngine, isNull);
    });

    test('register adds an engine', () {
      final engine = MockSttEngine(engineId: 'test');
      registry.register(engine);

      expect(registry.listAvailable(), hasLength(1));
      expect(registry.getEngine('test'), same(engine));
    });

    test('getEngine returns null for unregistered id', () {
      expect(registry.getEngine('nonexistent'), isNull);
    });

    test('defaultEngine returns first registered engine', () {
      final first = MockSttEngine(engineId: 'first');
      final second = MockSttEngine(engineId: 'second');
      registry.register(first);
      registry.register(second);

      expect(registry.defaultEngine, same(first));
    });

    test('duplicate register replaces (last-write-wins)', () {
      final original = MockSttEngine(engineId: 'dup', displayName: 'Original');
      final replacement =
          MockSttEngine(engineId: 'dup', displayName: 'Replacement');

      registry.register(original);
      registry.register(replacement);

      expect(registry.listAvailable(), hasLength(1));
      expect(registry.getEngine('dup'), same(replacement));
    });

    test('unregister removes an engine', () {
      final engine = MockSttEngine(engineId: 'rem');
      registry.register(engine);
      registry.unregister('rem');

      expect(registry.listAvailable(), isEmpty);
      expect(registry.getEngine('rem'), isNull);
    });

    test('unregister is no-op for unknown id', () {
      registry.unregister('nonexistent');
      expect(registry.listAvailable(), isEmpty);
    });

    test('listAvailable returns unmodifiable list', () {
      final engine = MockSttEngine(engineId: 'test');
      registry.register(engine);

      final list = registry.listAvailable();
      expect(() => list.add(MockSttEngine()), throwsA(isA<UnsupportedError>()));
    });

    test('defaultEngine updates when first engine is removed', () {
      final first = MockSttEngine(engineId: 'first');
      final second = MockSttEngine(engineId: 'second');
      registry.register(first);
      registry.register(second);

      registry.unregister('first');
      expect(registry.defaultEngine, same(second));
    });

    test('defaultEngine is null after all removed', () {
      final engine = MockSttEngine(engineId: 'only');
      registry.register(engine);
      registry.unregister('only');

      expect(registry.defaultEngine, isNull);
    });
  });
}
