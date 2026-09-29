if(NOT DEFINED FVP_DEPS_URL)
  set(FVP_DEPS_URL "" CACHE STRING "Base URL of MDK SDK archives")
endif()
if(NOT DEFINED FVP_DEPS_SHA256)
  set(FVP_DEPS_SHA256 "" CACHE STRING "Expected SHA-256 of the MDK SDK archive")
endif()


function(fvp_version)
  if(NOT DEFINED CMAKE_CURRENT_FUNCTION_LIST_DIR)
    message(WARNING "CMAKE_CURRENT_FUNCTION_LIST_DIR not defined")
    set(CMAKE_CURRENT_FUNCTION_LIST_DIR ${CMAKE_CURRENT_LIST_DIR})
  endif()
  set(PUBSPEC_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../pubspec.yaml")
  if(NOT EXISTS ${PUBSPEC_FILE})
    message(FATAL_ERROR "pubspec.yaml not found: ${PUBSPEC_FILE}")
  endif()
  file(READ ${PUBSPEC_FILE} PUBSPEC_CONTENTS)
  string(REGEX MATCH "version:[ \t]*([0-9]+\\.[0-9]+\\.[0-9]+|[0-9]+\\.[0-9]+|[^ \t\n\r]+)" MATCHED_LINE "${PUBSPEC_CONTENTS}")

  if(MATCHED_LINE)
    string(REGEX REPLACE "version:[ \t]*" "" FVP_VERSION "${MATCHED_LINE}")
    message(STATUS "Found fvp version: ${FVP_VERSION}")
    set(VERSION_HEADER_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../lib/src/version.h")
    file(WRITE ${VERSION_HEADER_FILE} "#pragma once\n#define FVP_VERSION \"${FVP_VERSION}\"\n")
  else()
    message(WARNING "No version line found in file")
  endif()
endfunction(fvp_version)


function(_fvp_resolve_deps_options DEFAULT_URL OUT_URL OUT_SHA256)
  set(DEPS_URL "${FVP_DEPS_URL}")
  string(STRIP "${DEPS_URL}" DEPS_URL)
  if("${DEPS_URL}" STREQUAL "" AND "$ENV{FVP_DEPS_URL}" MATCHES "^http")
    set(DEPS_URL "$ENV{FVP_DEPS_URL}")
    string(STRIP "${DEPS_URL}" DEPS_URL)
  endif()
  if("${DEPS_URL}" STREQUAL "")
    set(DEPS_URL "${DEFAULT_URL}")
    string(STRIP "${DEPS_URL}" DEPS_URL)
  endif()
  string(REGEX REPLACE "/+$" "" DEPS_URL "${DEPS_URL}")

  set(DEPS_SHA256 "${FVP_DEPS_SHA256}")
  string(STRIP "${DEPS_SHA256}" DEPS_SHA256)
  if("${DEPS_SHA256}" STREQUAL "")
    set(DEPS_SHA256 "$ENV{FVP_DEPS_SHA256}")
    string(STRIP "${DEPS_SHA256}" DEPS_SHA256)
  endif()
  if(NOT "${DEPS_SHA256}" STREQUAL "")
    string(LENGTH "${DEPS_SHA256}" DEPS_SHA256_LENGTH)
    if(NOT DEPS_SHA256_LENGTH EQUAL 64 OR NOT "${DEPS_SHA256}" MATCHES "^[0-9A-Fa-f]+$")
      message(FATAL_ERROR "FVP_DEPS_SHA256 must be a 64-character hexadecimal SHA-256 value")
    endif()
    string(TOLOWER "${DEPS_SHA256}" DEPS_SHA256)
  endif()

  set(${OUT_URL} "${DEPS_URL}" PARENT_SCOPE)
  set(${OUT_SHA256} "${DEPS_SHA256}" PARENT_SCOPE)
endfunction()


function(_fvp_download_file URL OUTPUT EXPECTED_SHA256)
  get_filename_component(OUTPUT_DIR "${OUTPUT}" DIRECTORY)
  file(MAKE_DIRECTORY "${OUTPUT_DIR}")
  set(PARTIAL_OUTPUT "${OUTPUT}.part")
  file(REMOVE "${PARTIAL_OUTPUT}")

  message(STATUS "Downloading ${URL}")
  file(DOWNLOAD "${URL}" "${PARTIAL_OUTPUT}"
    SHOW_PROGRESS
    STATUS DOWNLOAD_STATUS
  )
  list(GET DOWNLOAD_STATUS 0 DOWNLOAD_STATUS_CODE)
  list(GET DOWNLOAD_STATUS 1 DOWNLOAD_STATUS_MESSAGE)
  if(NOT DOWNLOAD_STATUS_CODE EQUAL 0)
    file(REMOVE "${PARTIAL_OUTPUT}")
    message(FATAL_ERROR "Failed to download ${URL}: ${DOWNLOAD_STATUS_MESSAGE}")
  endif()

  if(NOT "${EXPECTED_SHA256}" STREQUAL "")
    file(SHA256 "${PARTIAL_OUTPUT}" DOWNLOADED_SHA256)
    string(TOLOWER "${DOWNLOADED_SHA256}" DOWNLOADED_SHA256)
    if(NOT "${DOWNLOADED_SHA256}" STREQUAL "${EXPECTED_SHA256}")
      file(REMOVE "${PARTIAL_OUTPUT}")
      message(FATAL_ERROR
        "SHA-256 mismatch for ${URL}\n"
        "  expected: ${EXPECTED_SHA256}\n"
        "  actual:   ${DOWNLOADED_SHA256}"
      )
    endif()
  endif()

  file(RENAME "${PARTIAL_OUTPUT}" "${OUTPUT}")
endfunction()


function(_fvp_prepare_mdk_sdk SDK_URL SDK_ARCHIVE EXTRACT_ROOT EXPECTED_SHA256 UPDATE_LATEST)
  get_filename_component(REAL_EXTRACT_ROOT "${EXTRACT_ROOT}" REALPATH)
  file(MAKE_DIRECTORY "${REAL_EXTRACT_ROOT}")
  file(LOCK "${REAL_EXTRACT_ROOT}/fvp-deps.lock"
    GUARD FUNCTION
    TIMEOUT 300
    RESULT_VARIABLE LOCK_RESULT
  )
  if(NOT "${LOCK_RESULT}" STREQUAL "0")
    message(FATAL_ERROR "Failed to lock the MDK SDK cache: ${LOCK_RESULT}")
  endif()

  set(SDK_DIR "${REAL_EXTRACT_ROOT}/mdk-sdk")
  set(SDK_MARKER "${SDK_DIR}/lib/cmake/FindMDK.cmake")
  set(SDK_STAMP "${SDK_DIR}/.fvp-deps.sha256")
  set(SDK_BACKUP_DIR "${REAL_EXTRACT_ROOT}/.fvp-mdk-backup")

  if(EXISTS "${SDK_BACKUP_DIR}")
    if(EXISTS "${SDK_DIR}")
      file(REMOVE_RECURSE "${SDK_BACKUP_DIR}")
    else()
      execute_process(
        COMMAND "${CMAKE_COMMAND}" -E rename "${SDK_BACKUP_DIR}" "${SDK_DIR}"
        ERROR_VARIABLE RECOVERY_ERROR
        RESULT_VARIABLE RECOVERY_RESULT
      )
      if(NOT RECOVERY_RESULT EQUAL 0)
        message(FATAL_ERROR "Failed to recover the cached mdk-sdk: ${RECOVERY_ERROR}")
      endif()
    endif()
  endif()

  if(NOT "${EXPECTED_SHA256}" STREQUAL "" AND EXISTS "${SDK_MARKER}" AND EXISTS "${SDK_STAMP}")
    file(READ "${SDK_STAMP}" CACHED_SHA256)
    string(STRIP "${CACHED_SHA256}" CACHED_SHA256)
    string(TOLOWER "${CACHED_SHA256}" CACHED_SHA256)
    if("${CACHED_SHA256}" STREQUAL "${EXPECTED_SHA256}")
      message(STATUS "Using cached mdk-sdk (SHA256: ${CACHED_SHA256})")
      return()
    endif()
  endif()

  set(FORCE_DOWNLOAD OFF)
  if("${EXPECTED_SHA256}" STREQUAL "" AND UPDATE_LATEST)
    if(EXISTS "${SDK_ARCHIVE}")
      message(STATUS "Downloading latest MD5")
      _fvp_download_file("${SDK_URL}.md5" "${SDK_ARCHIVE}.md5" "")
      file(READ "${SDK_ARCHIVE}.md5" LATEST_MD5)
      string(STRIP "${LATEST_MD5}" LATEST_MD5)
      file(MD5 "${SDK_ARCHIVE}" ARCHIVE_MD5)
      message(STATUS "MD5 [${ARCHIVE_MD5}] => [${LATEST_MD5}]")
      if(NOT "${LATEST_MD5}" STREQUAL "${ARCHIVE_MD5}")
        set(FORCE_DOWNLOAD ON)
      endif()
    else()
      set(FORCE_DOWNLOAD ON)
    endif()
  endif()

  if("${EXPECTED_SHA256}" STREQUAL "" AND NOT FORCE_DOWNLOAD AND EXISTS "${SDK_MARKER}")
    set(CAN_REUSE_SDK ON)
    if(UPDATE_LATEST)
      if(EXISTS "${SDK_ARCHIVE}" AND EXISTS "${SDK_STAMP}")
        file(SHA256 "${SDK_ARCHIVE}" ARCHIVE_SHA256)
        file(READ "${SDK_STAMP}" CACHED_SHA256)
        string(STRIP "${CACHED_SHA256}" CACHED_SHA256)
        string(TOLOWER "${CACHED_SHA256}" CACHED_SHA256)
        if(NOT "${ARCHIVE_SHA256}" STREQUAL "${CACHED_SHA256}")
          message(STATUS "Cached mdk-sdk does not match the downloaded archive; re-extracting")
          set(CAN_REUSE_SDK OFF)
        endif()
      else()
        message(STATUS "Cached mdk-sdk checksum is unavailable; re-extracting")
        set(CAN_REUSE_SDK OFF)
      endif()
    endif()
    if(CAN_REUSE_SDK AND EXISTS "${SDK_STAMP}")
      file(READ "${SDK_STAMP}" CACHED_SHA256)
      string(STRIP "${CACHED_SHA256}" CACHED_SHA256)
      message(STATUS "Using cached mdk-sdk (SHA256: ${CACHED_SHA256})")
    elseif(CAN_REUSE_SDK)
      message(STATUS "Using cached mdk-sdk (checksum unavailable)")
    endif()
    if(CAN_REUSE_SDK)
      return()
    endif()
  endif()

  set(NEED_DOWNLOAD "${FORCE_DOWNLOAD}")
  if(EXISTS "${SDK_ARCHIVE}" AND NOT NEED_DOWNLOAD)
    file(SHA256 "${SDK_ARCHIVE}" ARCHIVE_SHA256)
    string(TOLOWER "${ARCHIVE_SHA256}" ARCHIVE_SHA256)
    if(NOT "${EXPECTED_SHA256}" STREQUAL "" AND NOT "${ARCHIVE_SHA256}" STREQUAL "${EXPECTED_SHA256}")
      message(STATUS "Cached MDK SDK archive does not match FVP_DEPS_SHA256")
      set(NEED_DOWNLOAD ON)
    endif()
  else()
    set(NEED_DOWNLOAD ON)
  endif()

  if(NEED_DOWNLOAD)
    _fvp_download_file("${SDK_URL}" "${SDK_ARCHIVE}" "${EXPECTED_SHA256}")
    file(SHA256 "${SDK_ARCHIVE}" ARCHIVE_SHA256)
    string(TOLOWER "${ARCHIVE_SHA256}" ARCHIVE_SHA256)
  endif()
  message(STATUS "MDK SDK archive SHA256: ${ARCHIVE_SHA256}")

  set(TEMP_EXTRACT_DIR "${REAL_EXTRACT_ROOT}/.fvp-mdk-extract")
  file(REMOVE_RECURSE "${TEMP_EXTRACT_DIR}")
  file(MAKE_DIRECTORY "${TEMP_EXTRACT_DIR}")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar "xvf" "${SDK_ARCHIVE}"
    WORKING_DIRECTORY "${TEMP_EXTRACT_DIR}"
    OUTPUT_QUIET
    ERROR_VARIABLE EXTRACT_ERROR
    RESULT_VARIABLE EXTRACT_RESULT
  )
  if(NOT EXTRACT_RESULT EQUAL 0 OR NOT EXISTS "${TEMP_EXTRACT_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake")
    file(REMOVE_RECURSE "${TEMP_EXTRACT_DIR}")
    if("${EXPECTED_SHA256}" STREQUAL "")
      file(REMOVE "${SDK_ARCHIVE}")
    endif()
    message(FATAL_ERROR
      "Failed to extract mdk-sdk from ${SDK_ARCHIVE}: ${EXTRACT_ERROR}"
    )
  endif()
  file(WRITE "${TEMP_EXTRACT_DIR}/mdk-sdk/.fvp-deps.sha256" "${ARCHIVE_SHA256}\n")

  if(EXISTS "${SDK_DIR}")
    execute_process(
      COMMAND "${CMAKE_COMMAND}" -E rename "${SDK_DIR}" "${SDK_BACKUP_DIR}"
      ERROR_VARIABLE BACKUP_ERROR
      RESULT_VARIABLE BACKUP_RESULT
    )
    if(NOT BACKUP_RESULT EQUAL 0)
      file(REMOVE_RECURSE "${TEMP_EXTRACT_DIR}")
      message(FATAL_ERROR "Failed to back up the cached mdk-sdk: ${BACKUP_ERROR}")
    endif()
  endif()
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E rename "${TEMP_EXTRACT_DIR}/mdk-sdk" "${SDK_DIR}"
    ERROR_VARIABLE INSTALL_ERROR
    RESULT_VARIABLE INSTALL_RESULT
  )
  if(NOT INSTALL_RESULT EQUAL 0)
    if(EXISTS "${SDK_BACKUP_DIR}")
      execute_process(
        COMMAND "${CMAKE_COMMAND}" -E rename "${SDK_BACKUP_DIR}" "${SDK_DIR}"
        ERROR_VARIABLE RESTORE_ERROR
        RESULT_VARIABLE RESTORE_RESULT
      )
      if(NOT RESTORE_RESULT EQUAL 0)
        file(REMOVE_RECURSE "${TEMP_EXTRACT_DIR}")
        message(FATAL_ERROR
          "Failed to install the extracted mdk-sdk: ${INSTALL_ERROR}\n"
          "The previous SDK is preserved at ${SDK_BACKUP_DIR}, but could not be restored: ${RESTORE_ERROR}"
        )
      endif()
    endif()
    file(REMOVE_RECURSE "${TEMP_EXTRACT_DIR}")
    message(FATAL_ERROR "Failed to install the extracted mdk-sdk: ${INSTALL_ERROR}")
  endif()
  file(REMOVE_RECURSE "${SDK_BACKUP_DIR}")
  file(REMOVE_RECURSE "${TEMP_EXTRACT_DIR}")
  message(STATUS "Extracted mdk-sdk (SHA256: ${ARCHIVE_SHA256})")
