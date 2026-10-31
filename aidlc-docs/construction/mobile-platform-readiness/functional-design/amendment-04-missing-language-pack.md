# Functional Design Amendment 04: a missing on-device language (Q-5)

**Unit**: 10, Mobile Platform Readiness (S-22). **Date**: 2026-10-26. **Revision**: 1. **Status**: APPROVED by James Petersen, 2026-10-26 ("Your plan is approved"), as proposed in the Group G review: Android 13+ downloads the language from the app; iOS 26+ downloads it from the app through `AssetInventory`; iOS 13 to 25 shows instructions.
**Amendments 01 to 03 stand.** This amendment adds a recovery path to the on-device refusal (Amendment 02 BR-U10-27); every change to earlier documents is named in section 8.

## 1. Finding Q-5

When the phone has no on-device model for the chosen language, the app correctly refuses ("On-device captions aren't available"), but the panel offers no way forward: "Open settings" is deliberately hidden for this kind (BR-U10-10, TP-8). In the emulator QA the reviewer worked round it by opening Android Settings with `adb`, which hid the finding. A tester with a stock phone would hit it on day one.

## 2. Evidence (docs-mcp; libraries indexed 2026-10-26)

| Fact | Source |
|---|---|
| Android 13 (API 33): `checkRecognitionSupport` reports `getInstalledOnDeviceLanguages()` ("ready for use"), `getPendingOnDeviceLanguages()` ("scheduled for download") and `getSupportedOnDeviceLanguages()` ("supported but need to be downloaded before use. See `SpeechRecognizer.triggerModelDownload(Intent)`") | `android-speech-recognitionsupport` |
| Android 13 (API 33): `triggerModelDownload(Intent)` "Attempts to download the support for the given `recognizerIntent`. This might trigger user interaction to approve the download." API 34 adds a form with a `ModelDownloadListener` (progress, success, error) | developer.android.com `SpeechRecognizer`, read through docs-mcp `fetch_url` (the site's redirect loop blocks indexing) |
| iOS: `SFSpeechRecognizer` has no download method; `supportsOnDeviceRecognition` only reports | `apple-speech`, `supportsOnDeviceRecognition` |
| iOS 26: `DictationTranscriber` "uses the same speech-to-text machine learning models as system dictation features do, or as `SFSpeechRecognizer` does when it is configured for on-device operation"; `supportedLocales` includes "locales that may not be installed but are downloadable"; `installedLocales` lists the installed ones | `apple-speech`, `DictationTranscriber` (iOS 26.0+) |
| iOS 26: `AssetInventory.assetInstallationRequest(supporting:)` → `AssetInstallationRequest.downloadAndInstall()`, which conforms to `ProgressReporting`; failed downloads are retried by the system later; models are shared between apps | `apple-speech`, `AssetInventory`, `AssetInstallationRequest` (iOS 26.0+) |
| iOS: an app can deep-link only to its own Settings page | UIKit `openSettingsURLString` |
| iPhone user steps: Settings → General → Keyboard → turn on Enable Dictation; Settings → General → Keyboard → Keyboards → Add New Keyboard ("You can add keyboards for writing or using Dictation in different languages") | `apple-iphone-user-guide-dictation`, `apple-iphone-user-guide-keyboards` |
| Our targets: iOS deployment target 13.0 (`project.pbxproj`); Android installs from API 24 (`flutter.minSdkVersion`, Flutter 3.41.7), captions from API 33 (Amendment 03 D-1) | repository |

**Assumption to verify (A-1):** the documents say the iOS 26 transcriber and `SFSpeechRecognizer` share the same on-device models, but not explicitly that an `AssetInventory` download makes `SFSpeechRecognizer.supportsOnDeviceRecognition` true for that locale. The iOS pass verifies it on the iOS 26 Simulator or a device before the iOS 26 button ships; if it fails, iOS 26 falls back to the instructions (section 4).

## 3. Shape

- **A language-pack status per locale**, asked through the existing runner channels: `installed`, `downloading` (pending), `downloadable`, `unsupported`, `unknown` (the check failed). Android: from `checkRecognitionSupport`. iOS 26+: `DictationTranscriber.installedLocales` and `supportedLocales`. iOS below 26: `unknown` (the existing `supportsOnDeviceRecognition` check still decides whether to start).
- **A download request**, Android: `triggerModelDownload` (API 34+ with `ModelDownloadListener` for progress and the result; API 33 fires and the app re-checks the status). iOS 26+: `AssetInventory.assetInstallationRequest(supporting: [DictationTranscriber(locale:…)])?.downloadAndInstall()`, progress from the request's `Progress`.
- **Channels** (revision 1a, before build): one dedicated pair on both platforms, method `app.zipcaptions/language_pack` (`status`, `download`) and event `app.zipcaptions/language_pack/events` (`progress`, `done`, `failed`), so the speech event stream stays unchanged. The status reply carries the language's display name from the platform (`Locale.getDisplayName` on Android, `Locale.localizedString(forIdentifier:)` on iOS), because Flutter has no locale display names without a new package. `SegmentedRecognizerBridge` separately gains `supportedLocales()` (the Group G review gap: the Kotlin side exists, the Dart interface does not).
- **`zip_core`** gets a small `LanguagePackService` interface (status, download, progress stream) with the two channel implementations in `zip_captions`; the engines are not changed.

## 4. Rules

| ID | Rule |
|---|---|
| BR-U10-46 | **The refusal says what is fixable.** When `onDeviceRecognitionUnavailable` is shown, the panel asks the language-pack status for the session's locale. `downloadable` → a "Download [language]" button. `downloading` → a progress state ("Downloading [language]…"). `unsupported` → the existing text with no action. `unknown` or iOS below 26 → the existing text plus the platform's instructions (section 5). |
| BR-U10-47 | **Download, then try again.** The button starts the download and shows progress where the platform reports it (Android 14+, iOS 26+); otherwise an indeterminate state and a status re-check every 5 seconds for up to 5 minutes. On `installed` the panel shows "Ready" and Try again starts normally; the app never starts captioning by itself. A failed or timed-out download shows "Couldn't download [language]. Check your connection and try again." with Try again. |
| BR-U10-47a | **A deferred download is not a failure** (revision 1b, Group H review). Android's `ModelDownloadListener.onScheduled()` means the service "scheduled the download, but won't satisfy it immediately. There will be no further updates on this listener"; a first status check that answers `downloading` (Android "pending": "scheduled for download") means the same. Both show a **scheduled** state: "{language} will download later, for example when you're on Wi-Fi. Tap Try again once it has downloaded.", with Try again and no time limit. The 5-minute limit and the failure text of BR-U10-47 apply only after a tap that produces no event at all (Android 13's fire-and-recheck). |
| BR-U10-46a | **The Android check is locale-level** (revision 1c, APPROVED by James Petersen 2026-10-26 after the Step 30 Android QA). The `isOnDeviceSupported(localeId)` answer on Android is `SDK_INT >= 33 && isOnDeviceRecognitionAvailable && the locale is in checkRecognitionSupport's installedOnDeviceLanguages` (tags compared case-insensitively, `-` and `_` the same; an error or timeout answers false, and the engine already fails closed). A missing pack therefore refuses at start, so the failure panel and its BR-U10-46 action appear; without this the refusal arrived as a mid-session `LANGUAGE_UNAVAILABLE` and the app went to History. This replaces the device-level-only limit Amendment 02 accepted (R10) on Android 13 and later. |
| BR-U10-48 | **User action only.** No download starts without the user's tap. A download may need the user's approval in a system dialog (Android); the app does not try to suppress or pre-empt it. |
| BR-U10-49 | **No transcript text, no network for speech.** The download fetches the platform's model only; recognition stays on-device (Amendment 02 unchanged). Logs carry the status enum and progress percentage only. |
| BR-U10-50 | **The Android language list.** `SegmentedSpeechEngine.supportedLocales()` returns the bridge's on-device languages (installed, pending and downloadable), so Settings can list them; a failure returns an empty list, and the resolver falls back as in Amendment 03 section 6. |

