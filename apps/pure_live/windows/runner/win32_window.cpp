
#include "win32_window.h"

#include <dwmapi.h>
#include <flutter_windows.h>
#include <windows.h>

#include "resource.h"

namespace {

/// Window attribute that enables dark mode window decorations.
///
/// Redefined in case the developer's machine has an older Windows SDK.
#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif

/// Window attribute that controls the preference for rounded corners.
///
/// Define the documented numeric value for compatibility with older SDKs.
#ifndef DWMWA_WINDOW_CORNER_PREFERENCE
#define DWMWA_WINDOW_CORNER_PREFERENCE 33
#endif

/// Converts logical coordinates to physical coordinates.
int Scale(int source, double scale_factor) {
  return static_cast<int>(source * scale_factor);
}

/// Registry key for app theme preference.
constexpr const wchar_t kGetPreferredBrightnessRegKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize";

constexpr const wchar_t kGetPreferredBrightnessRegValue[] =
    L"AppsUseLightTheme";

/// The number of Win32Window objects that currently exist.
static int g_active_window_count = 0;

using EnableNonClientDpiScaling = BOOL __stdcall(HWND hwnd);

constexpr const wchar_t kWindowClassName[] =
    L"FLUTTER_RUNNER_WIN32_WINDOW";

/// Dynamically loads EnableNonClientDpiScaling.
///
/// This API is only needed for PerMonitor V1 awareness mode.
void EnableFullDpiSupportIfAvailable(HWND hwnd) {
  HMODULE user32_module = LoadLibraryA("User32.dll");
  if (!user32_module) {
    return;
  }

  auto enable_non_client_dpi_scaling =
      reinterpret_cast<EnableNonClientDpiScaling*>(
          GetProcAddress(
              user32_module,
              "EnableNonClientDpiScaling"));

  if (enable_non_client_dpi_scaling != nullptr) {
    enable_non_client_dpi_scaling(hwnd);
  }

  FreeLibrary(user32_module);
}

/// Requests Windows 11 DWM rounded corners.
///
/// This is a preference, not a guarantee. DWM may ignore it depending
/// on the Windows version, window state, and custom frame implementation.
void ApplyWindowCornerPreference(HWND hwnd) {
  if (hwnd == nullptr) {
    return;
  }

  // DWMWCP_ROUND has the documented numeric value 2.
  // Explicitly cast it because older SDK compatibility macros may
  // otherwise cause an int-to-enum conversion error.
  const DWM_WINDOW_CORNER_PREFERENCE preference =
      static_cast<DWM_WINDOW_CORNER_PREFERENCE>(2);

  DwmSetWindowAttribute(
      hwnd,
      DWMWA_WINDOW_CORNER_PREFERENCE,
      &preference,
      sizeof(preference));
}

/// Updates the native window's dark-mode decoration preference.
void ApplyDarkModePreference(HWND hwnd) {
  if (hwnd == nullptr) {
    return;
  }

  DWORD light_mode = 1;
  DWORD light_mode_size = sizeof(light_mode);

  const LSTATUS result = RegGetValue(
      HKEY_CURRENT_USER,
      kGetPreferredBrightnessRegKey,
      kGetPreferredBrightnessRegValue,
      RRF_RT_REG_DWORD,
      nullptr,
      &light_mode,
      &light_mode_size);

  if (result == ERROR_SUCCESS) {
    const BOOL enable_dark_mode = light_mode == 0;

    DwmSetWindowAttribute(
        hwnd,
        DWMWA_USE_IMMERSIVE_DARK_MODE,
        &enable_dark_mode,
        sizeof(enable_dark_mode));
  }
}

}  // namespace

// Manages the Win32Window's window class registration.
class WindowClassRegistrar {
 public:
  ~WindowClassRegistrar() = default;

  /// Returns the singleton registrar instance.
  static WindowClassRegistrar* GetInstance() {
    if (!instance_) {
      instance_ = new WindowClassRegistrar();
    }
    return instance_;
  }

  /// Registers and returns the native window class name.
  const wchar_t* GetWindowClass();

  /// Unregisters the window class when no windows remain.
  void UnregisterWindowClass();

 private:
  WindowClassRegistrar() = default;

  static WindowClassRegistrar* instance_;

  bool class_registered_ = false;
};

WindowClassRegistrar* WindowClassRegistrar::instance_ = nullptr;

const wchar_t* WindowClassRegistrar::GetWindowClass() {
  if (!class_registered_) {
    WNDCLASS window_class{};

    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClassName;
    window_class.style = CS_HREDRAW | CS_VREDRAW;
    window_class.cbClsExtra = 0;
    window_class.cbWndExtra = 0;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon = LoadIcon(
        window_class.hInstance,
        MAKEINTRESOURCE(IDI_APP_ICON));
    window_class.hbrBackground = nullptr;
    window_class.lpszMenuName = nullptr;
    window_class.lpfnWndProc = Win32Window::WndProc;

    RegisterClass(&window_class);
    class_registered_ = true;
  }

  return kWindowClassName;
}

void WindowClassRegistrar::UnregisterWindowClass() {
  UnregisterClass(kWindowClassName, nullptr);
  class_registered_ = false;
}

Win32Window::Win32Window() {
  ++g_active_window_count;
}

