
#ifndef RUNNER_UTILS_H_
#define RUNNER_UTILS_H_

#include <string>
#include <vector>

// Creates a console for the process and redirects stdout and stderr.
void CreateAndAttachConsole();

// Converts a null-terminated UTF-16 string to UTF-8.
std::string Utf8FromUtf16(const wchar_t* utf16_string);

// Gets the command line arguments encoded in UTF-8.
std::vector<std::string> GetCommandLineArguments();

// Determines whether the operating system should draw the window frame.
//
// Resolution order:
// 1. --native-frame / --custom-frame command-line arguments.
// 2. %USERPROFILE%\.pure_window_chrome.
// 3. Windows build number.
//
// The result is resolved before window creation and applies on next start.
bool UseNativeWindowFrame();

#endif  // RUNNER_UTILS_H_