## 5. Text (British English, `.arb` + `ZcStrings`)

- Button: "Download {language}". Progress: "Downloading {language}… {percent}%" or "Downloading {language}…". Ready: "{language} is ready. Tap Try again to start captioning." Failure: "Couldn't download {language}. Check your connection and try again."
- iOS below 26 (instructions): "To caption in {language}, turn on Dictation and add a {language} keyboard: open Settings, then General, then Keyboard. Turn on Enable Dictation, then tap Keyboards and Add New Keyboard."
- Scheduled (BR-U10-47a): "{language} will download later, for example when you're on Wi-Fi. Tap Try again once it has downloaded."
- iOS status mapping (revision 1b): `AssetInventory.Status.unsupported` is final (`unsupported`); `DictationTranscriber.supportedLocale(equivalentTo:)` is not used as a second opinion after it.
- `{language}` is the locale's display name in the app's language.

## 6. Testable properties

| ID | Property |
|---|---|
| TP-28 | The panel action is total over (platform, OS version, status): every combination maps to exactly one of download button, progress, instructions, none, as BR-U10-46. |
| TP-29 | No download call without a tap; at most one download in flight per locale; Try again is the only path back to `start()`. |
| TP-30 | Status and download channel contracts (names, arguments, decoding), with unknown or malformed replies treated as `unknown`. |
| TP-31 | `supportedLocales()` maps the bridge's tags (BR-U10-50); log hygiene (TP-12) extended to the new logs. |

## 7. Device and Simulator checks

- Android emulator (our AVD, no pack): the panel offers "Download English (United States)"; the system may show an approval dialog; after the download, Try again captions real speech (played after the recogniser reports ready).
- iOS 26 Simulator: assumption A-1. If the download does not make `supportsOnDeviceRecognition` true, record it and fall back to the instructions on iOS 26.
- An iOS below 26 device, if available, for the instructions path.

## 8. Changes to earlier documents

- BR-U10-10 and TP-8: the on-device kind still never shows "Open settings"; it gains the BR-U10-46 action instead.
- Amendment 03 section 3: the bridge gains `supportedLocales()`, the status and the download calls.
- NFR: the download uses the network for the model only; the privacy statement (Amendment 02 section 6.2) is unchanged because recognition stays on-device.

## 9. Compliance

Security Baseline: no new permission on either platform; the download is a platform service the user approves; SECURITY-03 by TP-31. PBT: TP-28 total mapping (PBT-07 generators over the cross product), TP-29 stateful, example pins per platform and version. No blocking finding.
