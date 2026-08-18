#ifndef RUNNER_FLUTTER_WINDOW_H_
#define RUNNER_FLUTTER_WINDOW_H_

#include <flutter/dart_project.h>
#include <flutter/encodable_value.h>
#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <memory>
#include <string>
#include <vector>

#include "win32_window.h"

// A window that does nothing but host a Flutter view.
class FlutterWindow : public Win32Window {
 public:
  // Creates a new FlutterWindow hosting a Flutter view running |project|.
  explicit FlutterWindow(const flutter::DartProject& project);
  virtual ~FlutterWindow();

 protected:
  // Win32Window:
  bool OnCreate() override;
  void OnDestroy() override;
  LRESULT MessageHandler(HWND window, UINT const message, WPARAM const wparam,
                         LPARAM const lparam) noexcept override;

 private:
  struct DisplayModeSnapshot {
    std::wstring device_name;
    int width = 0;
    int height = 0;
    double current_refresh_rate = 0;
    double max_refresh_rate = 0;
    std::vector<double> supported_refresh_rates;
  };

  DisplayModeSnapshot ReadDisplayMode() const;
  flutter::EncodableValue EncodeDisplayMode(
      const DisplayModeSnapshot& snapshot) const;
  void RememberDisplayMode(const DisplayModeSnapshot& snapshot);
  void NotifyDisplayModeChanged(bool force = false);

  // The project to run.
  flutter::DartProject project_;

  // The Flutter instance hosted by this window.
  std::unique_ptr<flutter::FlutterViewController> flutter_controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>>
      display_mode_channel_;
  std::wstring last_display_device_;
  int last_display_width_ = 0;
  int last_display_height_ = 0;
  double last_display_refresh_rate_ = 0;
};

#endif  // RUNNER_FLUTTER_WINDOW_H_
