import Cocoa
import FlutterMacOS
import desktop_multi_window

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // External display windows are caption surfaces, not app windows: they get
    // no title bar and no resize handles. The window is borderless but stays
    // focusable, so the broadcaster can still bring it forward.
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { controller in
      let window = controller.view.window
      window?.styleMask.remove([.titled, .closable, .miniaturizable, .resizable])
    }

    super.awakeFromNib()
  }
}
