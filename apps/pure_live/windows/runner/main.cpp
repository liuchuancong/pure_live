#include <flutter/dart_project.h>
#include "flutter_window.h"
#include <windows.h>
#include <shobjidl_core.h>
#include <optional>
#include <flutter/flutter_engine.h>
#include <app_links/app_links_plugin_c_api.h>
#include <multiview_desktop/multi_view_desktop_plugin.h>
#include <flutter/generated_plugin_registrant.h>
#include "win32_window.h"
#include "utils.h"

namespace {

// Registers the lxmusic:// protocol under HKCU so the OS hands links to this
// exe. Per-user keys, no installer, no elevation — the portable build stays
// portable; a packaged (msix) build registers through its manifest instead
// and this write is simply redundant. Refreshed on every start, so a moved
// or updated exe re-points the launch command by itself.
void RegisterMusicProtocol() {
  const wchar_t* scheme = L"Software\\Classes\\lxmusic";
  const wchar_t* command = L"Software\\Classes\\lxmusic\\shell\\open\\command";

  HKEY key = nullptr;
  if (::RegCreateKeyExW(HKEY_CURRENT_USER, scheme, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr,
                        &key, nullptr) == ERROR_SUCCESS) {
    ::RegSetValueExW(key, L"URL Protocol", 0, REG_SZ,
                     reinterpret_cast<const BYTE*>(L""), sizeof(wchar_t));
    ::RegSetValueExW(key, L"", 0, REG_SZ,
                     reinterpret_cast<const BYTE*>(L"Pure Live"),
                     static_cast<DWORD>((wcslen(L"Pure Live") + 1) *
                                        sizeof(wchar_t)));
    ::RegCloseKey(key);
  }

  if (::RegCreateKeyExW(HKEY_CURRENT_USER, command, 0, nullptr,
                        REG_OPTION_NON_VOLATILE, KEY_SET_VALUE, nullptr,
                        &key, nullptr) == ERROR_SUCCESS) {
    wchar_t path[MAX_PATH];
    wchar_t quoted[MAX_PATH + 4];
    if (::GetModuleFileNameW(nullptr, path, MAX_PATH) != 0) {
      ::swprintf_s(quoted, L"\"%s\" \"%%1\"", path);
      ::RegSetValueExW(key, L"", 0, REG_SZ,
                       reinterpret_cast<const BYTE*>(quoted),
                       static_cast<DWORD>((wcslen(quoted) + 1) *
                                          sizeof(wchar_t)));
    }
    ::RegCloseKey(key);
  }
}

}  // namespace

int APIENTRY wWinMain(_In_ HINSTANCE instance, _In_opt_ HINSTANCE prev,
                      _In_ wchar_t* command_line, _In_ int show_command) {
  if (!::AttachConsole(ATTACH_PARENT_PROCESS) && ::IsDebuggerPresent()) {
    CreateAndAttachConsole();
  }

  ::CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  // A second launch carrying a link hands it to the running instance and
  // exits; the engine below then sees it on the app_links stream.
  if (SendAppLinkToInstance()) {
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  RegisterMusicProtocol();

  // A stable process identity before anything user-facing asks for one: the
  // taskbar grouping, the SMTC card and toast activation all attribute by the
  // AppUserModelID, and an unpackaged exe without one shows an unstable source.
  SetCurrentProcessExplicitAppUserModelID(L"com.liuchuancong.pure_live");

  MultiViewDesktopInitializeShellIntegration();

  if (MultiViewDesktopTryForwardTaskbarMenuActivation()) {
    ::CoUninitialize();
    return EXIT_SUCCESS;
  }

  flutter::DartProject project(L"data");
  std::vector<std::string> command_line_arguments = GetCommandLineArguments();
  project.set_dart_entrypoint_arguments(std::move(command_line_arguments));

  FlutterWindow window(project);
  Win32Window::Point origin(0, 0);
  Win32Window::Size size(800, 600);
  if (!window.Create(L"Pure Live", origin, size)) {
    return EXIT_FAILURE;
  }
  window.SetQuitOnClose(false);

  ::MSG msg;
  while (::GetMessage(&msg, nullptr, 0, 0)) {
    ::TranslateMessage(&msg);
    ::DispatchMessage(&msg);
  }

  ::CoUninitialize();
  return EXIT_SUCCESS;
}
