#include "screen_retriever_windows_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <codecvt>
#include <map>
#include <memory>
#include <sstream>

const double kBaseDpi = 96.0;

namespace screen_retriever_windows {
std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

// static
void ScreenRetrieverWindowsPlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "dev.leanflutter.plugins/screen_retriever",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<ScreenRetrieverWindowsPlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  auto event_channel =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(),
          "dev.leanflutter.plugins/screen_retriever_event",
          &flutter::StandardMethodCodec::GetInstance());
  auto streamHandler = std::make_unique<flutter::StreamHandlerFunctions<>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnListen(arguments, std::move(events));
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<>> {
        return plugin_pointer->OnCancel(arguments);
      });
  event_channel->SetStreamHandler(std::move(streamHandler));

  registrar->AddPlugin(std::move(plugin));
}

ScreenRetrieverWindowsPlugin::ScreenRetrieverWindowsPlugin(
    flutter::PluginRegistrarWindows* registrar) {
  registrar_ = registrar;
  display_count_ = GetMonitorCount();
  window_proc_id_ = registrar->RegisterTopLevelWindowProcDelegate(
      [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
        return HandleWindowProc(hwnd, message, wparam, lparam);
      });
}
ScreenRetrieverWindowsPlugin::~ScreenRetrieverWindowsPlugin() {}

int ScreenRetrieverWindowsPlugin::GetMonitorCount() {
  int monitorCount = 0;
  EnumDisplayMonitors(
      NULL, NULL,
      [](HMONITOR, HDC, LPRECT, LPARAM lParam) -> BOOL {
        int* count = (int*)lParam;
        (*count)++;
        return TRUE;
      },
      (LPARAM)&monitorCount);
  return monitorCount;
}

std::optional<LRESULT> ScreenRetrieverWindowsPlugin::HandleWindowProc(
    HWND hwnd,
    UINT message,
    WPARAM wparam,
    LPARAM lparam) {
  switch (message) {
    case WM_DISPLAYCHANGE: {
      int currentMonitorCount = GetMonitorCount();
      flutter::EncodableMap args = flutter::EncodableMap();
      if (currentMonitorCount > display_count_) {
        args[flutter::EncodableValue("type")] = "display-added";
      } else if (currentMonitorCount < display_count_) {
        args[flutter::EncodableValue("type")] = "display-removed";
      }
      display_count_ = currentMonitorCount;
      if (event_sink_) {
        event_sink_->Success(flutter::EncodableValue(args));
      }
      break;
    }
  }
  return std::nullopt;
}

flutter::EncodableMap MonitorToEncodableMap(HMONITOR monitor) {
  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;

  MONITORINFOEX info;
  info.cbSize = sizeof(MONITORINFOEX);
  ::GetMonitorInfo(monitor, &info);
  UINT dpi = FlutterDesktopGetDpiForMonitor(monitor);

  wchar_t display_name[sizeof(info.szDevice) / sizeof(*info.szDevice) + 1];
  memset(display_name, 0, sizeof(display_name));
  memcpy(display_name, info.szDevice, sizeof(info.szDevice));

  double scale_factor = dpi / kBaseDpi;

  double visibleWidth =
      round((info.rcWork.right - info.rcWork.left) / scale_factor);
  double visibleHeight =
      round((info.rcWork.bottom - info.rcWork.top) / scale_factor);

  double visibleX = round((info.rcWork.left) / scale_factor);
  double visibleY = round((info.rcWork.top) / scale_factor);

  flutter::EncodableMap size = flutter::EncodableMap();
  flutter::EncodableMap visibleSize = flutter::EncodableMap();
  flutter::EncodableMap visiblePosition = flutter::EncodableMap();

  size[flutter::EncodableValue("width")] =
      flutter::EncodableValue(static_cast<double>(
          round(info.rcMonitor.right / scale_factor - visibleX)));
  size[flutter::EncodableValue("height")] =
      flutter::EncodableValue(static_cast<double>(
          round(info.rcMonitor.bottom / scale_factor - visibleY)));

  visibleSize[flutter::EncodableValue("width")] =
      flutter::EncodableValue(visibleWidth);
  visibleSize[flutter::EncodableValue("height")] =
      flutter::EncodableValue(visibleHeight);

  visiblePosition[flutter::EncodableValue("dx")] =
      flutter::EncodableValue(visibleX);
  visiblePosition[flutter::EncodableValue("dy")] =
      flutter::EncodableValue(visibleY);

  flutter::EncodableMap display = flutter::EncodableMap();

  display[flutter::EncodableValue("id")] = flutter::EncodableValue("");
  DISPLAY_DEVICE displayDevice;
  displayDevice.cb = sizeof(DISPLAY_DEVICE);
  int deviceIndex = 0;
  while (EnumDisplayDevices(info.szDevice, deviceIndex, &displayDevice, 0)) {
    if (displayDevice.StateFlags & DISPLAY_DEVICE_ACTIVE &&
        (displayDevice.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP)) {
      std::wstring deviceName(displayDevice.DeviceName);
      if (deviceName.find(info.szDevice) == 0) {
        display[flutter::EncodableValue("id")] = flutter::EncodableValue(
            converter.to_bytes(displayDevice.DeviceID).c_str());
      }
    }
    deviceIndex++;
  }

  display[flutter::EncodableValue("name")] =
      flutter::EncodableValue(converter.to_bytes(display_name).c_str());
  display[flutter::EncodableValue("size")] = flutter::EncodableValue(size);
  display[flutter::EncodableValue("visibleSize")] =
      flutter::EncodableValue(visibleSize);
  display[flutter::EncodableValue("visiblePosition")] =
      flutter::EncodableValue(visiblePosition);
  display[flutter::EncodableValue("scaleFactor")] =
      flutter::EncodableValue(scale_factor);

  return display;
}

