import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  /// The main engine's close channel (ID §4b). Retained for the app's
  /// lifetime; the runner is the only place that raises `subWindowClosed`.
  private var subWindowEvents: FlutterMethodChannel?

  /// Sub-window ids by window identity, filled by the `configure` handler and
  /// drained by the `willClose` observer (ID §4a, §4c).
  private var windowIds: [ObjectIdentifier: Int] = [:]

  /// Observer tokens for the close hooks, so a closed window's entry can be
  /// removed with it.
  private var closeObservers: [ObjectIdentifier: NSObjectProtocol] = [:]

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Registered once, on the main engine, before any sub-window can exist
    // (Dart installs its handler in the host before the first `createWindow`).
    subWindowEvents = FlutterMethodChannel(
      name: "zip_core/overlay_sub_window_events",
      binaryMessenger: flutterViewController.engine.binaryMessenger)

    // Sub-windows are caption surfaces, not app windows. Unit 8 stripped their
    // decoration here unconditionally; this unit moves every styling decision
    // into the `configure` channel, so the external display still arrives
    // borderless (its window properties are `floating: false,
    // decorated: false`) and the pop-out asks for a floating decorated frame
    // (BR-U8.1-04). The runner is mode-blind: it applies what Dart sends.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { [weak self] controller in
      guard let self else { return }
      self.installConfigureChannel(for: controller)
      self.installCloseHook(for: controller)
    }

    super.awakeFromNib()
  }

  /// Installs the sub-engine's `configure` handler (ID §4a).
  ///
  /// The handler validates by type and answers a fixed error on rejection; it
  /// never reflects a field value back (SECURITY-05, nfr-design-patterns §3.1).
  private func installConfigureChannel(for controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "zip_core/overlay_window_configure",
      binaryMessenger: controller.registrar(
        forPlugin: "ZipCoreOverlayWindow").messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "configure" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard
        let args = call.arguments as? [String: Any],
        let windowId = args["windowId"] as? Int, windowId >= 0,
        let floating = args["floating"] as? Bool,
        let decorated = args["decorated"] as? Bool,
        let minWidth = args["minWidth"] as? Double,
        minWidth.isFinite, minWidth >= 0,
        let minHeight = args["minHeight"] as? Double,
        minHeight.isFinite, minHeight >= 0,
        let window = controller.view.window
      else {
        result(FlutterError(code: "configure_invalid", message: nil, details: nil))
        return
      }

      window.level = floating ? .floating : .normal
      // The plugin's creation mask minus what Unit 8 stripped, so
      // `decorated: false` reproduces the shipped borderless window exactly.
      let decoration: NSWindow.StyleMask = [
        .titled, .closable, .miniaturizable, .resizable,
      ]
      if decorated {
        window.styleMask.insert(decoration)
      } else {
        window.styleMask.remove(decoration)
      }
      window.contentMinSize = NSSize(width: minWidth, height: minHeight)

      self?.windowIds[ObjectIdentifier(window)] = windowId
      result(nil)
    }
  }

  /// Observes each sub-window's close and raises the main-engine event.
  ///
  /// An observer, never a delegate: `desktop_multi_window` owns the delegate
  /// and replacing it would break the plugin's own teardown (R-B2).
  private func installCloseHook(for controller: FlutterViewController) {
    guard let window = controller.view.window else { return }
    let key = ObjectIdentifier(window)
    closeObservers[key] = NotificationCenter.default.addObserver(
      forName: NSWindow.willCloseNotification, object: window, queue: nil
    ) { [weak self] note in
      guard let self, let closed = note.object as? NSWindow else { return }
      let closedKey = ObjectIdentifier(closed)
      // Removed before the id lookup: a window whose `configure` never
      // recorded an id still ends here, and its observer must not outlive it
      // in `closeObservers`.
      if let token = self.closeObservers.removeValue(forKey: closedKey) {
        NotificationCenter.default.removeObserver(token)
      }
      guard let id = self.windowIds.removeValue(forKey: closedKey) else {
        return
      }
      // Fire-and-forget: the close path must not wait for a Dart reply.
      self.subWindowEvents?.invokeMethod(
        "subWindowClosed", arguments: ["windowId": id])
    }
  }
}