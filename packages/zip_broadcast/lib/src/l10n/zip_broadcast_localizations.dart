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

  /// Subtitle on disabled OBS toggle when connection has not been verified
  ///
  /// In en, this message translates to:
  /// **'Test connection in Settings first'**
  String get obsNotConfigured;

  /// Inline error shown below the OBS toggle on the home screen when a connection attempt fails
  ///
  /// In en, this message translates to:
  /// **'Could not connect to OBS. Check your settings and try again.'**
  String get obsConnectionError;

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

  /// Status pill text on the home screen; uses ICU plural for correct singular/plural forms across languages
  ///
  /// In en, this message translates to:
  /// **'Ready · {inputCount, plural, =1{1 input} other{{inputCount} inputs}} · {targetCount, plural, =1{1 target} other{{targetCount} targets}} active'**
  String homeStatusSummary(int inputCount, int targetCount);

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
  String recordingStartError(String error);

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

  /// TextField label for the input's display label
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get audioSourceLabel;

  /// Hint text for the input label field
  ///
  /// In en, this message translates to:
  /// **'e.g. Presenter'**
  String get audioSourceLabelHint;

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

  /// Label for the Remote Viewers coming-soon output target card
  ///
  /// In en, this message translates to:
  /// **'Remote Viewers'**
  String get outputTargetsRemoteViewers;

  /// Subtitle for the Remote Viewers card indicating it is planned for Phase 2
  ///
  /// In en, this message translates to:
  /// **'Phase 2'**
  String get outputTargetsPhase2;

  /// Title on the sign-in card (signed-out and auth-failure states)
  ///
  /// In en, this message translates to:
  /// **'Sign in to broadcast'**
  String get signInTitle;

  /// Explanatory copy on the sign-in card (signed-out and auth-failure states)
  ///
  /// In en, this message translates to:
  /// **'Signing in is only needed to broadcast to remote viewers over the internet. Local captioning, on-screen display and your other output targets all work fully signed out.'**
  String get signInCopy;

  /// Provider sign-in button label
  ///
  /// In en, this message translates to:
  /// **'Continue with {providerLabel}'**
  String signInContinueWith(String providerLabel);

  /// Title on the signed-in account card
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get signInAccountTitle;

  /// Status line on the signed-in account card
  ///
  /// In en, this message translates to:
  /// **'Signed in · ready to broadcast remotely'**
  String get signInAccountStatus;

  /// Explanatory copy on the signed-in account card
  ///
  /// In en, this message translates to:
  /// **'You\'re signed in for remote broadcasting. Local captioning and your other output targets don\'t require this account.'**
  String get signInAccountCopy;

  /// Sign-out button label
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signInSignOut;

  /// Generic auth-failure alert message, shown for every failure reason
  ///
  /// In en, this message translates to:
  /// **'Sign-in didn\'t complete. The provider didn\'t confirm your identity — check your connection and try again.'**
  String get signInFailureAlert;

  /// Retry button label on the auth-failure card
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get signInRetry;

  /// Settings list entry title for the account/sign-in section
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsAccount;

  /// Settings list entry subtitle for the account/sign-in section
  ///
  /// In en, this message translates to:
  /// **'Sign in for remote broadcasting'**
  String get settingsAccountSubtitle;

  /// App bar title for the Broadcast UI route (Unit 6, S-17)
  ///
  /// In en, this message translates to:
  /// **'Go Live'**
  String get appTitleGoLive;

  /// Title of the signed-out overlay on the broadcast setup form
  ///
  /// In en, this message translates to:
  /// **'Sign in to broadcast'**
  String get broadcastSignedOutTitle;

  /// Body copy of the signed-out overlay on the broadcast setup form
  ///
  /// In en, this message translates to:
  /// **'Sign in to broadcast to remote viewers over the internet, or go back to use your local output targets only.'**
  String get broadcastSignedOutCopy;

  /// Label for the session name text field
  ///
  /// In en, this message translates to:
  /// **'Session name'**
  String get broadcastSessionNameLabel;

  /// Validation error when the session name is empty (business-rules.md Rule 7)
  ///
  /// In en, this message translates to:
  /// **'Session name is required'**
  String get broadcastSessionNameErrorEmpty;

  /// Validation error when the session name exceeds the max length (business-rules.md Rule 7)
  ///
  /// In en, this message translates to:
  /// **'Session name is too long'**
  String get broadcastSessionNameErrorTooLong;

  /// Validation error when the session name contains a control character (business-rules.md Rule 7)
  ///
  /// In en, this message translates to:
  /// **'Session name contains an invalid character'**
  String get broadcastSessionNameErrorControlChar;

  /// Toggle label for BroadcastSettings.autoStartCaptioning
  ///
  /// In en, this message translates to:
  /// **'Start captioning automatically when I go live'**
  String get broadcastAutoStartCaptioning;

  /// Label above the stable broadcast URL row
  ///
  /// In en, this message translates to:
  /// **'Your broadcast link'**
  String get broadcastUrlLabel;

  /// Button label to copy the broadcast URL to the clipboard
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get broadcastUrlCopyAction;

  /// Confirmation snackbar shown after copying the broadcast URL
  ///
  /// In en, this message translates to:
  /// **'Link copied to clipboard'**
  String get broadcastUrlCopied;

  /// Label on the Go Live button
  ///
  /// In en, this message translates to:
  /// **'Go Live'**
  String get broadcastGoLiveAction;

  /// Progress label on the Go Live button while StartingState is in effect
  ///
  /// In en, this message translates to:
  /// **'Going live…'**
  String get broadcastGoingLive;

  /// Title of the failure card shown for BroadcastFailedState
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t go live'**
  String get broadcastFailedTitle;

  /// Failure message for BroadcastFailure.signedOut
  ///
  /// In en, this message translates to:
  /// **'You\'ve been signed out. Sign in again and try once more.'**
  String get broadcastFailureSignedOut;

  /// Failure message for BroadcastFailure.signalingUnavailable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t publish your broadcast\'s live status. Check your connection and try again.'**
  String get broadcastFailureSignalingUnavailable;

  /// Failure message for BroadcastFailure.relayUnavailable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set up a connection relay. Check your connection and try again.'**
  String get broadcastFailureRelayUnavailable;

  /// Failure message for BroadcastFailure.identityUnavailable
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t look up your broadcast identity. Try again in a moment.'**
  String get broadcastFailureIdentityUnavailable;

  /// Failure message for BroadcastFailure.unknown
  ///
  /// In en, this message translates to:
  /// **'Something went wrong starting your broadcast. Try again.'**
  String get broadcastFailureUnknown;

  /// Retry button label on the broadcast failure card
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get broadcastRetryAction;

  /// Heading on the live broadcast dashboard
  ///
  /// In en, this message translates to:
  /// **'You\'re live'**
  String get broadcastDashboardTitle;

  /// Viewer count vs. capacity on the live dashboard
  ///
  /// In en, this message translates to:
  /// **'{count} of {max} viewers'**
  String broadcastViewerCount(int count, int max);

  /// Label for the broadcast duration stat card
  ///
  /// In en, this message translates to:
  /// **'Duration'**
  String get broadcastDurationLabel;

  /// Banner shown when captioning has never been active during this broadcast (F-6.4)
  ///
  /// In en, this message translates to:
  /// **'Captioning hasn\'t started yet — viewers are connected but won\'t see any captions until you start captioning.'**
  String get broadcastCaptionsNeverStarted;

  /// Banner shown when captioning was active before but isn't currently (F-6.4)
  ///
  /// In en, this message translates to:
  /// **'Captions are not running — viewers are connected but won\'t see any captions until you start captioning.'**
  String get broadcastCaptionsNotRunning;

  /// Banner shown when viewers.length == maxViewers (F-6.5)
  ///
  /// In en, this message translates to:
  /// **'This broadcast is at its {cap}-viewer cap — new viewers can\'t join until someone disconnects.'**
  String broadcastFullBanner(int cap);

  /// Empty-state text for the live caption preview on the dashboard
  ///
  /// In en, this message translates to:
  /// **'No captions yet — start captioning to show live captions here.'**
  String get broadcastCaptionPreviewEmpty;

  /// Button label to start captioning from the dashboard
  ///
  /// In en, this message translates to:
  /// **'Start Captioning'**
  String get broadcastStartCaptioningAction;

  /// Button label to pause captioning from the dashboard
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get broadcastPauseCaptioningAction;

  /// Button label to resume captioning from the dashboard
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get broadcastResumeCaptioningAction;

  /// Button label to end the live broadcast
  ///
  /// In en, this message translates to:
  /// **'End Broadcast'**
  String get broadcastEndAction;

  /// Snackbar shown when sign-out is refused while the broadcast session is non-idle (business-rules.md Rule 9)
  ///
  /// In en, this message translates to:
  /// **'End the live broadcast before signing out'**
  String get broadcastSignOutRefused;

  /// Section heading above the connected-viewer list on the live dashboard
  ///
  /// In en, this message translates to:
  /// **'Viewers'**
  String get broadcastViewers;

  /// Per-input audio row status when the engine is actively listening
  ///
  /// In en, this message translates to:
  /// **'active'**
  String get broadcastAudioInputStatusActive;

  /// Per-input audio row status when the engine failed
  ///
  /// In en, this message translates to:
  /// **'error'**
  String get broadcastAudioInputStatusError;

  /// Per-input audio row status when the engine isn't running
  ///
  /// In en, this message translates to:
  /// **'inactive'**
  String get broadcastAudioInputStatusInactive;

  /// Section label for the external display output controls
  ///
  /// In en, this message translates to:
  /// **'External Display'**
  String get externalDisplay;

  /// Heading above the list of connected displays
  ///
  /// In en, this message translates to:
  /// **'Available Displays'**
  String get externalDisplayAvailableDisplays;

  /// Shown when no external display is connected
  ///
  /// In en, this message translates to:
  /// **'No displays detected'**
  String get externalDisplayNoDisplays;

  /// Fallback name for a display that reports no label; {number} is its 1-based position
  ///
  /// In en, this message translates to:
  /// **'Display {number}'**
  String externalDisplayDisplayFallback(int number);

  /// Meta marker on the display the system considers primary
  ///
  /// In en, this message translates to:
  /// **'primary'**
  String get externalDisplayPrimaryMarker;

  /// Meta marker on the display captions are sent to
  ///
  /// In en, this message translates to:
  /// **'selected'**
  String get externalDisplaySelectedMarker;

  /// Meta marker on the display currently captioned
  ///
  /// In en, this message translates to:
  /// **'connected'**
  String get externalDisplayConnectedMarker;

  /// Meta marker on a display that went away while in use
  ///
  /// In en, this message translates to:
  /// **'disconnected'**
  String get externalDisplayDisconnectedMarker;

  /// Pill on the display row that is currently receiving captions
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get externalDisplayActivePill;

  /// Affordance on the row whose window is being created
  ///
  /// In en, this message translates to:
  /// **'opening'**
  String get externalDisplayOpening;

  /// Label above the Top/Bottom caption position selector
  ///
  /// In en, this message translates to:
  /// **'Caption Position'**
  String get externalDisplayCaptionPosition;

  /// Caption position: top of the display
  ///
  /// In en, this message translates to:
  /// **'Top'**
  String get externalDisplayPositionTop;

  /// Caption position: bottom of the display
  ///
  /// In en, this message translates to:
  /// **'Bottom'**
  String get externalDisplayPositionBottom;

  /// Banner shown when the selected display went away; {display} is its label
  ///
  /// In en, this message translates to:
  /// **'The {display} was disconnected. Captioning continues, but the external display output has stopped.'**
  String externalDisplayDisconnectedBanner(String display);

  /// Status line under the disconnected banner
  ///
  /// In en, this message translates to:
  /// **'waiting for display'**
  String get externalDisplayWaitingForDisplay;

  /// Failure banner when the window could not be created
  ///
  /// In en, this message translates to:
  /// **'The external display window could not be opened.'**
  String get externalDisplayFailedCreate;

  /// Fallback noun for the disconnected-display banner when the last known name is unavailable
  ///
  /// In en, this message translates to:
  /// **'selected display'**
  String get externalDisplaySelectedDisplay;

  /// Fixed frame shown when the external display window receives a launch payload it cannot decode
  ///
  /// In en, this message translates to:
  /// **'Window unavailable'**
  String get externalDisplayUnavailable;

  /// Dismisses the waiting-for-display state without forgetting the chosen display
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Chrome toggle label while the pop-out is closed (UX-PIP-01, V1 LABELS.documentPip)
  ///
  /// In en, this message translates to:
  /// **'Picture in Picture'**
  String get popOutEnter;

  /// Chrome toggle label while the pop-out is open (UX-PIP-01)
  ///
  /// In en, this message translates to:
  /// **'Exit Picture in Picture'**
  String get popOutExit;

  /// Banner shown in the main window while popped out (UX-PIP-05)
  ///
  /// In en, this message translates to:
  /// **'Captions are displaying in Picture-in-Picture'**
  String get popOutHint;

  /// Banner action that closes the pop-out (UX-PIP-05)
  ///
  /// In en, this message translates to:
  /// **'Return to Window'**
  String get popOutReturn;

  /// Visible reason under the disabled toggle when no session is active (BR-PIP-12)
  ///
  /// In en, this message translates to:
  /// **'Start captioning to pop captions out'**
  String get popOutUnavailableNoSession;

  /// Visible reason under the disabled toggle when no engine is available (BR-PIP-13)
  ///
  /// In en, this message translates to:
  /// **'No speech recognition engine is available on this device'**
  String get popOutUnavailableNoEngine;

  /// Failure line next to the toggle while the controller reports Failed
  ///
  /// In en, this message translates to:
  /// **'The pop-out window could not be opened'**
  String get popOutOpenFailed;
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
