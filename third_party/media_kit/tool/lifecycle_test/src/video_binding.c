#include "media_kit_mpv.h"
#ifdef _WIN32
#define EXPORT __declspec(dllexport)
#else
#define EXPORT __attribute__((visibility("default")))
#endif

EXPORT int fixture_bind_video(const char *path) {
    return media_kit_mpv_initialize(path);
}

EXPORT int fixture_video_pause(mpv_handle *handle) {
    int paused = -1;
    const int result = media_kit_mpv_get_property(handle, "pause", MPV_FORMAT_FLAG, &paused);
    return result < 0 ? result : paused;
}
