
#include "utils.h"

#include <cctype>
#include <flutter_windows.h>
#include <io.h>
#include <shellapi.h>
#include <stdio.h>
#include <windows.h>

#include <iostream>
#include <string>
#include <vector>

void CreateAndAttachConsole() {
  if (::AllocConsole()) {
    FILE* unused;
    if (freopen_s(&unused, "CONOUT$", "w", stdout)) {
      _dup2(_fileno(stdout), 1);
    }
    if (freopen_s(&unused, "CONOUT$", "w", stderr)) {
      _dup2(_fileno(stdout), 2);
    }

    std::ios::sync_with_stdio();
    FlutterDesktopResyncOutputStreams();
  }
}

std::vector<std::string> GetCommandLineArguments() {
  // Convert UTF-16 command-line arguments to UTF-8.
  int argc = 0;
  wchar_t** argv = ::CommandLineToArgvW(::GetCommandLineW(), &argc);

  if (argv == nullptr) {
    return {};
  }

  std::vector<std::string> command_line_arguments;

  // Skip argv[0], which contains the executable path.
  for (int i = 1; i < argc; ++i) {
    command_line_arguments.push_back(Utf8FromUtf16(argv[i]));
  }

  ::LocalFree(argv);
  return command_line_arguments;
}

std::string Utf8FromUtf16(const wchar_t* utf16_string) {
  if (utf16_string == nullptr) {
    return {};
  }

  // Bound the scan to the maximum Windows Unicode string length.
  const size_t bounded_length =
      ::wcsnlen(utf16_string, UNICODE_STRING_MAX_CHARS);

  const int input_length = static_cast<int>(bounded_length);

  if (input_length == 0) {
    return {};
  }

  const int target_length = ::WideCharToMultiByte(
      CP_UTF8,
      WC_ERR_INVALID_CHARS,
      utf16_string,
      input_length,
      nullptr,
      0,
      nullptr,
      nullptr);

  if (target_length <= 0) {
    return {};
  }

  std::string utf8_string(
      static_cast<size_t>(target_length), '\0');

  const int converted_length = ::WideCharToMultiByte(
      CP_UTF8,
      WC_ERR_INVALID_CHARS,
      utf16_string,
      input_length,
      utf8_string.data(),
      target_length,
      nullptr,
      nullptr);

  if (converted_length != target_length) {
    return {};
  }

  return utf8_string;
}

namespace {

constexpr wchar_t kFrameFlagFileName[] =
    L".pure_window_chrome";

constexpr DWORD kRoundedFrameBuild = 22000;

/// Returns the actual Windows build number, or zero on failure.
DWORD WindowsBuildNumber() {
  HMODULE ntdll = ::GetModuleHandleW(L"ntdll.dll");
  if (ntdll == nullptr) {
    return 0;
  }

  using RtlGetVersionFunction =
      LONG(NTAPI*)(OSVERSIONINFOEXW*);

  auto routine = reinterpret_cast<RtlGetVersionFunction>(
      ::GetProcAddress(ntdll, "RtlGetVersion"));

  if (routine == nullptr) {
    return 0;
  }

  OSVERSIONINFOEXW info{};
  info.dwOSVersionInfoSize = sizeof(info);

  if (routine(&info) != 0) {
    return 0;
  }

  return info.dwBuildNumber;
}

/// Reads the frame preference from the user's profile.
bool ReadFrameFlagFile(std::string& out) {
  wchar_t profile[MAX_PATH]{};

  const DWORD length = ::GetEnvironmentVariableW(
      L"USERPROFILE",
      profile,
      MAX_PATH);

  if (length == 0 || length >= MAX_PATH) {
    return false;
  }

  std::wstring path(profile, length);
  path += L"\\";
  path += kFrameFlagFileName;

  HANDLE file = ::CreateFileW(
      path.c_str(),
      GENERIC_READ,
      FILE_SHARE_READ,
      nullptr,
      OPEN_EXISTING,
      FILE_ATTRIBUTE_NORMAL,
      nullptr);

  if (file == INVALID_HANDLE_VALUE) {
    return false;
  }

  char buffer[32]{};
  DWORD bytes_read = 0;

  const BOOL ok = ::ReadFile(
      file,
      buffer,
      static_cast<DWORD>(sizeof(buffer) - 1),
      &bytes_read,
      nullptr);

  ::CloseHandle(file);

  if (!ok || bytes_read == 0) {
    return false;
  }

  out.assign(buffer, bytes_read);
  return true;
}

/// Removes whitespace and normalizes ASCII letters to lowercase.
std::string NormaliseFrameFlag(const std::string& value) {
  std::string normalized;
  normalized.reserve(value.size());

  for (const unsigned char character : value) {
    if (character == ' ' ||
        character == '\t' ||
        character == '\r' ||
        character == '\n') {
      continue;
    }

    normalized.push_back(
        static_cast<char>(::tolower(character)));
  }

  return normalized;
}

}  // namespace

bool UseNativeWindowFrame() {
  // Command-line arguments take precedence over the flag file.
  // If both are specified, the last argument wins.
  bool decided_by_argument = false;
  bool native_from_argument = false;

  for (const auto& argument : GetCommandLineArguments()) {
    if (argument == "--native-frame") {
      decided_by_argument = true;
      native_from_argument = true;
    } else if (argument == "--custom-frame") {
      decided_by_argument = true;
      native_from_argument = false;
    }
  }

  if (decided_by_argument) {
    return native_from_argument;
  }

  // Read the preference mirrored from the Dart-side window setting.
  std::string value;

  if (ReadFrameFlagFile(value)) {
    return NormaliseFrameFlag(value) == "system";
  }

  // Fall back to the OS build number.
  // Windows 10 defaults to the native frame; Windows 11 defaults to
  // the app-managed frame.
  const DWORD build = WindowsBuildNumber();

  if (build == 0) {
    return false;
  }

  return build < kRoundedFrameBuild;
}
