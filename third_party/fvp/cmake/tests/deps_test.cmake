cmake_minimum_required(VERSION 3.15)

foreach(REQUIRED_VARIABLE
    DEPS_FILE
    INVOKE_FILE
    TEST_ROOT
    FIXTURE_V1_URL
    FIXTURE_V1_SHA256
    FIXTURE_V2_URL
    FIXTURE_V2_SHA256)
  if(NOT DEFINED ${REQUIRED_VARIABLE})
    message(FATAL_ERROR "${REQUIRED_VARIABLE} is required")
  endif()
endforeach()

include("${DEPS_FILE}")

function(assert_equal ACTUAL EXPECTED DESCRIPTION)
  if(NOT "${ACTUAL}" STREQUAL "${EXPECTED}")
    message(FATAL_ERROR
      "${DESCRIPTION}\n"
      "  expected: ${EXPECTED}\n"
      "  actual:   ${ACTUAL}"
    )
  endif()
endfunction()

function(assert_exists PATH DESCRIPTION)
  if(NOT EXISTS "${PATH}")
    message(FATAL_ERROR "${DESCRIPTION}: ${PATH}")
  endif()
endfunction()

function(assert_not_exists PATH DESCRIPTION)
  if(EXISTS "${PATH}")
    message(FATAL_ERROR "${DESCRIPTION}: ${PATH}")
  endif()
endfunction()

function(assert_payload ROOT EXPECTED)
  set(PAYLOAD_FILE "${ROOT}/mdk-sdk/payload.txt")
  assert_exists("${PAYLOAD_FILE}" "MDK SDK payload is missing")
  file(READ "${PAYLOAD_FILE}" ACTUAL_PAYLOAD)
  string(STRIP "${ACTUAL_PAYLOAD}" ACTUAL_PAYLOAD)
  assert_equal("${ACTUAL_PAYLOAD}" "${EXPECTED}" "Unexpected MDK SDK payload")
endfunction()

file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${TEST_ROOT}")

# CMake variables take precedence over environment variables. Empty values
# fall back to the environment and then to the default URL.
set(ENV{FVP_DEPS_URL} "https://env.example.invalid/releases")
string(TOUPPER "${FIXTURE_V2_SHA256}" FIXTURE_V2_SHA256_UPPER)
set(ENV{FVP_DEPS_SHA256} "${FIXTURE_V2_SHA256_UPPER}")
set(FVP_DEPS_URL "   ")
set(FVP_DEPS_SHA256 "   ")
_fvp_resolve_deps_options("https://default.example.invalid/" RESOLVED_URL RESOLVED_SHA256)
assert_equal("${RESOLVED_URL}" "https://env.example.invalid/releases" "Environment URL was not used")
assert_equal("${RESOLVED_SHA256}" "${FIXTURE_V2_SHA256}" "Environment SHA-256 was not used")

set(FVP_DEPS_URL "https://cache.example.invalid/releases/")
set(FVP_DEPS_SHA256 "${FIXTURE_V1_SHA256}")
_fvp_resolve_deps_options("https://default.example.invalid/" RESOLVED_URL RESOLVED_SHA256)
assert_equal("${RESOLVED_URL}" "https://cache.example.invalid/releases" "CMake URL did not take precedence")
assert_equal("${RESOLVED_SHA256}" "${FIXTURE_V1_SHA256}" "CMake SHA-256 did not take precedence")

set(ENV{FVP_DEPS_URL} "")
set(ENV{FVP_DEPS_SHA256} "")
set(FVP_DEPS_URL "")
set(FVP_DEPS_SHA256 "")
_fvp_resolve_deps_options("https://default.example.invalid/" RESOLVED_URL RESOLVED_SHA256)
assert_equal("${RESOLVED_URL}" "https://default.example.invalid" "Default URL was not used")
assert_equal("${RESOLVED_SHA256}" "" "Default SHA-256 must be empty")

set(ENV{FVP_DEPS_URL} "file:///legacy-environment-value-is-ignored")
_fvp_resolve_deps_options("https://default.example.invalid/" RESOLVED_URL RESOLVED_SHA256)
assert_equal("${RESOLVED_URL}" "https://default.example.invalid" "Non-HTTP environment URL behavior changed")
set(ENV{FVP_DEPS_URL} "")

