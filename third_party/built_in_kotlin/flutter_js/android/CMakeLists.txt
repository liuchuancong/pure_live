cmake_minimum_required(VERSION 3.6.0)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -DANDROID_STL=c++_static -DANDROID_TOOLCHAIN=clang -DDEBUGGER_SERVER_PORT=${DEBUGGER_SERVER_PORT}")
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DQUICKJS")
include_directories(
    src/main/c/quickjs
)
add_library( fastdev_quickjs_runtime

             # Sets the library as a shared library.
             SHARED

             # Provides a relative path to your source file(s).
             src/main/c/libfastdev_quickjs_runtime.cpp

            src/main/c/quickjs/cutils.c
            src/main/c/quickjs/libregexp.c
            src/main/c/quickjs/libunicode.c
            src/main/c/quickjs/quickjs.c
    )

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -DCONFIG_VERSION=\\\"2020-11-08\\\"")

find_library(log-lib log)
target_link_libraries(fastdev_quickjs_runtime ${log-lib})