endfunction()


macro(fvp_setup_deps)
  fvp_version()
  if(WIN32)
    set(MDK_SDK_PKG mdk-sdk-windows.7z)
    if(CMAKE_CXX_COMPILER_ARCHITECTURE_ID MATCHES "[xX]64") # msvc
      set(MDK_SDK_PKG mdk-sdk-windows-x64.7z)
    endif()
  elseif(ANDROID)
    set(MDK_SDK_PKG mdk-sdk-android.7z)
  elseif(CMAKE_SYSTEM_NAME MATCHES "OHOS")
    set(MDK_SDK_PKG mdk-sdk-ohos.7z)
  elseif(LINUX OR CMAKE_SYSTEM_NAME MATCHES "Linux")
    set(MDK_SDK_PKG mdk-sdk-linux.tar.xz)
    if(CMAKE_C_COMPILER_ARCHITECTURE_ID MATCHES "[xX].*64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "[xX].*64" OR CMAKE_SYSTEM_PROCESSOR MATCHES "[aA][mM][dD]64")
      set(MDK_SDK_PKG mdk-sdk-linux-x64.tar.xz)
    endif()
  else()
  endif()
  _fvp_resolve_deps_options(
    "https://sourceforge.net/projects/mdk-sdk/files/nightly"
    FVP_DEPS_URL_EFFECTIVE
    FVP_DEPS_SHA256_EFFECTIVE
  )
  set(MDK_SDK_URL "${FVP_DEPS_URL_EFFECTIVE}/${MDK_SDK_PKG}")
  get_filename_component(MDK_SDK_EXTRACT_DIR "${CMAKE_CURRENT_SOURCE_DIR}" REALPATH)
  set(MDK_SDK_SAVE "${MDK_SDK_EXTRACT_DIR}/${MDK_SDK_PKG}")
  message(STATUS "MDK SDK URL: ${MDK_SDK_URL}")
  if(NOT "${FVP_DEPS_SHA256_EFFECTIVE}" STREQUAL "")
    message(STATUS "MDK SDK expected SHA256: ${FVP_DEPS_SHA256_EFFECTIVE}")
  endif()

  set(UPDATE_MDK_SDK_LATEST OFF)
  set(FVP_DEPS_LATEST_EFFECTIVE "$ENV{FVP_DEPS_LATEST}")
  message(STATUS "FVP_DEPS_LATEST=${FVP_DEPS_LATEST_EFFECTIVE}")
  # TODO: download from github option FVP_DEPS_LATEST_RELEASE=1
  if(NOT "${FVP_DEPS_SHA256_EFFECTIVE}" STREQUAL "" AND FVP_DEPS_LATEST_EFFECTIVE)
    message(STATUS "Ignoring FVP_DEPS_LATEST because FVP_DEPS_SHA256 is set")
  elseif(FVP_DEPS_LATEST_EFFECTIVE)
    set(UPDATE_MDK_SDK_LATEST ON)
  endif()

  _fvp_prepare_mdk_sdk(
    "${MDK_SDK_URL}"
    "${MDK_SDK_SAVE}"
    "${MDK_SDK_EXTRACT_DIR}"
    "${FVP_DEPS_SHA256_EFFECTIVE}"
    "${UPDATE_MDK_SDK_LATEST}"
  )
  include("${CMAKE_CURRENT_SOURCE_DIR}/mdk-sdk/lib/cmake/FindMDK.cmake")
endmacro()
