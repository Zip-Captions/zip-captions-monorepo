import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_core/zip_core.dart';

part 'language_pack_providers.g.dart';

/// The language-pack service (Amendment 04).
///
/// Wired to `MethodChannelLanguagePackService` in `runZipCaptions`; a test
/// overrides it with a fake. Reading it unwired is a programming error, which
/// the panel treats as an `unknown` status rather than a crash.
@Riverpod(keepAlive: true)
LanguagePackService languagePackService(Ref ref) => throw UnimplementedError(
      'languagePackServiceProvider must be overridden',
    );

/// The OS version the panel decides on (TP-28): the iOS major version, or
/// null when unreadable. Android's SDK level is never needed: the panel's
/// Android answer does not depend on it, so it reads null there.
///
/// An injectable value, so a test can pin any version without a platform.
@Riverpod(keepAlive: true)
int? languagePackOsVersion(Ref ref) => iosMajorVersion(
      isWeb: kIsWeb,
      platform: defaultTargetPlatform,
      operatingSystemVersion: kIsWeb ? '' : Platform.operatingSystemVersion,
    );

/// Parses the iOS major version from `Platform.operatingSystemVersion`
/// ("Version 26.0 (Build 23A344)"), or null off iOS or when it does not
/// parse.
@visibleForTesting
int? iosMajorVersion({
  required bool isWeb,
  required TargetPlatform platform,
  required String operatingSystemVersion,
}) {
  if (isWeb || platform != TargetPlatform.iOS) return null;
  final match = RegExp(r'(\d+)').firstMatch(operatingSystemVersion);
  return match == null ? null : int.tryParse(match.group(1)!);
}
