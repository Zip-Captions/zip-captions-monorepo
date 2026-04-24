// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'zip_broadcast_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class ZipBroadcastLocalizationsEn extends ZipBroadcastLocalizations {
  ZipBroadcastLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Zip Broadcast';

  @override
  String get homePlaceholder => 'Tap Start to begin captioning';

  @override
  String get appearanceTitle => 'Appearance';

  @override
  String get appearanceTextSize => 'Text size';

  @override
  String get appearanceFont => 'Font';

  @override
  String get appearanceScrollDirection => 'Scroll direction';

  @override
  String get appearanceNewAtBottom => '↑ New at bottom';

  @override
  String get appearanceNewAtTop => '↓ New at top';

  @override
  String get audioSourceNoInputs => 'No audio inputs configured.';

  @override
  String get audioSourceAddInput => 'Add Audio Input';

  @override
  String get audioSourceSpeakerLabel => 'Speaker label';

  @override
  String get audioSourceSpeakerLabelHint => 'e.g. Teacher';

  @override
  String get audioSourceColour => 'Colour';

  @override
  String audioSourceInputPosition(int position) {
    return 'Input $position';
  }

  @override
  String get audioSourceRemoveTooltip => 'Remove';

  @override
  String get audioSourceNewInputName => 'New Input';
}