Win32Window::~Win32Window() {
  --g_active_window_count;
  Destroy();
}

bool Win32Window::Create(
    const std::wstring& title,
    const Point& origin,
    const Size& size) {
  Destroy();

  const wchar_t* window_class =
      WindowClassRegistrar::GetInstance()->GetWindowClass();

  const POINT target_point = {
      static_cast<LONG>(origin.x),
      static_cast<LONG>(origin.y)};

  HMONITOR monitor =
      MonitorFromPoint(target_point, MONITOR_DEFAULTTONEAREST);

  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);
  double scale_factor = dpi / 96.0;

  HWND window = CreateWindow(
      window_class,
      title.c_str(),
      WS_OVERLAPPEDWINDOW,
      Scale(origin.x, scale_factor),
      Scale(origin.y, scale_factor),
      Scale(size.width, scale_factor),
      Scale(size.height, scale_factor),
      nullptr,
      nullptr,
      GetModuleHandle(nullptr),
      this);

  if (!window) {
    return false;
  }

  // Apply native window decorations after the HWND has been created.
  ApplyWindowCornerPreference(window);
  ApplyDarkModePreference(window);

  return OnCreate();
}

bool Win32Window::Show() {
  // SW_SHOW avoids restoring a maximized window unexpectedly.
  // Visibility remains controlled by the existing runner lifecycle.
  return ShowWindow(window_handle_, SW_SHOW);
}

// static
LRESULT CALLBACK Win32Window::WndProc(
    HWND const window,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept {
  if (message == WM_NCCREATE) {
    auto window_struct =
        reinterpret_cast<CREATESTRUCT*>(lparam);

    SetWindowLongPtr(
        window,
        GWLP_USERDATA,
        reinterpret_cast<LONG_PTR>(
            window_struct->lpCreateParams));

    auto that = static_cast<Win32Window*>(
        window_struct->lpCreateParams);

    EnableFullDpiSupportIfAvailable(window);
    that->window_handle_ = window;
  } else if (Win32Window* that =
                 GetThisFromHandle(window)) {
    return that->MessageHandler(
        window,
        message,
        wparam,
        lparam);
  }

  return DefWindowProc(
      window,
      message,
      wparam,
      lparam);
}

LRESULT Win32Window::MessageHandler(
    HWND hwnd,
    UINT const message,
    WPARAM const wparam,
    LPARAM const lparam) noexcept {
  switch (message) {
    case WM_DESTROY:
      window_handle_ = nullptr;
      Destroy();

      if (quit_on_close_) {
        PostQuitMessage(0);
      }

      return 0;

    case WM_DPICHANGED: {
      auto new_rect_size =
          reinterpret_cast<RECT*>(lparam);

      LONG new_width =
          new_rect_size->right - new_rect_size->left;

      LONG new_height =
          new_rect_size->bottom - new_rect_size->top;

      SetWindowPos(
          hwnd,
          nullptr,
          new_rect_size->left,
          new_rect_size->top,
          new_width,
          new_height,
          SWP_NOZORDER | SWP_NOACTIVATE);

      // Reapply the preference after a DPI transition.
      ApplyWindowCornerPreference(hwnd);
      return 0;
    }

    case WM_SIZE: {
      RECT rect = GetClientArea();

      if (child_content_ != nullptr) {
        MoveWindow(
            child_content_,
            rect.left,
            rect.top,
            rect.right - rect.left,
            rect.bottom - rect.top,
            TRUE);
      }

      return 0;
    }

    case WM_ACTIVATE:
      if (child_content_ != nullptr) {
        SetFocus(child_content_);
      }

      return 0;

    case WM_DWMCOLORIZATIONCOLORCHANGED:
      UpdateTheme(hwnd);
      return 0;
  }

  return DefWindowProc(
      hwnd,
      message,
      wparam,
      lparam);
}

void Win32Window::Destroy() {
  OnDestroy();

  if (window_handle_) {
    DestroyWindow(window_handle_);
    window_handle_ = nullptr;
  }

  if (g_active_window_count == 0) {
    WindowClassRegistrar::GetInstance()
        ->UnregisterWindowClass();
  }
}

Win32Window* Win32Window::GetThisFromHandle(
    HWND const window) noexcept {
  return reinterpret_cast<Win32Window*>(
      GetWindowLongPtr(window, GWLP_USERDATA));
}

void Win32Window::SetChildContent(HWND content) {
  child_content_ = content;

  SetParent(content, window_handle_);

  RECT frame = GetClientArea();

  MoveWindow(
      content,
      frame.left,
      frame.top,
      frame.right - frame.left,
      frame.bottom - frame.top,
      TRUE);

  SetFocus(child_content_);
}

RECT Win32Window::GetClientArea() {
  RECT frame{};
  GetClientRect(window_handle_, &frame);
  return frame;
}

HWND Win32Window::GetHandle() {
  return window_handle_;
}

void Win32Window::SetQuitOnClose(bool quit_on_close) {
  quit_on_close_ = quit_on_close;
}

bool Win32Window::OnCreate() {
  // No-op; provided for subclasses.
  return true;
}

void Win32Window::OnDestroy() {
  // No-op; provided for subclasses.
}

void Win32Window::UpdateTheme(HWND const window) {
  ApplyDarkModePreference(window);
}
