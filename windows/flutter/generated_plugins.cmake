#
# Generated file, do not edit.
#

list(APPEND FLUTTER_PLUGIN_LIST
  app_links
  audio_service_win
  battery_plus
  charset_converter
  cloud_firestore
  connectivity_plus
  dynamic_color
  ffmpeg_kit_extended_flutter
  firebase_auth
  firebase_core
  flutter_acrylic
  flutter_inappwebview_windows
  flutter_js
  fullscreen_window
  fvp
  media_kit_libs_windows_video
  media_kit_video
  permission_handler_windows
  screen_brightness_windows
  screen_retriever_windows
  share_plus
  tray_manager
  url_launcher_windows
  volume_controller
  window_manager
)

list(APPEND FLUTTER_FFI_PLUGIN_LIST
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