BOOL CALLBACK MonitorRepresentationEnumProc(HMONITOR monitor,
                                            HDC hdc,
                                            LPRECT clip,
                                            LPARAM list_ref) {
  flutter::EncodableValue* monitors =
      reinterpret_cast<flutter::EncodableValue*>(list_ref);
  flutter::EncodableMap display = MonitorToEncodableMap(monitor);
  std::get<flutter::EncodableList>(*monitors).push_back(
      flutter::EncodableValue(display));
  return TRUE;
}

void ScreenRetrieverWindowsPlugin::GetCursorScreenPoint(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const flutter::EncodableMap& args =
      std::get<flutter::EncodableMap>(*method_call.arguments());

  double device_pixel_ratio =
      std::get<double>(args.at(flutter::EncodableValue("devicePixelRatio")));

  double x, y;
  POINT cursorPos;
  GetCursorPos(&cursorPos);
  x = cursorPos.x / device_pixel_ratio * 1.0f;
  y = cursorPos.y / device_pixel_ratio * 1.0f;

  flutter::EncodableMap result_data = flutter::EncodableMap();
  result_data[flutter::EncodableValue("dx")] = flutter::EncodableValue(x);
  result_data[flutter::EncodableValue("dy")] = flutter::EncodableValue(y);

  result->Success(flutter::EncodableValue(result_data));
}

void ScreenRetrieverWindowsPlugin::GetPrimaryDisplay(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  POINT ptZero = {0, 0};
  HMONITOR monitor = MonitorFromPoint(ptZero, MONITOR_DEFAULTTOPRIMARY);
  flutter::EncodableMap display = MonitorToEncodableMap(monitor);
  result->Success(flutter::EncodableValue(display));
}

void ScreenRetrieverWindowsPlugin::GetAllDisplays(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  flutter::EncodableValue displays(std::in_place_type<flutter::EncodableList>);

  ::EnumDisplayMonitors(nullptr, nullptr, MonitorRepresentationEnumProc,
                        reinterpret_cast<LPARAM>(&displays));

  flutter::EncodableMap result_data = flutter::EncodableMap();
  result_data[flutter::EncodableValue("displays")] = displays;

  result->Success(flutter::EncodableValue(result_data));
}

void ScreenRetrieverWindowsPlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getCursorScreenPoint") == 0) {
    GetCursorScreenPoint(method_call, std::move(result));
  } else if (method_call.method_name().compare("getPrimaryDisplay") == 0) {
    GetPrimaryDisplay(method_call, std::move(result));
  } else if (method_call.method_name().compare("getAllDisplays") == 0) {
    GetAllDisplays(method_call, std::move(result));
  } else {
    result->NotImplemented();
  }
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ScreenRetrieverWindowsPlugin::OnListenInternal(
    const flutter::EncodableValue* arguments,
    std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events) {
  event_sink_ = std::move(events);
  return nullptr;
}

std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>>
ScreenRetrieverWindowsPlugin ::OnCancelInternal(
    const flutter::EncodableValue* arguments) {
  event_sink_ = nullptr;
  return nullptr;
}

}  // namespace screen_retriever_windows
