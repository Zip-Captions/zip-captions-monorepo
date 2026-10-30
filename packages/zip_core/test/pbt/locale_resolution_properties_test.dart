// TP-25 (Amendment 03 section 6): locale resolution over generated supported
// and device lists. One property: the provider's answer equals an independent
// implementation of the section-6 resolution order, and when nothing matches,
// the answer is exactly 'en-CA' — never an arbitrary supported locale and
// never a missed match.
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zip_core/src/models/speech_locale.dart';
import 'package:zip_core/src/providers/base_settings_notifier.dart';
import 'package:zip_core/src/providers/device_locales_provider.dart';
import 'package:zip_core/src/providers/locale_info_provider.dart';
import 'package:zip_core/src/providers/resolved_locale_id_provider.dart';

import '../helpers/pbt.dart' as pbt;

const _languages = ['en', 'fr', 'de', 'cmn', 'es'];
const _regions = ['US', 'CA', 'GB', 'AU', 'CN', 'MX'];
const _scripts = ['Hant', 'Hans', 'Latn'];

/// A generated locale tag: `lang`, or `lang` + a `-`/`_` + region, with
/// random casing so separator- and case-insensitivity are exercised.
String _generateTag(Random r) {
  final language = _languages[r.nextInt(_languages.length)];
  // About one tag in three carries a script subtag (`zh-Hant-CA`), so the
  // region is not simply "everything after the language".
  final script = r.nextInt(3) == 0 ? _scripts[r.nextInt(_scripts.length)] : '';
  if (r.nextBool()) {
    final region = _regions[r.nextInt(_regions.length)];
    final separator = r.nextBool() ? '-' : '_';
    final casedRegion = r.nextBool() ? region : region.toLowerCase();
    final casedLanguage = r.nextBool()
        ? language
        : '${language[0].toUpperCase()}$language';
    final scriptPart = script.isEmpty ? '' : '$separator$script';
    return '$casedLanguage$scriptPart$separator$casedRegion';
  }
  return script.isEmpty ? language : '$language-$script';
}

class _Case {
  _Case({
    required this.supported,
    required this.device,
    required this.active,
  });

  final List<String> supported;
  final List<String> device;
  final String? active;
}

_Case _generateCase(Random r) {
  final count = r.nextInt(6);
  final supported = <String>{};
  while (supported.length < count) {
    supported.add(_generateTag(r));
  }
  final deviceCount = r.nextInt(4);
  final device = List.generate(deviceCount, (_) => _generateTag(r));
  final activeRoll = r.nextInt(3);
  final String? active;
  if (activeRoll == 0 || supported.isEmpty) {
    active = null;
  } else if (activeRoll == 1) {
    active = supported.elementAt(r.nextInt(supported.length));
  } else {
    active = _generateTag(r);
  }
  return _Case(
    supported: supported.toList(),
    device: device,
    active: active,
  );
}

// --- The independent oracle (Amendment 03 section 6, written from the rule,
// not from the provider).

String _norm(String id) => id.toLowerCase().replaceAll('_', '-');

String? _language(String id) {
  final normalised = _norm(id);
  final index = normalised.indexOf('-');
  final language = index == -1 ? normalised : normalised.substring(0, index);
  return language.isEmpty ? null : language;
}

/// The region subtag: the one after the language, skipping a four-letter
/// script subtag (`zh-Hant-CA` has region `ca`); `null` when there is none.
String? _region(String id) {
  final parts = _norm(id).split('-');
  var index = 1;
  if (index < parts.length && RegExp(r'^[a-z]{4}$').hasMatch(parts[index])) {
    index++;
  }
  return index < parts.length && parts[index].isNotEmpty ? parts[index] : null;
}

String? _exact(List<String> supported, String wanted) {
  for (final id in supported) {
    if (_norm(id) == _norm(wanted)) return id;
  }
  return null;
}

String? _languageOnly(List<String> supported, String wanted) {
  final language = _language(wanted);
  if (language == null) return null;
  String? usMatch;
  String? firstMatch;
  for (final id in supported) {
    if (_language(id) != language) continue;
    if (_region(id) == 'ca') return id;
    if (_region(id) == 'us') usMatch ??= id;
    firstMatch ??= id;
  }
  return usMatch ?? firstMatch;
}

