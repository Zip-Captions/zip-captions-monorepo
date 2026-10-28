// Tests for Amendment 04 TP-28 (BR-U10-46): the panel action is a total, pure
// function of (platform, OS version, language-pack status).
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zip_captions/src/widgets/language_pack_action.dart';
import 'package:zip_core/zip_core.dart';

import '../helpers/pbt.dart' as pbt;

const LanguagePackAction _download = LanguagePackAction.download;
const LanguagePackAction _scheduled = LanguagePackAction.scheduled;
const LanguagePackAction _instructions = LanguagePackAction.instructions;
const LanguagePackAction _none = LanguagePackAction.none;

LanguagePackAction _act(
  TargetPlatform platform,
  int? osVersion,
  LanguagePackStatus status,
) => languagePackActionFor(
  platform: platform,
  osVersion: osVersion,
  status: status,
);

void main() {
  group('TP-28 example table', () {
    // status order: installed, downloading, downloadable, unsupported, unknown
    final table = <String, List<LanguagePackAction>>{
      // iOS 26 and later: by status.
      'iOS 26': [_none, _scheduled, _download, _none, _instructions],
      'iOS 27': [_none, _scheduled, _download, _none, _instructions],
      // iOS below 26: the instructions, whatever the status says.
      'iOS 25': [
        _instructions,
        _instructions,
        _instructions,
        _instructions,
        _instructions,
      ],
      'iOS 13': [
        _instructions,
        _instructions,
        _instructions,
        _instructions,
        _instructions,
      ],
      // Android: by status, the SDK never changes the answer; unknown shows
      // nothing extra.
      'Android 33': [_none, _scheduled, _download, _none, _none],
      'Android 34': [_none, _scheduled, _download, _none, _none],
      'Android 31': [_none, _scheduled, _download, _none, _none],
    };
    for (final entry in table.entries) {
      final parts = entry.key.split(' ');
      final platform = parts[0] == 'iOS'
          ? TargetPlatform.iOS
          : TargetPlatform.android;
      final version = int.parse(parts[1]);
      for (final status in LanguagePackStatus.values) {
        test('${entry.key} + ${status.name} -> '
            '${entry.value[status.index].name}', () {
          expect(_act(platform, version, status), entry.value[status.index]);
        });
      }
    }

    test('an unreadable iOS version is judged by the status alone', () {
      expect(
        _act(TargetPlatform.iOS, null, LanguagePackStatus.downloadable),
        _download,
      );
      expect(
        _act(TargetPlatform.iOS, null, LanguagePackStatus.unknown),
        _instructions,
      );
    });

    test('every other platform gets no action', () {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.fuchsia,
      ]) {
        for (final status in LanguagePackStatus.values) {
          expect(_act(platform, null, status), _none, reason: '$platform');
        }
      }
    });
  });

  group('TP-28 property over the cross product (PBT-10)', () {
    final gen = pbt.any.combine3<TargetPlatform, int?, LanguagePackStatus,
        ({TargetPlatform p, int? v, LanguagePackStatus s})>(
      pbt.any.choose(TargetPlatform.values),
      pbt.any.choose<int?>([null, 13, 16, 24, 25, 26, 27, 30, 31, 33, 34, 36]),
      pbt.any.choose(LanguagePackStatus.values),
      (p, v, s) => (p: p, v: v, s: s),
    );

    pbt.Glados(gen).test('total, and equal to the BR-U10-46 rules in words', (
      c,
    ) {
      final action = _act(c.p, c.v, c.s);

      // Total: exactly one of the four.
      expect(LanguagePackAction.values, contains(action));

      // The rules, restated independently of the implementation.
      final LanguagePackAction expected;
      final iosOld = c.p == TargetPlatform.iOS && c.v != null && c.v! < 26;
      if (c.p != TargetPlatform.iOS && c.p != TargetPlatform.android) {
        expected = _none;
      } else if (iosOld) {
        expected = _instructions;
      } else if (c.s == LanguagePackStatus.downloadable) {
        expected = _download;
      } else if (c.s == LanguagePackStatus.downloading) {
        expected = _scheduled;
      } else if (c.s == LanguagePackStatus.unknown &&
          c.p == TargetPlatform.iOS) {
        expected = _instructions;
      } else {
        expected = _none;
      }
      expect(action, expected, reason: '${c.p} ${c.v} ${c.s}');

      // Pure: asking again gives the same answer.
      expect(_act(c.p, c.v, c.s), action);
    });

    pbt.Glados(gen).test('the Android SDK never changes the answer', (c) {
      if (c.p != TargetPlatform.android) return;
      expect(_act(c.p, c.v, c.s), _act(c.p, null, c.s));
    });
  });
}
