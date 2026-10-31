import Flutter
import Speech
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// Unit 10, Amendment 04: the language-pack channel pair. Held so the
  /// stream handler outlives the registration call.
  private let languagePack = LanguagePackChannel()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // Unit 10, Amendment 02 section 3.1: answers the on-device support
    // question the speech_to_text plugin does not expose. The engine owns the
    // fail-closed rule; this only reports the platform's answer.
    let speechSupport = FlutterMethodChannel(
      name: "app.zipcaptions/speech_support",
      binaryMessenger: engineBridge.applicationRegistrar.messenger()
    )
    speechSupport.setMethodCallHandler { call, result in
      guard call.method == "isOnDeviceSupported" else {
        result(FlutterMethodNotImplemented)
        return
      }
      // The Dart checker sends the locale as a bare string.
      let localeId = call.arguments as? String
      let locale = localeId.map { Locale(identifier: $0) } ?? Locale.current
      result(SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition ?? false)
    }

    languagePack.register(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// Unit 10, Amendment 04 (a missing on-device language): the iOS side of
/// `LanguagePackService`, on `app.zipcaptions/language_pack` (`status`,
/// `download`) and `app.zipcaptions/language_pack/events`.
///
/// iOS 26 and later only: `DictationTranscriber` and `AssetInventory` are
/// iOS 26.0+, so every use sits behind `#available(iOS 26.0, *)` and the
/// deployment target stays 13.0. Below 26, `status` answers "unknown" and
/// `download` answers a `FlutterError`.
///
/// ASSUMPTION A-1 (Amendment 04 section 2): that an `AssetInventory`
/// download makes `SFSpeechRecognizer.supportsOnDeviceRecognition` true for
/// the locale is NOT stated by the documents. It is verified in the
/// reviewer's iOS pass on an iOS 26 Simulator or device before the button
/// ships.
///
/// SECURITY-03: logs and events carry a status, a percentage or a locale tag
/// only; never recognised text.
final class LanguagePackChannel: NSObject, FlutterStreamHandler {
  private var sink: FlutterEventSink?

  func register(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "app.zipcaptions/language_pack",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      let localeId = (call.arguments as? [String: Any])?["localeId"] as? String
      switch call.method {
      case "status":
        guard let localeId = localeId else {
          result(FlutterError(code: "bad_arguments", message: nil, details: nil))
          return
        }
        self.status(localeId: localeId, result: result)
      case "download":
        guard let localeId = localeId else {
          result(FlutterError(code: "bad_arguments", message: nil, details: nil))
          return
        }
        self.download(localeId: localeId, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    FlutterEventChannel(
      name: "app.zipcaptions/language_pack/events",
      binaryMessenger: messenger
    ).setStreamHandler(self)
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    sink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }

  /// Events leave on the main thread.
  private func send(_ event: [String: Any]) {
    DispatchQueue.main.async { [weak self] in
      self?.sink?(event)
    }
  }

  private func displayName(_ localeId: String) -> String {
    Locale.current.localizedString(forIdentifier: localeId) ?? localeId
  }

  private func status(localeId: String, result: @escaping FlutterResult) {
    let name = displayName(localeId)
    guard #available(iOS 26.0, *) else {
      result(["status": "unknown", "displayName": name])
      return
    }
    Task {
      let status = await Self.statusString(localeId: localeId)
      NSLog("ZipCaptionsLanguagePack status: %@ %@", localeId, status)
      DispatchQueue.main.async {
        result(["status": status, "displayName": name])
      }
    }
  }

  /// `SFSpeechRecognizer.supportsOnDeviceRecognition` first (the check that
  /// decides whether captioning starts); then `AssetInventory.status`, then
  /// the transcriber's supported locales.
  @available(iOS 26.0, *)
  private static func statusString(localeId: String) async -> String {
    let locale = Locale(identifier: localeId)
    // apple-speech: SFSpeechRecognizer.supportsOnDeviceRecognition.
    if SFSpeechRecognizer(locale: locale)?.supportsOnDeviceRecognition == true {
      return "installed"
    }
    // apple-speech: AssetInventory.status(forModules:) returns one of
    // downloading, installed, supported ("assets will need to be
    // downloaded") or unsupported ("will not work with its configuration").
    // Amendment 04 revision 1b: unsupported is final; the transcriber's
    // supported locales are not consulted as a second opinion, and the locale
    // is used as given (no supportedLocale(equivalentTo:) call).
    let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
    switch await AssetInventory.status(forModules: [transcriber]) {
    case .downloading: return "downloading"
    case .installed: return "installed"
    case .supported: return "downloadable"
    case .unsupported: return "unsupported"
    @unknown default: return "unknown"
    }
  }

  private func download(localeId: String, result: @escaping FlutterResult) {
    guard #available(iOS 26.0, *) else {
      result(FlutterError(code: "unsupported_os_version", message: nil, details: nil))
      return
    }
    // The outcome arrives as events; the reply says only that it started.
    result(nil)
    Task {
      await self.runDownload(localeId: localeId)
    }
  }

  @available(iOS 26.0, *)
  private func runDownload(localeId: String) async {
    let locale = Locale(identifier: localeId)
    // apple-speech: DictationTranscriber.Preset.progressiveLongDictation
    // ("immediate transcription of lengthy audio") is the closest preset to
    // continuous captioning; the system installs assets by the module's
    // configuration, not its object identity (AssetInventory overview).
    let transcriber = DictationTranscriber(locale: locale, preset: .progressiveLongDictation)
    do {
      // apple-speech: assetInstallationRequest(supporting:) returns nil when
      // the status is already installed ("nothing further needs to be done").
      guard let request = try await AssetInventory.assetInstallationRequest(
        supporting: [transcriber]
      ) else {
        NSLog("ZipCaptionsLanguagePack already installed: %@", localeId)
        send(["type": "done", "localeId": localeId])
        return
      }
      // apple-speech: AssetInstallationRequest conforms to ProgressReporting.
      let observation = request.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
        let percent = Int((progress.fractionCompleted * 100).rounded())
        NSLog("ZipCaptionsLanguagePack progress %d", percent)
        self?.send(["type": "progress", "localeId": localeId, "percent": percent])
      }
      defer { observation.invalidate() }
      // apple-speech: downloadAndInstall() returns when the first attempt has
      // succeeded or failed; the system retries a failed download later.
      try await request.downloadAndInstall()
      NSLog("ZipCaptionsLanguagePack download done: %@", localeId)
      send(["type": "done", "localeId": localeId])
    } catch {
      NSLog("ZipCaptionsLanguagePack download failed: %@", String(describing: type(of: error)))
      send(["type": "failed", "localeId": localeId])
    }
  }
}
