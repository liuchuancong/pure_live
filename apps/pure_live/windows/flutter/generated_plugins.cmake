#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  audio_service_win
  battery_plus
  connectivity_plus
  desktop_drop
  device_screen_brightness
  dynamic_color
  ffmpeg_kit_extended_flutter
  file_selector_windows
  flutter_acrylic
  flutter_secure_storage_windows
  media_core_audio
  media_core_native
  media_kit_video
  multiview_desktop
  refresh_rate
  restart_app
  share_plus
  system_theme
  url_launcher_windows
  volume_controller
  webview_all_windows
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
  fjs
  flutter_local_notifications_windows
  jni
)

set(PLUGIN_BUNDLED_LIBRARIES)

foreach(plugin ${FLUTTER_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${plugin}/windows plugins/${plugin})
  target_link_libraries(${BINARY_NAME} PRIVATE ${plugin}_plugin)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES $<TARGET_FILE:${plugin}_plugin>)
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${plugin}_bundled_libraries})
endforeach(plugin)

foreach(ffi_plugin ${FLUTTER_FFI_PLUGIN_LIST})
  add_subdirectory(flutter/ephemeral/.plugin_symlinks/${ffi_plugin}/windows plugins/${ffi_plugin})
  list(APPEND PLUGIN_BUNDLED_LIBRARIES ${${ffi_plugin}_bundled_libraries})
endforeach(ffi_plugin)
