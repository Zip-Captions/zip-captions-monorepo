import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;

import '../helpers/generators.dart';

void main() {
  group('SherpaModelDownloadProgress PBT', () {
    Glados(arbitrarySherpaModelDownloadProgress).test(
      'downloadedBytes <= totalBytes',
      (progress) {
        expect(
          progress.downloadedBytes,
          lessThanOrEqualTo(progress.totalBytes),
        );
      },
    );

    Glados(arbitrarySherpaModelDownloadProgress).test(
      'totalBytes > 0',
      (progress) {
        expect(progress.totalBytes, greaterThan(0));
      },
    );

    Glados(arbitrarySherpaModelDownloadProgress).test(
      'modelId is never empty',
      (progress) {
        expect(progress.modelId, isNotEmpty);
      },
    );
  });
}
