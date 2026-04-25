import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'zip_broadcast_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of ZipBroadcastLocalizations
/// returned by `ZipBroadcastLocalizations.of(context)`.
///
/// Applications need to include `ZipBroadcastLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/zip_broadcast_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: ZipBroadcastLocalizations.localizationsDelegates,
///   supportedLocales: ZipBroadcastLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the ZipBroadcastLocalizations.supportedLocales
/// property.
abstract class ZipBroadcastLocalizations {
  ZipBroadcastLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static ZipBroadcastLocalizations? of(BuildContext context) {
    return Localizations.of<ZipBroadcastLocalizations>(
      context,
      ZipBroadcastLocalizations,
    );
  }

  static const LocalizationsDelegate<ZipBroadcastLocalizations> delegate =
      _ZipBroadcastLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en')];

  /// The app name displayed in the app bar
  ///
  /// In en, this message translates to:
  /// **'Zip Broadcast'**
  String get appName;

  /// Placeholder text on the home screen before captioning starts
  ///
  /// In en, this message translates to:
  /// **'Tap Start to begin captioning'**
  String get homePlaceholder;

  /// Title of the Appearance settings panel
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceTitle;

  /// Label for the text-size setting section
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get appearanceTextSize;

  /// Label for the extra-small caption text size chip
  ///
  /// In en, this message translates to:
  /// **'XS'**
  String get appearanceTextSizeLabelXs;

  /// Label for the small caption text size chip
  ///
  /// In en, this message translates to:
  /// **'SM'**
  String get appearanceTextSizeLabelSm;

  /// Label for the medium caption text size chip
  ///
  /// In en, this message translates to:
  /// **'MD'**
  String get appearanceTextSizeLabelMd;

  /// Label for the large caption text size chip
  ///
  /// In en, this message translates to:
  /// **'LG'**
  String get appearanceTextSizeLabelLg;

  /// Label for the extra-large caption text size chip
  ///
  /// In en, this message translates to:
  /// **'XL'**
  String get appearanceTextSizeLabelXl;

  /// Label for the double-extra-large caption text size chip
  ///
  /// In en, this message translates to:
  /// **'XXL'**
  String get appearanceTextSizeLabelXxl;

  /// Label for the font setting section
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get appearanceFont;

  /// Label for the scroll-direction setting section
  ///
  /// In en, this message translates to:
  /// **'Scroll direction'**
  String get appearanceScrollDirection;

  /// Scroll direction chip: newest captions appear at the bottom
  ///
  /// In en, this message translates to:
  /// **'↑ New at bottom'**
  String get appearanceNewAtBottom;

  /// Scroll direction chip: newest captions appear at the top
  ///
  /// In en, this message translates to:
  /// **'↓ New at top'**
  String get appearanceNewAtTop;

  /// Label for the dark theme toggle
  ///
  /// In en, this message translates to:
  /// **'Dark Theme'**
  String get appearanceDarkTheme;

  /// OBS connection status: connected
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get obsStatusConnected;

  /// OBS connection status: connecting
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get obsStatusConnecting;

  /// OBS connection status: reconnecting
  ///
  /// In en, this message translates to:
  /// **'Reconnecting…'**
  String get obsStatusReconnecting;

  /// OBS connection status: error
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get obsStatusError;

  /// OBS connection status: disconnected
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get obsStatusDisconnected;

  /// OBS connection status shown when OBS target is disabled
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get obsStatusDisabled;

  /// Label on the Start Broadcast button
  ///
  /// In en, this message translates to:
  /// **'Start Broadcast'**
  String get homeStartBroadcast;

  /// Section heading for output targets list on home screen
  ///
  /// In en, this message translates to:
  /// **'Output targets'**
  String get homeOutputTargets;

  /// Empty-state text when no audio inputs are configured
  ///
  /// In en, this message translates to:
  /// **'No audio inputs configured.'**
  String get homeNoAudioInputs;

  /// Section heading for audio inputs list on home screen
  ///
  /// In en, this message translates to:
  /// **'Audio inputs'**
  String get homeAudioInputs;

