// A controllable mpv ABI fixture. Deliberately reuses its event buffer just as
// mpv_wait_event does. The native producer also calls back during shutdown.
#define _GNU_SOURCE
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#ifdef _WIN32
#include <windows.h>
#define EXPORT __declspec(dllexport)
typedef CRITICAL_SECTION mutex;
#define init(m) InitializeCriticalSection(m)
#define lock(m) EnterCriticalSection(m)
#define unlock(m) LeaveCriticalSection(m)
#define finish(m) DeleteCriticalSection(m)
#define sleep_ms() Sleep(1)
static volatile LONG destroyed_count, violation_count, blocked;
#define get(p) InterlockedCompareExchange(p, 0, 0)
#define increment(p) InterlockedIncrement(p)
#define set(p, v) InterlockedExchange(p, v)
#else
#include <pthread.h>
#include <unistd.h>
#include <dlfcn.h>
#define EXPORT __attribute__((visibility("default")))
typedef pthread_mutex_t mutex;
#define init(m) pthread_mutex_init(m, NULL)
#define lock(m) pthread_mutex_lock(m)
#define unlock(m) pthread_mutex_unlock(m)
#define finish(m) pthread_mutex_destroy(m)
#define sleep_ms() usleep(1000)
static int destroyed_count, violation_count, blocked;
#define get(p) __atomic_load_n(p, __ATOMIC_SEQ_CST)
#define increment(p) __atomic_add_fetch(p, 1, __ATOMIC_SEQ_CST)
#define set(p, v) __atomic_store_n(p, v, __ATOMIC_SEQ_CST)
#endif

typedef struct { int event_id, error; uint64_t reply_userdata; void *data; } event;
typedef struct {
    mutex gate;
    void (*callback)(void *);
    void *userdata;
    int pending, polls, value, fail_initialize, stopping, stress_started;
    event buffer;
#ifdef _WIN32
    HANDLE thread;
#else
    pthread_t thread;
#endif
} handle;

EXPORT void *mpv_create(void) {
    handle *h = calloc(1, sizeof(*h));
    init(&h->gate);
    return h;
}
EXPORT int mpv_set_option_string(handle *h, const char *name, const char *value) {
    if (!strcmp(name, "fail-initialize")) h->fail_initialize = 1;
    return 0;
}
EXPORT int mpv_initialize(handle *h) { return h->fail_initialize ? -1 : 0; }
EXPORT void mpv_set_wakeup_callback(handle *h, void (*cb)(void *), void *data) {
    lock(&h->gate);
    h->callback = cb;
    h->userdata = data;
    if (cb) cb(data);
    unlock(&h->gate);
}
EXPORT event *mpv_wait_event(handle *h, double timeout) {
    lock(&h->gate);
    h->polls++;
    h->value++;
    h->buffer.event_id = h->pending ? 25 : 0;
    h->buffer.data = &h->value;
    if (h->pending) h->pending--;
    unlock(&h->gate);
    return &h->buffer;
}
EXPORT void fixture_emit(handle *h) {
    lock(&h->gate);
    h->pending++;
    if (h->callback) h->callback(h->userdata);
    unlock(&h->gate);
}
#ifdef _WIN32
static DWORD WINAPI producer(void *opaque) {
#else
static void *producer(void *opaque) {
#endif
    handle *h = opaque;
    for (;;) {
        lock(&h->gate);
        int stopping = h->stopping;
        if (!stopping) {
            h->pending++;
            if (h->callback) h->callback(h->userdata);
        }
        unlock(&h->gate);
        if (stopping) break;
        sleep_ms();
    }
    return 0;
}
EXPORT void fixture_start_stress(handle *h) {
    h->stress_started = 1;
#ifdef _WIN32
    h->thread = CreateThread(NULL, 0, producer, h, 0, NULL);
    if (!h->thread) abort();
#else
    if (pthread_create(&h->thread, NULL, producer, h)) abort();
#endif
}
EXPORT void mpv_terminate_destroy(handle *h) {
    while (get(&blocked)) sleep_ms();
    lock(&h->gate);
    if (h->callback) increment(&violation_count);
    h->stopping = 1;
    unlock(&h->gate);
    if (h->stress_started) {
#ifdef _WIN32
        WaitForSingleObject(h->thread, INFINITE);
        CloseHandle(h->thread);
#else
        pthread_join(h->thread, NULL);
#endif
    }
    finish(&h->gate);
    memset(h, 0xDD, sizeof(*h));
    free(h);
    increment(&destroyed_count);
}
EXPORT int fixture_waits(handle *h) { return h->polls; }
EXPORT int fixture_destroyed(void) { return get(&destroyed_count); }
EXPORT int fixture_violations(void) { return get(&violation_count); }
EXPORT void fixture_block_destroy(int value) { set(&blocked, value); }
EXPORT const char *fixture_library_path(void) {
#ifdef _WIN32
    static char path[MAX_PATH];
    HMODULE module;
    GetModuleHandleExA(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS |
        GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
        (LPCSTR)&fixture_library_path, &module);
    GetModuleFileNameA(module, path, MAX_PATH);
    return path;
#else
    Dl_info info;
    dladdr((void *)&fixture_library_path, &info);
    return info.dli_fname;
#endif
}
