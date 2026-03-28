import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_core/zip_core.dart';

/// Zip Captions app-specific settings notifier.
///
/// Uses key prefix `zip_captions` to isolate settings
/// in SharedPreferences from other apps in the monorepo.
class ZipCaptionsSettingsNotifier extends BaseSettingsNotifier {
  @override
  String get keyPrefix => 'zip_captions';
}

/// Provider for Zip Captions app settings.
final zipCaptionsSettingsProvider =
    NotifierProvider<ZipCaptionsSettingsNotifier, AppSettings>(
  ZipCaptionsSettingsNotifier.new,
);
