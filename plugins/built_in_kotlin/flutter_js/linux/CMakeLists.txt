cmake_minimum_required(VERSION 3.10)


set(PROJECT_NAME "flutter_js")
project(${PROJECT_NAME} LANGUAGES CXX C)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

set(CMAKE_C_COMPILER "gcc")
set(CMAKE_CXX_COMPILER "g++")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -DANDROID_STL=c++_static -DDEBUGGER_SERVER_PORT=${DEBUGGER_SERVER_PORT}")

add_library(${PLUGIN_NAME} SHARED
  "flutter_js_plugin.cc"
)

apply_standard_settings(${PLUGIN_NAME})
target_compile_features(${PLUGIN_NAME} PUBLIC cxx_std_17)
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

# List of absolute paths to libraries that should be bundled with the plugin
set(flutter_qjs_bundled_libraries
  "$<TARGET_FILE:libquickjs_c_bridge_plugin.so>"
  PARENT_SCOPE
)

set(BUILD_BUNDLE_DIR "${PROJECT_BINARY_DIR}/bundle")
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
    set(CMAKE_INSTALL_PREFIX "${BUILD_BUNDLE_DIR}" CACHE PATH "..." FORCE)
endif()
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}/lib")

set(QUICKJSC_BRIDGE "libquickjs_c_bridge_plugin.so")
set(QUICKJSC_BRIDGE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/shared/${QUICKJSC_BRIDGE}")
install(CODE "file(REMOVE_RECURSE \"${INSTALL_BUNDLE_LIB_DIR}/${QUICKJSC_BRIDGE}\")" COMPONENT Runtime)
install(FILES "${QUICKJSC_BRIDGE_PATH}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}" COMPONENT Runtime)
