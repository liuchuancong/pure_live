
#include "utils.h"

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
