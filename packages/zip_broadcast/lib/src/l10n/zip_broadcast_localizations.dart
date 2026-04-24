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
