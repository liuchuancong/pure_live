#include "include/screen_retriever_windows/screen_retriever_windows_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "screen_retriever_windows_plugin.h"

void ScreenRetrieverWindowsPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  screen_retriever_windows::ScreenRetrieverWindowsPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
