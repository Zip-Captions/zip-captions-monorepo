import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zip_core/zip_core.dart';

/// Zip Broadcast app-specific settings notifier.
///
/// Uses key prefix `zip_broadcast` to isolate settings
/// in SharedPreferences from other apps in the monorepo.
class DisplaySettingsNotifier extends BaseSettingsNotifier {
  @override
  String get keyPrefix => 'zip_broadcast';
}

/// Provider for Zip Broadcast display settings.
final displaySettingsProvider =
    NotifierProvider<DisplaySettingsNotifier, DisplaySettings>(
  DisplaySettingsNotifier.new,
);
