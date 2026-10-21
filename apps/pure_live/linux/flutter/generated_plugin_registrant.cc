//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <desktop_multi_window/desktop_multi_window_plugin.h>
#include <device_screen_brightness/device_screen_brightness_plugin.h>
#include <dynamic_color/dynamic_color_plugin.h>
#include <ffmpeg_kit_extended_flutter/ffmpeg_kit_extended_flutter_plugin.h>
#include <file_selector_linux/file_selector_plugin.h>
#include <flutter_acrylic/flutter_acrylic_plugin.h>
#include <flutter_secure_storage_linux/flutter_secure_storage_linux_plugin.h>
#include <gtk/gtk_plugin.h>
#include <media_core_audio/media_core_audio_plugin.h>
#include <media_core_native/media_core_native_plugin.h>
#include <media_kit_video/media_kit_video_plugin.h>
#include <open_file_linux/open_file_linux_plugin.h>
#include <refresh_rate/refresh_rate_plugin.h>
#include <restart_app/restart_app_plugin.h>
#include <url_launcher_linux/url_launcher_plugin.h>
#include <volume_controller/volume_controller_plugin.h>
#include <window_frame_kit/window_frame_kit_plugin.h>
#include <yaru_window_linux/yaru_window_linux_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) desktop_multi_window_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DesktopMultiWindowPlugin");
  desktop_multi_window_plugin_register_with_registrar(desktop_multi_window_registrar);
  g_autoptr(FlPluginRegistrar) device_screen_brightness_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DeviceScreenBrightnessPlugin");
  device_screen_brightness_plugin_register_with_registrar(device_screen_brightness_registrar);
  g_autoptr(FlPluginRegistrar) dynamic_color_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "DynamicColorPlugin");
  dynamic_color_plugin_register_with_registrar(dynamic_color_registrar);
  g_autoptr(FlPluginRegistrar) ffmpeg_kit_extended_flutter_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FfmpegKitExtendedFlutterPlugin");
  ffmpeg_kit_extended_flutter_plugin_register_with_registrar(ffmpeg_kit_extended_flutter_registrar);
  g_autoptr(FlPluginRegistrar) file_selector_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FileSelectorPlugin");
  file_selector_plugin_register_with_registrar(file_selector_linux_registrar);
  g_autoptr(FlPluginRegistrar) flutter_acrylic_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterAcrylicPlugin");
  flutter_acrylic_plugin_register_with_registrar(flutter_acrylic_registrar);
  g_autoptr(FlPluginRegistrar) flutter_secure_storage_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "FlutterSecureStorageLinuxPlugin");
  flutter_secure_storage_linux_plugin_register_with_registrar(flutter_secure_storage_linux_registrar);
  g_autoptr(FlPluginRegistrar) gtk_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "GtkPlugin");
  gtk_plugin_register_with_registrar(gtk_registrar);
  g_autoptr(FlPluginRegistrar) media_core_audio_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MediaCoreAudioPlugin");
  media_core_audio_plugin_register_with_registrar(media_core_audio_registrar);
  g_autoptr(FlPluginRegistrar) media_core_native_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MediaCoreNativePlugin");
  media_core_native_plugin_register_with_registrar(media_core_native_registrar);
  g_autoptr(FlPluginRegistrar) media_kit_video_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "MediaKitVideoPlugin");
  media_kit_video_plugin_register_with_registrar(media_kit_video_registrar);
  g_autoptr(FlPluginRegistrar) open_file_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "OpenFileLinuxPlugin");
  open_file_linux_plugin_register_with_registrar(open_file_linux_registrar);
  g_autoptr(FlPluginRegistrar) refresh_rate_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "RefreshRatePlugin");
  refresh_rate_plugin_register_with_registrar(refresh_rate_registrar);
  g_autoptr(FlPluginRegistrar) restart_app_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "RestartAppPlugin");
  restart_app_plugin_register_with_registrar(restart_app_registrar);
  g_autoptr(FlPluginRegistrar) url_launcher_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "UrlLauncherPlugin");
  url_launcher_plugin_register_with_registrar(url_launcher_linux_registrar);
  g_autoptr(FlPluginRegistrar) volume_controller_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "VolumeControllerPlugin");
  volume_controller_plugin_register_with_registrar(volume_controller_registrar);
  g_autoptr(FlPluginRegistrar) window_frame_kit_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "WindowFrameKitPlugin");
  window_frame_kit_plugin_register_with_registrar(window_frame_kit_registrar);
  g_autoptr(FlPluginRegistrar) yaru_window_linux_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "YaruWindowLinuxPlugin");
  yaru_window_linux_plugin_register_with_registrar(yaru_window_linux_registrar);
}
