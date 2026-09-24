#include "flutter_window.h"

#include <algorithm>
#include <cmath>
#include <optional>
#include <set>
#include <thread>

#include <flutter/standard_method_codec.h>
#include "flutter/generated_plugin_registrant.h"

namespace {

constexpr UINT kNativeHttpDoneMessage = WM_APP + 0x3A1;

std::string StringArgument(const flutter::EncodableMap& args, const char* key) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return std::string();
  if (const auto* value = std::get_if<std::string>(&it->second)) return *value;
  return std::string();
}

int IntArgument(const flutter::EncodableMap& args, const char* key,
                int fallback) {
  const auto it = args.find(flutter::EncodableValue(key));
  if (it == args.end()) return fallback;
  if (const auto* value = std::get_if<int32_t>(&it->second)) return *value;
  if (const auto* value = std::get_if<int64_t>(&it->second)) {
    return static_cast<int>(*value);
  }
  return fallback;
}

}  // namespace

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

  native_http_channel_ =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          flutter_controller_->engine()->messenger(), "pure_live/native_http",
          &flutter::StandardMethodCodec::GetInstance());
  native_http_channel_->SetMethodCallHandler(
      [this](const auto& call, auto result) {
        HandleNativeHttpCall(call, std::move(result));
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
  native_http_channel_.reset();
  native_http_pending_.clear();
  flutter_controller_.reset();

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  if (message == kNativeHttpDoneMessage) {
    DrainNativeHttpCompletions();
    return 0;
  }
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

void FlutterWindow::HandleNativeHttpCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  // Cloudflare rejects dart:io's TLS fingerprint on kick.com (403); the
  // Windows Schannel stack used by WinHTTP is accepted.
  if (call.method_name() != "getKickJson") {
    result->NotImplemented();
    return;
  }
  const auto* args = std::get_if<flutter::EncodableMap>(call.arguments());
  if (!args) {
    result->Error("native_http_failed", "Missing arguments");
    return;
  }
  const std::string url = StringArgument(*args, "url");
  if (!NativeHttpIsAllowedKickUrl(url)) {
    result->Error("native_http_failed", "Native HTTP host is not allowed");
    return;
  }
  std::vector<std::pair<std::string, std::string>> headers;
  const auto header_it = args->find(flutter::EncodableValue("headers"));
  if (header_it != args->end()) {
    if (const auto* map = std::get_if<flutter::EncodableMap>(&header_it->second)) {
      for (const auto& [name, value] : *map) {
        const auto* name_text = std::get_if<std::string>(&name);
        const auto* value_text = std::get_if<std::string>(&value);
        if (name_text && value_text) headers.emplace_back(*name_text, *value_text);
      }
    }
  }
  std::string proxy;
  const std::string proxy_host = StringArgument(*args, "proxyHost");
  const int proxy_port = IntArgument(*args, "proxyPort", 0);
  if (!proxy_host.empty() && proxy_port > 0 && proxy_port <= 65535) {
    proxy = proxy_host + ":" + std::to_string(proxy_port);
  }
  const int timeout_ms =
      std::clamp(IntArgument(*args, "timeoutMillis", 20000), 1000, 60000);

  const int id = native_http_next_id_++;
  native_http_pending_[id] = std::move(result);
  const HWND window = GetHandle();
  std::shared_ptr<NativeHttpQueue> queue = native_http_queue_;
  std::thread([=]() {
    NativeHttpResponse response = NativeHttpGet(url, headers, proxy, timeout_ms);
    {
      std::lock_guard<std::mutex> lock(queue->mutex);
      queue->done.emplace_back(id, std::move(response));
    }
    PostMessage(window, kNativeHttpDoneMessage, 0, 0);
  }).detach();
}

void FlutterWindow::DrainNativeHttpCompletions() {
  std::deque<std::pair<int, NativeHttpResponse>> done;
  {
    std::lock_guard<std::mutex> lock(native_http_queue_->mutex);
    done.swap(native_http_queue_->done);
  }
  for (auto& [id, response] : done) {
    auto it = native_http_pending_.find(id);
    if (it == native_http_pending_.end()) continue;
    auto result = std::move(it->second);
    native_http_pending_.erase(it);
    if (!response.error.empty()) {
      result->Error("native_http_failed", response.error);
      continue;
    }
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("statusCode"),
         flutter::EncodableValue(response.status)},
        {flutter::EncodableValue("body"),
         flutter::EncodableValue(std::move(response.body))},
    }));
  }
}
