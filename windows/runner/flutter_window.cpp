#include "flutter_window.h"

#include <algorithm>
#include <cmath>
#include <optional>
#include <set>

#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {
  // Some Dart-side exit paths end the message loop before Windows has sent
  // WM_DESTROY. Calling Destroy only from Win32Window's base destructor is too
  // late: C++ has already destroyed flutter_controller_, while its child HWND
  // can still synchronously notify the live parent window. Tear down through
  // the derived virtual OnDestroy while every guard member is still alive.
  Destroy();
}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }
  flutter_controller_destroying_ = false;

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

  display_mode_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "pure_live/display_mode",
          &flutter::StandardMethodCodec::GetInstance());
  display_mode_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        if (call.method_name() == "getDisplayModeInfo" ||
            call.method_name() == "setHighRefreshRate") {
          const DisplayModeSnapshot snapshot = ReadDisplayMode();
          RememberDisplayMode(snapshot);
          result->Success(EncodeDisplayMode(snapshot));
          return;
        }
        result->NotImplemented();
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
  // FlutterViewController destruction synchronously destroys its child HWND,
  // which sends WM_PARENTNOTIFY back to this top-level window. At that point
  // the wrapper still exists but its internal view is null, so forwarding the
  // re-entrant message would crash in FlutterWindowsView::GetEngine().
  flutter_controller_destroying_ = true;
  display_mode_channel_.reset();
  flutter_controller_.reset();

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == WM_MOVE || message == WM_DISPLAYCHANGE ||
      message == WM_DPICHANGED) {
    NotifyDisplayModeChanged(message == WM_DISPLAYCHANGE);
  }

  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_ && !flutter_controller_destroying_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      if (flutter_controller_ && !flutter_controller_destroying_) {
        flutter_controller_->engine()->ReloadSystemFonts();
      }
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}

FlutterWindow::DisplayModeSnapshot FlutterWindow::ReadDisplayMode() const {
  DisplayModeSnapshot snapshot;
  const HWND window = const_cast<FlutterWindow*>(this)->GetHandle();
  if (!window) {
    return snapshot;
  }

  const HMONITOR monitor =
      MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
  MONITORINFOEXW monitor_info{};
  monitor_info.cbSize = sizeof(monitor_info);
  if (!GetMonitorInfoW(monitor, &monitor_info)) {
    return snapshot;
  }
  snapshot.device_name = monitor_info.szDevice;

  DEVMODEW current{};
  current.dmSize = sizeof(current);
  if (!EnumDisplaySettingsExW(monitor_info.szDevice, ENUM_CURRENT_SETTINGS,
                              &current, 0)) {
    return snapshot;
  }

  snapshot.width = static_cast<int>(current.dmPelsWidth);
  snapshot.height = static_cast<int>(current.dmPelsHeight);
  if (current.dmDisplayFrequency > 1 && current.dmDisplayFrequency < 1000) {
    snapshot.current_refresh_rate =
        static_cast<double>(current.dmDisplayFrequency);
  }

  std::set<DWORD> rates;
  DEVMODEW mode{};
  for (DWORD mode_index = 0;; ++mode_index) {
    mode = {};
    mode.dmSize = sizeof(mode);
    if (!EnumDisplaySettingsExW(monitor_info.szDevice, mode_index, &mode,
                                0)) {
      break;
    }
    if (mode.dmPelsWidth != current.dmPelsWidth ||
        mode.dmPelsHeight != current.dmPelsHeight ||
        (mode.dmDisplayFlags & DM_INTERLACED) != 0 ||
        mode.dmDisplayFrequency <= 1 || mode.dmDisplayFrequency >= 1000) {
      continue;
    }
    rates.insert(mode.dmDisplayFrequency);
  }
  if (snapshot.current_refresh_rate > 0) {
    rates.insert(static_cast<DWORD>(std::lround(snapshot.current_refresh_rate)));
  }
  for (const DWORD rate : rates) {
    snapshot.supported_refresh_rates.push_back(static_cast<double>(rate));
  }
  snapshot.max_refresh_rate = snapshot.supported_refresh_rates.empty()
                                  ? snapshot.current_refresh_rate
                                  : snapshot.supported_refresh_rates.back();
  return snapshot;
}

flutter::EncodableValue FlutterWindow::EncodeDisplayMode(
    const DisplayModeSnapshot& snapshot) const {
  flutter::EncodableList rates;
  rates.reserve(snapshot.supported_refresh_rates.size());
  for (const double rate : snapshot.supported_refresh_rates) {
    rates.emplace_back(rate);
  }

  flutter::EncodableMap map;
  map[flutter::EncodableValue("enabled")] = flutter::EncodableValue(true);
  map[flutter::EncodableValue("currentRefreshRate")] =
      flutter::EncodableValue(snapshot.current_refresh_rate);
  map[flutter::EncodableValue("maxRefreshRate")] =
      flutter::EncodableValue(snapshot.max_refresh_rate);
  map[flutter::EncodableValue("preferredRefreshRate")] =
      flutter::EncodableValue(snapshot.current_refresh_rate);
  map[flutter::EncodableValue("requestedRefreshRate")] =
      flutter::EncodableValue(snapshot.current_refresh_rate);
  map[flutter::EncodableValue("supportedRefreshRates")] =
      flutter::EncodableValue(std::move(rates));
  map[flutter::EncodableValue("width")] =
      flutter::EncodableValue(snapshot.width);
  map[flutter::EncodableValue("height")] =
      flutter::EncodableValue(snapshot.height);
  return flutter::EncodableValue(std::move(map));
}

void FlutterWindow::NotifyDisplayModeChanged(bool force) {
  if (!display_mode_channel_) {
    return;
  }

  // WM_MOVE can be emitted many times per second while dragging a window.
  // Check the inexpensive monitor identity first and enumerate display modes
  // only after the window really crosses to another monitor. Display-mode
  // changes arrive through WM_DISPLAYCHANGE with force=true.
  if (!force && !last_display_device_.empty()) {
    const HWND window = GetHandle();
    const HMONITOR monitor =
        MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
    MONITORINFOEXW monitor_info{};
    monitor_info.cbSize = sizeof(monitor_info);
    if (GetMonitorInfoW(monitor, &monitor_info) &&
        last_display_device_ == monitor_info.szDevice) {
      return;
    }
  }

  const DisplayModeSnapshot snapshot = ReadDisplayMode();
  const bool changed =
      snapshot.device_name != last_display_device_ ||
      snapshot.width != last_display_width_ ||
      snapshot.height != last_display_height_ ||
      std::abs(snapshot.current_refresh_rate - last_display_refresh_rate_) >
          0.1;
  if (!force && !changed) {
    return;
  }
  RememberDisplayMode(snapshot);
  display_mode_channel_->InvokeMethod(
      "displayModeChanged",
      std::make_unique<flutter::EncodableValue>(EncodeDisplayMode(snapshot)));
}

void FlutterWindow::RememberDisplayMode(
    const DisplayModeSnapshot& snapshot) {
  last_display_device_ = snapshot.device_name;
  last_display_width_ = snapshot.width;
  last_display_height_ = snapshot.height;
  last_display_refresh_rate_ = snapshot.current_refresh_rate;
}
