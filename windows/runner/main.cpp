#include <flutter/dart_project.h>
#include <flutter/flutter_view_controller.h>
#include <windows.h>
#include "flutter_window.h"
#include "utils.h"
#include <shobjidl.h>

namespace {

constexpr wchar_t kPrimaryInstanceMutex[] =
    L"Local\\PureLive_Primary_Instance_v1";

bool HasExplicitInstanceArgument(
    const std::vector<std::string>& arguments) {
  for (const auto& argument : arguments) {
    if (argument.rfind("--instance=", 0) == 0) {
      return true;
    }
  }
  return false;
}

void BringPrimaryWindowToFront() {
  const HWND window =
      ::FindWindowW(L"FLUTTER_RUNNER_WIN32_WINDOW", L"pure_live");
  if (window == nullptr) {
    return;
  }
  if (::IsIconic(window)) {
    ::ShowWindowAsync(window, SW_RESTORE);
  } else {
    ::ShowWindowAsync(window, SW_SHOW);
  }
  ::SetWindowPos(window, HWND_TOP, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
  ::SetForegroundWindow(window);
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t *command_line, _In_ int show_command) {
  std::vector<std::string> command_line_arguments =
      GetCommandLineArguments();

  // Reject a duplicate primary process before allocating a Flutter engine,
  // GPU surface, Dart isolate or plugins. The Dart single-instance channel is
  // retained for argument forwarding; this early fence prevents the brief
  // decoder/UI stall observed when users launch the installed shortcut twice.
  HANDLE primary_instance_mutex = nullptr;
  if (!HasExplicitInstanceArgument(command_line_arguments)) {
    primary_instance_mutex =
        ::CreateMutexW(nullptr, TRUE, kPrimaryInstanceMutex);
    if (primary_instance_mutex != nullptr &&
        ::GetLastError() == ERROR_ALREADY_EXISTS) {
      BringPrimaryWindowToFront();
      ::CloseHandle(primary_instance_mutex);
      return EXIT_SUCCESS;
    }
  }

  // Attach to console when present (e.g., 'flutter run') or create a
  // new console when running with a debugger.
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  // Initialize COM, so that it is available for use in the library and/or
  // plugins.
  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  {
    flutter::DartProject project(L"data");

    project.set_dart_entrypoint_arguments(std::move(command_line_arguments));
    SetCurrentProcessExplicitAppUserModelID(L"com.mystyle.purelive");
    FlutterWindow window(project);
    Win32Window::Point origin(10, 10);
    Win32Window::Size size(1280, 720);
    if (!window.Create(L"pure_live", origin, size)) {
      return EXIT_FAILURE;
    }
    window.SetQuitOnClose(true);

    ::MSG msg;
    while (::GetMessage(&msg, nullptr, 0, 0)) {
      ::TranslateMessage(&msg);
      ::DispatchMessage(&msg);
    }
  }

  ::CoUninitialize();
  // Flutter and plugin objects are already destroyed above. Bypass process
  // detach hooks in optional DLLs that can otherwise keep the process alive.
  ::TerminateProcess(::GetCurrentProcess(), EXIT_SUCCESS);
  return EXIT_SUCCESS;
}
