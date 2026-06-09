#ifndef FLUTTER_PLUGIN_SCREEN_RETRIEVER_WINDOWS_PLUGIN_H_
#define FLUTTER_PLUGIN_SCREEN_RETRIEVER_WINDOWS_PLUGIN_H_

#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace screen_retriever_windows {

class ScreenRetrieverWindowsPlugin
    : public flutter::Plugin,
      flutter::StreamHandler<flutter::EncodableValue> {
 private:
  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> event_sink_;

  int32_t display_count_ = 0;
  int32_t window_proc_id_ = -1;
  int GetMonitorCount();
  std::optional<LRESULT> HandleWindowProc(HWND hwnd,
                                          UINT message,
                                          WPARAM wparam,
                                          LPARAM lparam);

 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows* registrar);

  ScreenRetrieverWindowsPlugin(flutter::PluginRegistrarWindows* registrar);

  virtual ~ScreenRetrieverWindowsPlugin();

  // Disallow copy and assign.
  ScreenRetrieverWindowsPlugin(const ScreenRetrieverWindowsPlugin&) = delete;
  ScreenRetrieverWindowsPlugin& operator=(const ScreenRetrieverWindowsPlugin&) =
      delete;

  void ScreenRetrieverWindowsPlugin::GetCursorScreenPoint(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ScreenRetrieverWindowsPlugin::GetPrimaryDisplay(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void ScreenRetrieverWindowsPlugin::GetAllDisplays(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  std::unique_ptr<flutter::StreamHandlerError<>> OnListenInternal(
      const flutter::EncodableValue* arguments,
      std::unique_ptr<flutter::EventSink<>>&& events) override;

  std::unique_ptr<flutter::StreamHandlerError<>> OnCancelInternal(
      const flutter::EncodableValue* arguments) override;
};

}  // namespace screen_retriever_windows

#endif  // FLUTTER_PLUGIN_SCREEN_RETRIEVER_WINDOWS_PLUGIN_H_