# A valid pin downloads, verifies, and stamps the extracted SDK.
set(PINNED_ROOT "${TEST_ROOT}/pinned cache")
set(PINNED_ARCHIVE "${PINNED_ROOT}/mdk-sdk.tar")
_fvp_prepare_mdk_sdk(
  "${FIXTURE_V1_URL}"
  "${PINNED_ARCHIVE}"
  "${PINNED_ROOT}"
  "${FIXTURE_V1_SHA256}"
  OFF
)
assert_payload("${PINNED_ROOT}" "fixture-v1")
file(READ "${PINNED_ROOT}/mdk-sdk/.fvp-deps.sha256" PINNED_STAMP)
string(STRIP "${PINNED_STAMP}" PINNED_STAMP)
assert_equal("${PINNED_STAMP}" "${FIXTURE_V1_SHA256}" "Incorrect SHA-256 stamp")

# A matching stamp can be reused offline without the downloaded archive.
file(WRITE "${PINNED_ROOT}/mdk-sdk/local-marker.txt" "keep\n")
file(REMOVE "${PINNED_ARCHIVE}")
_fvp_prepare_mdk_sdk(
  "file:///does/not/exist/mdk-sdk.tar"
  "${PINNED_ARCHIVE}"
  "${PINNED_ROOT}"
  "${FIXTURE_V1_SHA256}"
  OFF
)
assert_exists("${PINNED_ROOT}/mdk-sdk/local-marker.txt" "Pinned cache was unexpectedly re-extracted")

# Changing the pin downloads and replaces the extracted SDK without stale files.
_fvp_prepare_mdk_sdk(
  "${FIXTURE_V2_URL}"
  "${PINNED_ARCHIVE}"
  "${PINNED_ROOT}"
  "${FIXTURE_V2_SHA256}"
  OFF
)
assert_payload("${PINNED_ROOT}" "fixture-v2")
assert_not_exists("${PINNED_ROOT}/mdk-sdk/local-marker.txt" "Stale extracted files were retained")

# Recover a last-known-good SDK if a process stopped between backup and swap.
file(RENAME "${PINNED_ROOT}/mdk-sdk" "${PINNED_ROOT}/.fvp-mdk-backup")
_fvp_prepare_mdk_sdk(
  "file:///does/not/exist/mdk-sdk.tar"
  "${PINNED_ARCHIVE}"
  "${PINNED_ROOT}"
  "${FIXTURE_V2_SHA256}"
  OFF
)
assert_payload("${PINNED_ROOT}" "fixture-v2")
assert_not_exists("${PINNED_ROOT}/.fvp-mdk-backup" "Recovered SDK backup was not cleaned up")

# A bad pin fails without replacing the last valid archive or extracted SDK.
set(BAD_SHA256 "0000000000000000000000000000000000000000000000000000000000000000")
execute_process(
  COMMAND "${CMAKE_COMMAND}"
    "-DDEPS_FILE=${DEPS_FILE}"
    "-DSDK_URL=${FIXTURE_V1_URL}"
    "-DSDK_ARCHIVE=${PINNED_ARCHIVE}"
    "-DEXTRACT_ROOT=${PINNED_ROOT}"
    "-DEXPECTED_SHA256=${BAD_SHA256}"
    -P "${INVOKE_FILE}"
  RESULT_VARIABLE BAD_HASH_RESULT
  OUTPUT_VARIABLE BAD_HASH_OUTPUT
  ERROR_VARIABLE BAD_HASH_ERROR
)
if(BAD_HASH_RESULT EQUAL 0)
  message(FATAL_ERROR "An incorrect SHA-256 unexpectedly succeeded")
endif()
set(BAD_HASH_LOG "${BAD_HASH_OUTPUT}\n${BAD_HASH_ERROR}")
if(NOT "${BAD_HASH_LOG}" MATCHES "SHA-256 mismatch")
  message(FATAL_ERROR "Incorrect SHA-256 failed for an unexpected reason:\n${BAD_HASH_LOG}")