  /// Button label to navigate to audio input management
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get homeManage;

  /// Status pill text on the home screen showing input and target counts
  ///
  /// In en, this message translates to:
  /// **'Ready · {inputCount} {inputLabel} · {targetCount} {targetLabel} active'**
  String homeStatusSummary(
    int inputCount,
    String inputLabel,
    int targetCount,
    String targetLabel,
  );

  /// Singular form of 'input' used in home status summary
  ///
  /// In en, this message translates to:
  /// **'input'**
  String get homeInputSingular;

  /// Plural form of 'input' used in home status summary
  ///
  /// In en, this message translates to:
  /// **'inputs'**
  String get homeInputPlural;

  /// Singular form of 'target' used in home status summary
  ///
  /// In en, this message translates to:
  /// **'target'**
  String get homeTargetSingular;

  /// Plural form of 'target' used in home status summary
  ///
  /// In en, this message translates to:
  /// **'targets'**
  String get homeTargetPlural;

  /// Label shown when the broadcast session is paused
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get recordingPaused;

  /// Tooltip on the Resume floating action button
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recordingResume;

  /// Tooltip on the Appearance floating action button
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get recordingAppearance;

  /// Snackbar message when a broadcast fails to start
  ///
  /// In en, this message translates to:
  /// **'Could not start broadcast: {error}'**
  String recordingStartError(Object error);

  /// Settings list tile title for Appearance detail
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get settingsAppearance;

  /// Settings list tile subtitle for Appearance detail
  ///
  /// In en, this message translates to:
  /// **'Text size, font, scroll direction'**
  String get settingsAppearanceSubtitle;

  /// Settings list tile and detail title for OBS WebSocket
  ///
  /// In en, this message translates to:
  /// **'OBS WebSocket'**
  String get settingsObs;

  /// Settings list tile and detail title for Output Targets
  ///
  /// In en, this message translates to:
  /// **'Output Targets'**
  String get settingsOutputTargets;

  /// Settings list tile and detail title for Audio Inputs
  ///
  /// In en, this message translates to:
  /// **'Audio Inputs'**
  String get settingsAudioInputs;

  /// Settings list tile and detail title for Transcripts & Behaviour
  ///
  /// In en, this message translates to:
  /// **'Transcripts & Behaviour'**
  String get settingsTranscripts;

  /// Label for the OBS host text field
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get settingsObsHost;

  /// Label for the OBS port text field
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get settingsObsPort;

  /// Label for the OBS password text field
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get settingsObsPassword;

  /// Label on the OBS Test Connection button
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get settingsObsTestConnection;

  /// Snackbar message when OBS test connection succeeds
  ///
  /// In en, this message translates to:
  /// **'Connected successfully'**
  String get settingsObsConnectedSuccess;

  /// Snackbar message when OBS test connection fails
  ///
  /// In en, this message translates to:
  /// **'Connection failed ({status})'**
  String settingsObsConnectionFailed(String status);

  /// OBS connection status label shown below test connection button
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String settingsObsStatus(String status);

  /// Label for the On-Screen Captions output target toggle
  ///
  /// In en, this message translates to:
  /// **'On-Screen Captions'**
  String get settingsOnScreenCaptions;

  /// Label for the Browser Source output target toggle
  ///
  /// In en, this message translates to:
  /// **'Browser Source'**
  String get settingsBrowserSource;

  /// Label for the Caption Overlay output target toggle
  ///
  /// In en, this message translates to:
  /// **'Caption Overlay'**
  String get settingsCaptionOverlay;

  /// Label for the Transcripts output target (always active)
  ///
  /// In en, this message translates to:
  /// **'Transcripts'**
  String get settingsTranscriptsTarget;

  /// List tile to navigate to audio input management
  ///
  /// In en, this message translates to:
  /// **'Manage Audio Inputs'**
  String get settingsManageAudioInputs;

  /// Label for the Save Transcripts toggle
  ///
  /// In en, this message translates to:
  /// **'Save Transcripts'**
  String get settingsSaveTranscripts;

