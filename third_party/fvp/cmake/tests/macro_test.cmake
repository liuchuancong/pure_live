cmake_minimum_required(VERSION 3.15)

if(NOT DEFINED DEPS_FILE)
  message(FATAL_ERROR "DEPS_FILE is required")
endif()

set(CMAKE_SYSTEM_NAME "Linux")
set(CMAKE_SYSTEM_PROCESSOR "x86_64")
include("${DEPS_FILE}")

# The dependency integration test runs outside the plugin source tree. Avoid
# generating version.h; fvp_version() is independent from dependency setup.
function(fvp_version)
endfunction()

fvp_setup_deps()

if(NOT FVP_TEST_FIND_MDK)
  message(FATAL_ERROR "fvp_setup_deps() did not include FindMDK.cmake")
endif()
