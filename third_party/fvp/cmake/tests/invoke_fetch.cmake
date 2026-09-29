cmake_minimum_required(VERSION 3.15)

foreach(REQUIRED_VARIABLE DEPS_FILE SDK_URL SDK_ARCHIVE EXTRACT_ROOT EXPECTED_SHA256)
  if(NOT DEFINED ${REQUIRED_VARIABLE})
    message(FATAL_ERROR "${REQUIRED_VARIABLE} is required")
  endif()
endforeach()

include("${DEPS_FILE}")
_fvp_prepare_mdk_sdk(
  "${SDK_URL}"
  "${SDK_ARCHIVE}"
  "${EXTRACT_ROOT}"
  "${EXPECTED_SHA256}"
  OFF
)
