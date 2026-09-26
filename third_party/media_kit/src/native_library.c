// Resolve the module selected by the code-assets runtime for all consumers.
#define _GNU_SOURCE
#include <stddef.h>
#include <stdint.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#define MK_EXPORT __declspec(dllexport)
#else
#include <dlfcn.h>
#include <locale.h>
#define MK_EXPORT __attribute__((visibility("default"))) __attribute__((used))
#endif

MK_EXPORT int32_t media_kit_library_path(void *symbol, char *buffer, int32_t capacity) {
#ifdef _WIN32
    HMODULE module;
    if (!GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT, (LPCWSTR)symbol, &module)) return -1;
    wchar_t wide[32768];
    DWORD length = GetModuleFileNameW(module, wide, 32768);
    if (!length || length == 32768) return -1;
    return WideCharToMultiByte(CP_UTF8, 0, wide, -1, buffer, capacity, NULL, NULL) ? 0 : -1;
#else
    Dl_info info;
    if (!dladdr(symbol, &info) || !info.dli_fname) return -1;
    size_t length = strlen(info.dli_fname) + 1;
    if (length > (size_t)capacity) return -1;
    memcpy(buffer, info.dli_fname, length);
#ifdef __linux__
    // libmpv's client API requires a C numeric locale.
    setlocale(LC_NUMERIC, "C");
#endif
    return 0;
#endif
}
