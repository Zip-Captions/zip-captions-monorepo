// Tests for Unit 8.1 (S-21): the package fence (NFR-R §5.1; BR-U8.1-02).
// T34 / N-14.
//
// Three static checks, run against the working tree rather than a fresh
// checkout, because they describe the source tree this package ships from:
//  1. no app `lib/` file imports a window plugin directly;
//  2. `window_manager` appears nowhere in any package;
//  3. `package:zip_core/overlay.dart` is a separate library: the main library
//     does not export it (it would make `Failed` ambiguous).
//
// The plugin import is allowed in exactly one production file per plugin
// inside `zip_core`: `screen_retriever_display_enumerator_io.dart` for
// `screen_retriever`, and the `_io` service for `desktop_multi_window`. The
// check below asserts the apps, not `zip_core`: `zip_core` is where the fence
// lives, so it is where the plugins are allowed to appear.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _pluginImport = 'package:desktop_multi_window';
const _retrieverImport = 'package:screen_retriever';

/// The repository's `packages/` directory, resolved from the package root the
/// test runs in (`packages/zip_core`).
Directory get _packages => Directory('../');

bool _isDart(File file) => file.path.endsWith('.dart');

List<File> _dartFiles(Directory root, String subdirectory) {
  final directory = Directory('${root.path}/$subdirectory');
  if (!directory.existsSync()) return const <File>[];
  return directory
      .listSync(recursive: true)
      .whereType<File>()
      .where(_isDart)
      // This file names `window_manager` in order to forbid it, so it is the
      // one file the check cannot inspect without failing itself.
      .where((file) => !file.path.endsWith('refactor_fence_test.dart'))
      .toList();
}

void main() {
  group('refactor fence', () {
    test('no app lib/ file imports a window plugin', () {
      final offenders = <String>[];
      for (final app in const ['zip_broadcast', 'zip_captions']) {
        for (final file in _dartFiles(_packages, '$app/lib')) {
          final source = file.readAsStringSync();
          if (source.contains(_pluginImport) ||
              source.contains(_retrieverImport)) {
            offenders.add(file.path);
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('window_manager appears nowhere in any package', () {
      final offenders = <String>[];
      for (final package in const [
        'zip_core',
        'zip_broadcast',
        'zip_captions',
      ]) {
        for (final subdirectory in const ['lib', 'test']) {
          for (final file in _dartFiles(_packages, '$package/$subdirectory')) {
            if (file.readAsStringSync().contains('window_manager')) {
              offenders.add(file.path);
            }
          }
        }
      }
      expect(offenders, isEmpty);
    });

    test('the overlay barrel is not re-exported from zip_core.dart', () {
      final source = File('lib/zip_core.dart').readAsStringSync();
      expect(source.contains('overlay.dart'), isFalse);
    });
  });
}
