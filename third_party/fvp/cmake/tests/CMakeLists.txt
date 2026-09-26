cmake_minimum_required(VERSION 3.15)

project(fvp_deps_tests NONE)

enable_testing()

function(create_mdk_fixture NAME PAYLOAD OUT_ARCHIVE OUT_SHA256)
  set(FIXTURE_ROOT "${CMAKE_CURRENT_BINARY_DIR}/fixtures/${NAME}")
  set(FIXTURE_ARCHIVE "${CMAKE_CURRENT_BINARY_DIR}/fixtures/${NAME}.tar")
  file(REMOVE_RECURSE "${FIXTURE_ROOT}")
  file(MAKE_DIRECTORY "${FIXTURE_ROOT}/mdk-sdk/lib/cmake")
  file(WRITE "${FIXTURE_ROOT}/mdk-sdk/lib/cmake/FindMDK.cmake"
    "set(FVP_TEST_FIND_MDK TRUE)\n"
  )
  file(WRITE "${FIXTURE_ROOT}/mdk-sdk/payload.txt" "${PAYLOAD}\n")
  execute_process(
    COMMAND "${CMAKE_COMMAND}" -E tar "cf" "${FIXTURE_ARCHIVE}" "--format=gnutar" "mdk-sdk"
    WORKING_DIRECTORY "${FIXTURE_ROOT}"
    RESULT_VARIABLE ARCHIVE_RESULT
    ERROR_VARIABLE ARCHIVE_ERROR
  )
  if(NOT ARCHIVE_RESULT EQUAL 0)
    message(FATAL_ERROR "Failed to create ${NAME} fixture: ${ARCHIVE_ERROR}")
  endif()
  file(SHA256 "${FIXTURE_ARCHIVE}" FIXTURE_SHA256)
  file(MD5 "${FIXTURE_ARCHIVE}" FIXTURE_MD5)
  file(WRITE "${FIXTURE_ARCHIVE}.md5" "${FIXTURE_MD5}\n")
  set(${OUT_ARCHIVE} "${FIXTURE_ARCHIVE}" PARENT_SCOPE)
  set(${OUT_SHA256} "${FIXTURE_SHA256}" PARENT_SCOPE)
endfunction()

create_mdk_fixture("v1" "fixture-v1" FIXTURE_V1_ARCHIVE FIXTURE_V1_SHA256)
create_mdk_fixture("v2" "fixture-v2" FIXTURE_V2_ARCHIVE FIXTURE_V2_SHA256)

if(WIN32)
  set(FILE_URL_PREFIX "file:///")
else()
  set(FILE_URL_PREFIX "file://")
endif()
set(FIXTURE_V1_URL "${FILE_URL_PREFIX}${FIXTURE_V1_ARCHIVE}")
set(FIXTURE_V2_URL "${FILE_URL_PREFIX}${FIXTURE_V2_ARCHIVE}")

set(INTEGRATION_RELEASE_DIR "${CMAKE_CURRENT_BINARY_DIR}/integration-release")
set(INTEGRATION_ROOT "${CMAKE_CURRENT_BINARY_DIR}/integration root")
set(INTEGRATION_BAD_ROOT "${CMAKE_CURRENT_BINARY_DIR}/integration bad root")
file(MAKE_DIRECTORY "${INTEGRATION_RELEASE_DIR}" "${INTEGRATION_ROOT}" "${INTEGRATION_BAD_ROOT}")
configure_file(
  "${FIXTURE_V1_ARCHIVE}"
  "${INTEGRATION_RELEASE_DIR}/mdk-sdk-linux-x64.tar.xz"
  COPYONLY
)
configure_file(
  "${FIXTURE_V1_ARCHIVE}"
  "${INTEGRATION_RELEASE_DIR}/mdk-sdk-windows.7z"
  COPYONLY
)

add_test(
  NAME fvp_deps
  COMMAND "${CMAKE_COMMAND}"
    "-DDEPS_FILE=${CMAKE_CURRENT_LIST_DIR}/../deps.cmake"
    "-DINVOKE_FILE=${CMAKE_CURRENT_LIST_DIR}/invoke_fetch.cmake"
    "-DTEST_ROOT=${CMAKE_CURRENT_BINARY_DIR}/test root"
    "-DFIXTURE_V1_URL=${FIXTURE_V1_URL}"
    "-DFIXTURE_V1_SHA256=${FIXTURE_V1_SHA256}"
    "-DFIXTURE_V2_URL=${FIXTURE_V2_URL}"
    "-DFIXTURE_V2_SHA256=${FIXTURE_V2_SHA256}"
    -P "${CMAKE_CURRENT_LIST_DIR}/deps_test.cmake"
)

add_test(
  NAME fvp_deps_integration
  COMMAND "${CMAKE_COMMAND}"
    "-DDEPS_FILE=${CMAKE_CURRENT_LIST_DIR}/../deps.cmake"
    "-DFVP_DEPS_URL=${FILE_URL_PREFIX}${INTEGRATION_RELEASE_DIR}"
    "-DFVP_DEPS_SHA256=${FIXTURE_V1_SHA256}"
    -P "${CMAKE_CURRENT_LIST_DIR}/macro_test.cmake"
)
set_tests_properties(fvp_deps_integration PROPERTIES
  ENVIRONMENT "FVP_DEPS_LATEST=1"
  WORKING_DIRECTORY "${INTEGRATION_ROOT}"
)

add_test(
  NAME fvp_deps_integration_bad_sha
  COMMAND "${CMAKE_COMMAND}"
    "-DDEPS_FILE=${CMAKE_CURRENT_LIST_DIR}/../deps.cmake"
    "-DMACRO_TEST_FILE=${CMAKE_CURRENT_LIST_DIR}/macro_test.cmake"
    "-DSDK_BASE_URL=${FILE_URL_PREFIX}${INTEGRATION_RELEASE_DIR}"
    "-DTEST_ROOT=${INTEGRATION_BAD_ROOT}"
    -P "${CMAKE_CURRENT_LIST_DIR}/macro_bad_sha_test.cmake"
)
