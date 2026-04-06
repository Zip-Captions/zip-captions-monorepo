import 'package:flutter_test/flutter_test.dart';
import 'package:glados/glados.dart' hide addTearDown, expect, group, test;

import '../helpers/generators.dart';

void main() {
  group('SherpaModelInfo PBT', () {
    Glados(arbitrarySherpaModelInfo).test(
      'isDownloaded=true implies localPath is not null',
      (info) {
        if (info.isDownloaded) {
          expect(info.localPath, isNotNull);
        }
      },
    );

    Glados(arbitrarySherpaModelInfo).test(
      'isDownloaded=false implies localPath is null',
      (info) {
        if (!info.isDownloaded) {
          expect(info.localPath, isNull);
        }
      },
    );

    Glados(arbitrarySherpaModelInfo).test(
      'catalogEntry is always present',
      (info) {
        expect(info.catalogEntry, isNotNull);
      },
    );
  });
}
