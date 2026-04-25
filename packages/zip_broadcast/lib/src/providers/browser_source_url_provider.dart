import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:zip_broadcast/src/providers/broadcast_providers.dart';

part 'browser_source_url_provider.g.dart';

/// Derives the browser source URL from the output target settings browser
/// source port.
///
/// Returns an empty string when browser source is disabled.
@riverpod
String browserSourceUrl(Ref ref) {
  final settings = ref.watch(outputTargetSettingsNotifierProvider);
  if (!settings.browserSourceEnabled) return '';
  return 'http://localhost:${settings.browserSourcePort}/captions';
}
