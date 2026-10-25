#include "flutter_window.h"

#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>

#include <cwchar>
#include <memory>
#include <optional>
#include <set>
#include <vector>

#include "desktop_multi_window/desktop_multi_window_plugin.h"
#include "flutter/generated_plugin_registrant.h"
#include "utils.h"

namespace {

// The room windows' small runner channel: a sub-engine cannot address its
// own window through the window plugins (the native layer resolves the
// current window from the calling thread's active window, and a
// desktop_multi_window engine runs its Dart on a thread that owns no
// window), so the verbs a room window needs — its HWND, a close, a title —
// live here, answered on the main thread where the window was created.
// The channels are kept alive for the process: one per room window, few.
std::vector<std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>>& RoomWindowChannels() {
  static std::vector<std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>> channels;
  return channels;
}

std::wstring ToWide(const std::string& utf8) {
  if (utf8.empty()) {
    return std::wstring();
  }
  int size = ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), nullptr, 0);
  std::wstring wide(static_cast<size_t>(size), L'\0');
  ::MultiByteToWideChar(CP_UTF8, 0, utf8.c_str(), static_cast<int>(utf8.size()), wide.data(), size);
  wide.resize(static_cast<size_t>(size));
  return wide;
}

// The class desktop_multi_window gives every clone top-level. The primary
// window uses FLUTTER_RUNNER_WIN32_WINDOW; serving the runner channel against
// that window would make a clone's close button quit the whole app.
constexpr const wchar_t kCloneWindowClass[] = L"FLUTTER_MULTI_WINDOW_WIN32_WINDOW";

std::set<HWND>& ServedCloneWindows() {
  static std::set<HWND> windows;
  return windows;
}

bool IsCloneWindow(HWND hwnd) {
  if (hwnd == nullptr) {
    return false;
  }
  wchar_t name[64] = {};
  if (::GetClassNameW(hwnd, name, 64) == 0) {
    return false;
  }
  return wcscmp(name, kCloneWindowClass) == 0;
}

struct FindCloneContext {
  DWORD pid;
  HWND found;
};

BOOL CALLBACK FindUnclaimedClone(HWND hwnd, LPARAM opaque) {
  auto* context = reinterpret_cast<FindCloneContext*>(opaque);
  DWORD pid = 0;
  ::GetWindowThreadProcessId(hwnd, &pid);
  if (pid == context->pid && IsCloneWindow(hwnd) &&
      ServedCloneWindows().find(hwnd) == ServedCloneWindows().end()) {
    context->found = hwnd;
    return FALSE;
  }
  return TRUE;
}

void ServeRoomWindow(flutter::FlutterViewController* controller) {
  HWND child = controller->view()->GetNativeWindow();
  // The Flutter view is a child of the top-level window; title, frame style,
  // close and maximise belong to the top-level HWND.
  HWND hwnd = ::GetAncestor(child, GA_ROOT);
  if (hwnd == nullptr) {
    hwnd = child;
  }
  // A view that resolves to the primary's runner window means the clone
  // window is not in this view's parent chain. Find the engine's own
  // FLUTTER_MULTI_WINDOW window instead of ever driving the primary.
  if (!IsCloneWindow(hwnd) || ServedCloneWindows().count(hwnd) != 0) {
    // Drop handles from closed windows first; a handle can be reused.
    for (auto it = ServedCloneWindows().begin(); it != ServedCloneWindows().end();) {
      if (::IsWindow(*it)) {
        ++it;
      } else {
        it = ServedCloneWindows().erase(it);
      }
    }
    FindCloneContext context{::GetCurrentProcessId(), nullptr};
    ::EnumWindows(FindUnclaimedClone, reinterpret_cast<LPARAM>(&context));
    hwnd = context.found;
  }
  if (!IsCloneWindow(hwnd)) {
    ::OutputDebugStringW(L"[pure_live] clone window handle not found; room channel skipped\n");
    return;
  }
  ServedCloneWindows().insert(hwnd);
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      controller->engine()->messenger(), "pure_live/room_window",
      &flutter::StandardMethodCodec::GetInstance());
  channel->SetMethodCallHandler(
      [hwnd](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "hwnd") {
          result->Success(flutter::EncodableValue(static_cast<int64_t>(reinterpret_cast<intptr_t>(hwnd))));
        } else if (call.method_name() == "close") {
          // WM_CLOSE lands in the plugin's own window proc: the engine is
          // torn down and the process stays, because a sub-window does not
          // quit on close.
          ServedCloneWindows().erase(hwnd);
          ::PostMessage(hwnd, WM_CLOSE, 0, 0);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "title") {
          const auto* text = std::get_if<std::string>(call.arguments());
          if (text != nullptr) {
            std::wstring wide = ToWide(*text);
            ::SetWindowTextW(hwnd, wide.c_str());
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "chrome") {
          const auto* custom = std::get_if<bool>(call.arguments());
          if (custom != nullptr) {
            LONG_PTR style = ::GetWindowLongPtrW(hwnd, GWL_STYLE);
            if (*custom) {
              // The app draws the strip; keep the resize frame and the
              // system menu bits so snap, edges and the taskbar still work.
              style &= ~WS_CAPTION;
            } else {
              style |= WS_CAPTION;
            }
            ::SetWindowLongPtrW(hwnd, GWL_STYLE, style);
            ::SetWindowPos(hwnd, nullptr, 0, 0, 0, 0,
                           SWP_FRAMECHANGED | SWP_NOMOVE | SWP_NOSIZE |
                               SWP_NOZORDER | SWP_NOACTIVATE);
          }
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "startDragging") {
          ::ReleaseCapture();
          ::SendMessageW(hwnd, WM_NCLBUTTONDOWN, HTCAPTION, 0);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "minimize") {
          ::ShowWindow(hwnd, SW_MINIMIZE);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "maximize") {
          ::ShowWindow(hwnd, SW_MAXIMIZE);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "restore") {
          ::ShowWindow(hwnd, SW_RESTORE);
          result->Success(flutter::EncodableValue(true));
        } else if (call.method_name() == "isMaximized") {
          result->Success(flutter::EncodableValue(::IsZoomed(hwnd) != 0));
        } else {
          result->NotImplemented();
        }
      });
  RoomWindowChannels().push_back(std::move(channel));
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
  // Sub-windows created by desktop_multi_window run their own engines; each
  // one needs the plugins registered too, or the room windows come up
  // without window_manager, the player and the rest of the stack. The room
  // window channel rides along on the same hook.
  DesktopMultiWindowSetWindowCreatedCallback([](void *controller) {
    auto *flutter_view_controller =
        reinterpret_cast<flutter::FlutterViewController *>(controller);
    RegisterPlugins(flutter_view_controller->engine());
    ServeRoomWindow(flutter_view_controller);
  });
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure a
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
