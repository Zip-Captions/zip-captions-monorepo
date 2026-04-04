import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:zip_core/src/services/catalog/sherpa_model_manager.dart';

void main() {
  late Dio dio;
  late DioAdapter dioAdapter;
  late Directory tempDir;
  late SherpaModelManager manager;

  setUp(() async {
    dio = Dio();
    dioAdapter = DioAdapter(dio: dio);
    tempDir = await Directory.systemTemp.createTemp('sherpa_test_');
    manager = SherpaModelManager(dio: dio, storageDir: tempDir);
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('SherpaModelManager', () {
    group('deleteModel', () {
      test('removes model directory', () async {
        final modelDir = Directory('${tempDir.path}/test-model');
        await modelDir.create();
        await File('${modelDir.path}/model.bin').writeAsString('data');

        await manager.deleteModel('test-model');
        expect(modelDir.existsSync(), isFalse);
      });

      test('also removes partial file', () async {
        final partial = File('${tempDir.path}/test-model.partial');
        await partial.writeAsString('partial');

        await manager.deleteModel('test-model');
        expect(partial.existsSync(), isFalse);
      });

      test('no-op for non-existent model', () async {
        // Should not throw.
        await manager.deleteModel('nonexistent');
      });
    });

    group('modelLocalPath', () {
      test('returns path when model directory exists', () async {
        final modelDir = Directory('${tempDir.path}/my-model');
        await modelDir.create();

        expect(manager.modelLocalPath('my-model'), modelDir.path);
      });

      test('returns null when model directory does not exist', () {
        expect(manager.modelLocalPath('missing'), isNull);
      });
    });

    group('downloadedModels', () {
      test('returns empty when no catalog loaded', () {
        expect(manager.downloadedModels, isEmpty);
      });
    });

    group('bestModelForLocale', () {
      test('returns null when no models downloaded', () {
        expect(manager.bestModelForLocale('en-US'), isNull);
      });
    });

    group('cancelDownload', () {
      test('no-op when no active download', () {
        // Should not throw.
        manager.cancelDownload('nonexistent');
      });
    });
  });
}
