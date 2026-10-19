
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

#endif  // RUNNER_UTILS_H_