endif()
assert_not_exists("${PINNED_ARCHIVE}.part" "Partial download was not removed")
file(SHA256 "${PINNED_ARCHIVE}" ARCHIVE_AFTER_FAILURE)
assert_equal("${ARCHIVE_AFTER_FAILURE}" "${FIXTURE_V2_SHA256}" "Valid archive was replaced after hash failure")
assert_payload("${PINNED_ROOT}" "fixture-v2")

# Without a pin, the existing download and cache behavior remains available.
set(LEGACY_ROOT "${TEST_ROOT}/legacy cache")
set(LEGACY_ARCHIVE "${LEGACY_ROOT}/mdk-sdk.tar")
_fvp_prepare_mdk_sdk(
  "${FIXTURE_V1_URL}"
  "${LEGACY_ARCHIVE}"
  "${LEGACY_ROOT}"
  ""
  OFF
)
assert_payload("${LEGACY_ROOT}" "fixture-v1")
_fvp_prepare_mdk_sdk(
  "${FIXTURE_V2_URL}"
  "${LEGACY_ARCHIVE}"
  "${LEGACY_ROOT}"
  ""
  ON
)
assert_payload("${LEGACY_ROOT}" "fixture-v2")

# Existing caches created by older fvp versions have no SHA-256 stamp. A
# requested latest check re-extracts the matching archive to establish one.
file(REMOVE "${LEGACY_ROOT}/mdk-sdk/.fvp-deps.sha256")
file(WRITE "${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "remove\n")
_fvp_prepare_mdk_sdk(
  "${FIXTURE_V2_URL}"
  "${LEGACY_ARCHIVE}"
  "${LEGACY_ROOT}"
  ""
  ON
)
assert_not_exists("${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "Unstamped latest SDK was not re-extracted")
assert_exists("${LEGACY_ROOT}/mdk-sdk/.fvp-deps.sha256" "Latest SDK stamp was not created")

file(WRITE "${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "keep\n")
_fvp_prepare_mdk_sdk(
  "${FIXTURE_V2_URL}"
  "${LEGACY_ARCHIVE}"
  "${LEGACY_ROOT}"
  ""
  ON
)
assert_exists("${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "Unchanged latest SDK was unexpectedly re-extracted")

# If a previous update replaced only the archive, the stamp forces extraction
# even when the remote MD5 matches that archive.
file(WRITE "${LEGACY_ROOT}/mdk-sdk/.fvp-deps.sha256" "${FIXTURE_V1_SHA256}\n")
_fvp_prepare_mdk_sdk(
  "${FIXTURE_V2_URL}"
  "${LEGACY_ARCHIVE}"
  "${LEGACY_ROOT}"
  ""
  ON
)
assert_not_exists("${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "Stale SDK survived an archive/stamp mismatch")
file(READ "${LEGACY_ROOT}/mdk-sdk/.fvp-deps.sha256" LATEST_STAMP)
string(STRIP "${LATEST_STAMP}" LATEST_STAMP)
assert_equal("${LATEST_STAMP}" "${FIXTURE_V2_SHA256}" "Latest SDK stamp was not repaired")

# Ordinary unpinned builds preserve the legacy cache behavior even if a
# leftover archive no longer matches the extracted SDK.
_fvp_download_file("${FIXTURE_V1_URL}" "${LEGACY_ARCHIVE}" "")
file(WRITE "${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "keep\n")
_fvp_prepare_mdk_sdk(
  "file:///does/not/exist/mdk-sdk.tar"
  "${LEGACY_ARCHIVE}"
  "${LEGACY_ROOT}"
  ""
  OFF
)
assert_exists("${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "Ordinary unpinned cache behavior changed")
assert_payload("${LEGACY_ROOT}" "fixture-v2")

file(REMOVE "${LEGACY_ARCHIVE}")
_fvp_prepare_mdk_sdk(
  "file:///does/not/exist/mdk-sdk.tar"
  "${LEGACY_ARCHIVE}"
  "${LEGACY_ROOT}"
  ""
  OFF
)
assert_exists("${LEGACY_ROOT}/mdk-sdk/local-marker.txt" "Unpinned cache behavior changed")