  /// Label for the Keep Screen On wake-lock toggle
  ///
  /// In en, this message translates to:
  /// **'Keep Screen On'**
  String get settingsKeepScreenOn;

  /// Label for the Release on Pause wake-lock toggle
  ///
  /// In en, this message translates to:
  /// **'Release on Pause'**
  String get settingsReleaseOnPause;

  /// App bar title on the home screen and as fallback
  ///
  /// In en, this message translates to:
  /// **'Zip Broadcast'**
  String get appTitleDefault;

  /// App bar title on the recording screen
  ///
  /// In en, this message translates to:
  /// **'Broadcast'**
  String get appTitleBroadcast;

  /// App bar title on the settings screen
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get appTitleSettings;

  /// App bar title on the history screen
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get appTitleHistory;

  /// App bar title on the audio inputs screen
  ///
  /// In en, this message translates to:
  /// **'Audio Inputs'**
  String get appTitleAudioInputs;

  /// Snackbar message when the browser source server fails to bind
  ///
  /// In en, this message translates to:
  /// **'Browser source failed to start: {reason}'**
  String browserSourceFailedToStart(String reason);

  /// Empty-state message on the audio source config screen
  ///
  /// In en, this message translates to:
  /// **'No audio inputs configured.'**
  String get audioSourceNoInputs;

  /// Button label to add a new audio input
  ///
  /// In en, this message translates to:
  /// **'Add Audio Input'**
  String get audioSourceAddInput;

  /// TextField label for the speaker name
  ///
  /// In en, this message translates to:
  /// **'Speaker label'**
  String get audioSourceSpeakerLabel;

  /// Hint text for the speaker label field
  ///
  /// In en, this message translates to:
  /// **'e.g. Teacher'**
  String get audioSourceSpeakerLabelHint;

  /// Label above the colour swatch row
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get audioSourceColour;

  /// Semantic label for a colour swatch button, e.g. 'Colour 1'
  ///
  /// In en, this message translates to:
  /// **'Colour {index}'**
  String audioSourceColourOption(int index);

  /// Card title showing the input's position in the list
  ///
  /// In en, this message translates to:
  /// **'Input {position}'**
  String audioSourceInputPosition(int position);

  /// Tooltip on the remove-input icon button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get audioSourceRemoveTooltip;

  /// Default name given to a newly added audio input
  ///
  /// In en, this message translates to:
  /// **'New Input'**
  String get audioSourceNewInputName;

  /// Label on the OBS status pill in the recording screen status bar
  ///
  /// In en, this message translates to:
  /// **'OBS'**
  String get statusPillObs;

  /// Label on the Browser Source status pill in the recording screen status bar
  ///
  /// In en, this message translates to:
  /// **'Browser Source'**
  String get statusPillBrowserSource;

  /// Label on the Caption Overlay status pill in the recording screen status bar
  ///
  /// In en, this message translates to:
  /// **'Overlay'**
  String get statusPillOverlay;

  /// Tooltip on the Pause button in the recording controls bar
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recordingControlsPause;

  /// Tooltip on the Resume button in the recording controls bar
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recordingControlsResume;

  /// Tooltip on the Stop button in the recording controls bar
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get recordingControlsStop;

  /// Badge label on coming-soon output target cards
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;
}

class _ZipBroadcastLocalizationsDelegate
    extends LocalizationsDelegate<ZipBroadcastLocalizations> {
  const _ZipBroadcastLocalizationsDelegate();

  @override
  Future<ZipBroadcastLocalizations> load(Locale locale) {
    return SynchronousFuture<ZipBroadcastLocalizations>(
      lookupZipBroadcastLocalizations(locale),
    );
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en'].contains(locale.languageCode);

  @override
  bool shouldReload(_ZipBroadcastLocalizationsDelegate old) => false;
}

ZipBroadcastLocalizations lookupZipBroadcastLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return ZipBroadcastLocalizationsEn();
  }

  throw FlutterError(
    'ZipBroadcastLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
