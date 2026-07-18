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
  String get appearanceTextSizeLabelXs => 'XS';

  @override
  String get appearanceTextSizeLabelSm => 'SM';

  @override
  String get appearanceTextSizeLabelMd => 'MD';

  @override
  String get appearanceTextSizeLabelLg => 'LG';

  @override
  String get appearanceTextSizeLabelXl => 'XL';

  @override
  String get appearanceTextSizeLabelXxl => 'XXL';

  @override
  String get appearanceFont => 'Font';

  @override
  String get appearanceScrollDirection => 'Scroll direction';

  @override
  String get appearanceNewAtBottom => '↑ New at bottom';

  @override
  String get appearanceNewAtTop => '↓ New at top';

  @override
  String get appearanceDarkTheme => 'Dark Theme';

  @override
  String get obsStatusConnected => 'Connected';

  @override
  String get obsStatusConnecting => 'Connecting…';

  @override
  String get obsStatusReconnecting => 'Reconnecting…';

  @override
  String get obsStatusError => 'Error';

  @override
  String get obsStatusDisconnected => 'Disconnected';

  @override
  String get obsNotConfigured => 'Test connection in Settings first';

  @override
  String get obsConnectionError =>
      'Could not connect to OBS. Check your settings and try again.';

  @override
  String get obsStatusDisabled => 'Disabled';

  @override
  String get homeStartBroadcast => 'Start Broadcast';

  @override
  String get homeOutputTargets => 'Output targets';

  @override
  String get homeNoAudioInputs => 'No audio inputs configured.';

  @override
  String get homeAudioInputs => 'Audio inputs';

  @override
  String get homeManage => 'Manage';

  @override
  String homeStatusSummary(int inputCount, int targetCount) {
    String _temp0 = intl.Intl.pluralLogic(
      inputCount,
      locale: localeName,
      other: '$inputCount inputs',
      one: '1 input',
    );
    String _temp1 = intl.Intl.pluralLogic(
      targetCount,
      locale: localeName,
      other: '$targetCount targets',
      one: '1 target',
    );
    return 'Ready · $_temp0 · $_temp1 active';
  }

  @override
  String get recordingPaused => 'Paused';

  @override
  String get recordingResume => 'Resume';

  @override
  String get recordingAppearance => 'Appearance';

  @override
  String recordingStartError(String error) {
    return 'Could not start broadcast: $error';
  }

  @override
  String get settingsAppearance => 'Appearance';

  @override
  String get settingsAppearanceSubtitle => 'Text size, font, scroll direction';

  @override
  String get settingsObs => 'OBS WebSocket';

  @override
  String get settingsOutputTargets => 'Output Targets';

  @override
  String get settingsAudioInputs => 'Audio Inputs';

  @override
  String get settingsTranscripts => 'Transcripts & Behaviour';

  @override
  String get settingsObsHost => 'Host';

  @override
  String get settingsObsPort => 'Port';

  @override
  String get settingsObsPassword => 'Password';

  @override
  String get settingsObsTestConnection => 'Test Connection';

  @override
  String get settingsObsConnectedSuccess => 'Connected successfully';

  @override
  String settingsObsConnectionFailed(String status) {
    return 'Connection failed ($status)';
  }

  @override
  String settingsObsStatus(String status) {
    return 'Status: $status';
  }

  @override
  String get settingsOnScreenCaptions => 'On-Screen Captions';

  @override
  String get settingsBrowserSource => 'Browser Source';

  @override
  String get settingsCaptionOverlay => 'Caption Overlay';

  @override
  String get settingsTranscriptsTarget => 'Transcripts';

  @override
  String get settingsManageAudioInputs => 'Manage Audio Inputs';

  @override
  String get settingsSaveTranscripts => 'Save Transcripts';

  @override
  String get settingsKeepScreenOn => 'Keep Screen On';

  @override
  String get settingsReleaseOnPause => 'Release on Pause';

  @override
  String get appTitleDefault => 'Zip Broadcast';

  @override
  String get appTitleBroadcast => 'Broadcast';

  @override
  String get appTitleSettings => 'Settings';

  @override
  String get appTitleHistory => 'History';

  @override
  String get appTitleAudioInputs => 'Audio Inputs';

  @override
  String browserSourceFailedToStart(String reason) {
    return 'Browser source failed to start: $reason';
  }

  @override
  String get audioSourceNoInputs => 'No audio inputs configured.';

  @override
  String get audioSourceAddInput => 'Add Audio Input';

  @override
  String get audioSourceLabel => 'Label';

  @override
  String get audioSourceLabelHint => 'e.g. Presenter';

  @override
  String get audioSourceColour => 'Colour';

  @override
  String audioSourceColourOption(int index) {
    return 'Colour $index';
  }

  @override
  String audioSourceInputPosition(int position) {
    return 'Input $position';
  }

  @override
  String get audioSourceRemoveTooltip => 'Remove';

  @override
  String get audioSourceNewInputName => 'New Input';

  @override
  String get statusPillObs => 'OBS';

  @override
  String get statusPillBrowserSource => 'Browser Source';

  @override
  String get statusPillOverlay => 'Overlay';

  @override
  String get recordingControlsPause => 'Pause';

  @override
  String get recordingControlsResume => 'Resume';

  @override
  String get recordingControlsStop => 'Stop';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get outputTargetsRemoteViewers => 'Remote Viewers';

  @override
  String get outputTargetsPhase2 => 'Phase 2';
}