String _oracle({
  required List<String> supported,
  required List<String> device,
  required String? active,
}) {
  if (active != null) {
    return _exact(supported, active) ??
        _languageOnly(supported, active) ??
        active;
  }
  if (supported.isEmpty) {
    return device.isNotEmpty ? device.first : 'en-CA';
  }
  for (final tag in device) {
    final match = _exact(supported, tag) ?? _languageOnly(supported, tag);
    if (match != null) return match;
  }
  return _exact(supported, 'en-CA') ??
      _languageOnly(supported, 'en-CA') ??
      'en-CA';
}

bool _matchesAny(List<String> supported, String wanted) =>
    _exact(supported, wanted) != null ||
    _languageOnly(supported, wanted) != null;

/// Resolves with no explicit choice, for the example pins below.
Future<String> _resolve({
  required List<String> supported,
  required List<String> device,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      deviceLocalesProvider.overrideWithValue(device),
      localeInfoProvider.overrideWith(
        (_) async => [
          for (final id in supported)
            SpeechLocale(localeId: id, displayName: id),
        ],
      ),
    ],
  );
  addTearDown(container.dispose);
  await container.read(localeInfoProvider.future);
  return container.read(resolvedLocaleIdProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the region is the subtag after the language, skipping a script', () {
    test('zh-Hant-CA wins the CA tie-break over zh-Hant-TW', () async {
      expect(
        await _resolve(
          supported: ['zh-Hant-TW', 'zh-Hant-CA', 'zh-Hans-CN'],
          device: ['zh-HK'],
        ),
        'zh-Hant-CA',
      );
    });

    test('zh-Hans-US wins the US tie-break when there is no CA', () async {
      expect(
        await _resolve(
          supported: ['zh-Hant-TW', 'zh-Hans-US'],
          device: ['zh'],
        ),
        'zh-Hans-US',
      );
    });

    test(
      'a script with no region has no region: a CA one still wins',
      () async {
        expect(
          await _resolve(
            supported: ['zh-Hant', 'zh-Hans-CA'],
            device: ['zh'],
          ),
          'zh-Hans-CA',
        );
      },
    );

    test(
      'a script with no region and no CA or US falls to the first listed',
      () async {
        expect(
          await _resolve(
            supported: ['zh-Hant', 'zh-Hans'],
            device: ['zh'],
          ),
          'zh-Hant',
        );
      },
    );

    test('case and the underscore separator are still ignored', () async {
      expect(
        await _resolve(
          supported: ['zh_hant_tw', 'ZH_Hant_ca'],
          device: ['zh'],
        ),
        'ZH_Hant_ca',
      );
    });
  });

  const pbt.Glados<_Case>(_generateCase).test(
    'TP-25: for any generated supported and device lists, resolvedLocaleId '
    'equals the section-6 resolution and never matches none of them unless '
    'the list is empty or nothing matches',
    (testCase) async {
      final active = testCase.active;
      SharedPreferences.setMockInitialValues(
        active == null ? <String, Object>{} : {'stt.activeLocaleId': active},
      );
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          deviceLocalesProvider.overrideWithValue(testCase.device),
          localeInfoProvider.overrideWith(
            (_) async => [
              for (final id in testCase.supported)
                SpeechLocale(localeId: id, displayName: id),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(localeInfoProvider.future);

      final resolved = container.read(resolvedLocaleIdProvider);
      expect(
        resolved,
        _oracle(
          supported: testCase.supported,
          device: testCase.device,
          active: testCase.active,
        ),
        reason:
            'supported=${testCase.supported} device=${testCase.device} '
            'active=${testCase.active}',
      );

      if (testCase.active == null && testCase.supported.isNotEmpty) {
        final unmatched = !testCase.supported.any(
          (s) => _norm(s) == _norm(resolved),
        );
        if (unmatched) {
          // Nothing matched: the answer is exactly the en-CA pass-through,
          // and it may only be that when truly nothing could have matched.
          expect(
            resolved,
            'en-CA',
            reason:
                'arbitrary first-locale drift: '
                'resolved=$resolved supported=${testCase.supported}',
          );
          for (final tag in testCase.device) {
            expect(
              _matchesAny(testCase.supported, tag),
              isFalse,
              reason: 'missed a device match for $tag',
            );
          }
          expect(
            _matchesAny(testCase.supported, 'en-CA'),
            isFalse,
            reason: 'missed an en-CA match',
          );
        }
      }
    },
  );
}
