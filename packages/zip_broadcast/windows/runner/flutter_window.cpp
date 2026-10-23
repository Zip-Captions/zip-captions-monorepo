#include "flutter_window.h"

#include <optional>

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <map>

#include "flutter/generated_plugin_registrant.h"

namespace {

// Sub-window ids by top-level HWND, and the per-window minimum sizes the
// `configure` handler recorded (ID §4a). File-scope because the window-proc
// delegate and the created-window callback share one process-wide map.
std::map<HWND, int64_t>& WindowIds() {
  static std::map<HWND, int64_t> ids;
  return ids;
}

std::map<HWND, SIZE>& WindowMinSizes() {
  static std::map<HWND, SIZE> sizes;
  return sizes;
}

// The main engine's close channel (ID §4b).
flutter::MethodChannel<flutter::EncodableValue>* SubWindowEvents() {
  static flutter::MethodChannel<flutter::EncodableValue>* channel = nullptr;
  return channel;
}

// Raises `subWindowClosed` for |hwnd| if the runner recorded an id for it.
// Fire-and-forget: nothing on the close path waits for a Dart reply.
void EmitSubWindowClosed(HWND hwnd) {
  auto& ids = WindowIds();
  auto it = ids.find(hwnd);
  if (it == ids.end()) {
    return;
  }
  int64_t id = it->second;
  ids.erase(it);
  WindowMinSizes().erase(hwnd);

  auto* channel = SubWindowEvents();
  if (!channel) {
    return;
  }
  flutter::EncodableMap args;
  args[flutter::EncodableValue("windowId")] = flutter::EncodableValue(id);
  channel->InvokeMethod(
      "subWindowClosed",
      std::make_unique<flutter::EncodableValue>(flutter::EncodableValue(args)),
      nullptr);
}

// Additive window-proc delegate: applies the stored minimum size and raises
// the close event. Returns nullopt in every branch so the plugin's own
// WM_CLOSE/WM_DESTROY handling still runs exactly as shipped (R-B2).
std::optional<LRESULT> SubWindowProc(HWND hwnd, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
  switch (message) {
    case WM_GETMINMAXINFO: {
      auto it = WindowMinSizes().find(hwnd);
      if (it != WindowMinSizes().end()) {
        auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
        info->ptMinTrackSize.x = it->second.cx;
        info->ptMinTrackSize.y = it->second.cy;
      }
      return std::nullopt;
    }
    case WM_CLOSE:
      EmitSubWindowClosed(hwnd);
      return std::nullopt;
    default:
      return std::nullopt;
  }
}

// The sub-engine's `configure` handler (ID §4a). Validates by type and
// answers a fixed error on rejection; no field value is ever reflected back.
void InstallConfigureChannel(flutter::FlutterViewController* controller) {
  auto registrar = flutter::PluginRegistrarManager::GetInstance()
                       ->GetRegistrar<flutter::PluginRegistrarWindows>(
                           controller->engine()->GetRegistrarForPlugin(
                               "ZipCoreOverlayWindow"));
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "zip_core/overlay_window_configure",
      &flutter::StandardMethodCodec::GetInstance());
  // Deliberately leaked: the channel lives as long as its sub-window, and the
  // window's teardown is not a place to run plugin code.
  channel.release()->SetMethodCallHandler(
      [controller](const flutter::MethodCall<flutter::EncodableValue>& call,
                   std::unique_ptr<
                       flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() != "configure") {
          result->NotImplemented();
          return;
        }
        const auto* args =
            std::get_if<flutter::EncodableMap>(call.arguments());
        if (!args) {
          result->Error("configure_invalid");
          return;
        }
        auto int_value = [args](const char* key) -> std::optional<int64_t> {
          auto it = args->find(flutter::EncodableValue(key));
          if (it == args->end()) return std::nullopt;
          const auto* value = std::get_if<int64_t>(&it->second);
          if (!value) return std::nullopt;
          return *value;
        };
        auto bool_value = [args](const char* key) -> std::optional<bool> {
          auto it = args->find(flutter::EncodableValue(key));
          if (it == args->end()) return std::nullopt;
          const auto* value = std::get_if<bool>(&it->second);
          if (!value) return std::nullopt;
          return *value;
        };
        auto double_value = [args](const char* key) -> std::optional<double> {
          auto it = args->find(flutter::EncodableValue(key));
          if (it == args->end()) return std::nullopt;
          const auto* value = std::get_if<double>(&it->second);
          if (!value) return std::nullopt;
          return *value;
        };

        auto window_id = int_value("windowId");
        auto floating = bool_value("floating");
        auto decorated = bool_value("decorated");
        auto min_width = double_value("minWidth");
        auto min_height = double_value("minHeight");

        if (!window_id || *window_id < 0 || !floating || !decorated ||
            !min_width || *min_width < 0 || !min_height || *min_height < 0) {
          result->Error("configure_invalid");
          return;
        }

        if (!controller->view()) {
          result->Error("configure_invalid");
          return;
        }
        HWND hwnd =
            GetAncestor(controller->view()->GetNativeWindow(), GA_ROOT);
        if (!hwnd) {
          result->Error("configure_invalid");
          return;
        }

        SetWindowPos(hwnd, *floating ? HWND_TOPMOST : HWND_NOTOPMOST, 0, 0, 0,
                     0, SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);

        LONG style = GetWindowLong(hwnd, GWL_STYLE);
        const LONG decoration = WS_CAPTION | WS_THICKFRAME | WS_MINIMIZEBOX |
                                WS_MAXIMIZEBOX | WS_SYSMENU;
        if (*decorated) {
          style |= decoration;
        } else {
          style &= ~decoration;
        }
        SetWindowLong(hwnd, GWL_STYLE, style);
        SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                     SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER |
                         SWP_FRAMECHANGED);

        WindowMinSizes()[hwnd] = SIZE{
            static_cast<LONG>(*min_width), static_cast<LONG>(*min_height)};
        WindowIds()[hwnd] = *window_id;

        result->Success();
      });
}

}  // namespace

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());

  // Registered once, on the main engine, before any sub-window can exist.
  auto sub_window_events =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(),
          "zip_core/overlay_sub_window_events",
          &flutter::StandardMethodCodec::GetInstance());
  sub_window_events.release()->SetMethodCallHandler(nullptr);
  SubWindowEvents() = sub_window_events.release();

  // Sub-windows are caption surfaces, not app windows. Unit 8 stripped their
  // decoration here unconditionally; this unit moves every styling decision
  // into the `configure` channel (BR-U8.1-04), so the external display still
  // arrives borderless and the pop-out asks for a floating decorated frame.
  // The runner is mode-blind: it applies what Dart sends.
  DesktopMultiWindowSetWindowCreatedCallback([](void* controller) {
    if (!controller) {
      return;
    }
    auto* flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController*>(controller);
    InstallConfigureChannel(flutter_view_controller);

    auto registrar = flutter::PluginRegistrarManager::GetInstance()
                         ->GetRegistrar<flutter::PluginRegistrarWindows>(
                             flutter_view_controller->engine()
                                 ->GetRegistrarForPlugin(
                                     "ZipCoreOverlayWindow"));
    registrar->RegisterTopLevelWindowProcDelegate(SubWindowProc);
  });

  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

void FlutterWindow::OnDestroy() {
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}