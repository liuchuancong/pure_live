// Copyright (c) media_kit contributors. MIT license.
// mpv retains only native code; isolate shutdown finalizes its owner.
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include "dart_native_api.h"

#ifdef _WIN32
#include <windows.h>
#define MK_EXPORT __declspec(dllexport)
typedef CRITICAL_SECTION mk_mutex;
typedef CONDITION_VARIABLE mk_condition;
static void mutex_init(mk_mutex *m) { InitializeCriticalSection(m); }
static void mutex_lock(mk_mutex *m) { EnterCriticalSection(m); }
static void mutex_unlock(mk_mutex *m) { LeaveCriticalSection(m); }
static void mutex_destroy(mk_mutex *m) { DeleteCriticalSection(m); }
static void condition_init(mk_condition *c) { InitializeConditionVariable(c); }
static void condition_wait(mk_condition *c, mk_mutex *m) {
    SleepConditionVariableCS(c, m, INFINITE);
}
static void condition_signal(mk_condition *c) { WakeConditionVariable(c); }
static void condition_destroy(mk_condition *c) { (void)c; }
#else
#include <pthread.h>
#define MK_EXPORT __attribute__((visibility("default"))) __attribute__((used))
typedef pthread_mutex_t mk_mutex;
typedef pthread_cond_t mk_condition;
static void mutex_init(mk_mutex *m) { pthread_mutex_init(m, NULL); }
static void mutex_lock(mk_mutex *m) { pthread_mutex_lock(m); }
static void mutex_unlock(mk_mutex *m) { pthread_mutex_unlock(m); }
static void mutex_destroy(mk_mutex *m) { pthread_mutex_destroy(m); }
static void condition_init(mk_condition *c) { pthread_cond_init(c, NULL); }
static void condition_wait(mk_condition *c, mk_mutex *m) { pthread_cond_wait(c, m); }
static void condition_signal(mk_condition *c) { pthread_cond_signal(c); }
static void condition_destroy(mk_condition *c) { pthread_cond_destroy(c); }
#endif

typedef void (*set_wakeup_fn)(void *, void (*)(void *), void *);
typedef void (*destroy_fn)(void *);
typedef bool (*post_fn)(Dart_Port, Dart_CObject *);

typedef struct {
    void *handle;
    set_wakeup_fn set_wakeup;
    destroy_fn destroy;
    post_fn post;
    Dart_Port port;
    mk_mutex mutex;
    mk_condition condition;
    // One reference for NativeFinalizer and one for the cleanup worker.
    unsigned references;
    bool stopped;
    bool closing;
} mk_event_loop;

static void release(mk_event_loop *loop) {
    mutex_lock(&loop->mutex);
    const bool last = --loop->references == 0;
    mutex_unlock(&loop->mutex);
    if (last) {
        condition_destroy(&loop->condition);
        mutex_destroy(&loop->mutex);
        free(loop);
    }
}

// Requires the mutex: finalization clears port before the VM can shut down.
static void post(mk_event_loop *loop, int64_t value) {
    if (loop->port != 0) {
        Dart_CObject message = {0};
        message.type = Dart_CObject_kInt64;
        message.value.as_int64 = value;
        loop->post(loop->port, &message);
    }
}

static void wakeup(void *opaque) {
    mk_event_loop *loop = opaque;
    mutex_lock(&loop->mutex);
    if (!loop->stopped) post(loop, 1);
    mutex_unlock(&loop->mutex);
}

MK_EXPORT void media_kit_event_loop_stop(mk_event_loop *loop) {
    mutex_lock(&loop->mutex);
    const bool was_stopped = loop->stopped;
    loop->stopped = true;
    mutex_unlock(&loop->mutex);
    // Unregister outside our mutex to avoid inversion with mpv's wakeup lock.
    // This call waits for any in-flight wakeup to return.
    if (!was_stopped) loop->set_wakeup(loop->handle, NULL, NULL);
}

static void destroy_on_worker(mk_event_loop *loop) {
    mutex_lock(&loop->mutex);
    while (!loop->closing) condition_wait(&loop->condition, &loop->mutex);
    mutex_unlock(&loop->mutex);
    loop->destroy(loop->handle);
    mutex_lock(&loop->mutex);
    post(loop, 0);
    mutex_unlock(&loop->mutex);
    release(loop);
}

#ifdef _WIN32
static DWORD WINAPI worker(void *opaque) {
    destroy_on_worker(opaque);
    return 0;
}
#else
static void *worker(void *opaque) {
    destroy_on_worker(opaque);
    return NULL;
}
#endif

MK_EXPORT mk_event_loop *media_kit_event_loop_create(
    void *handle, set_wakeup_fn set_wakeup, destroy_fn destroy,
    post_fn post_message, Dart_Port port) {
    mk_event_loop *loop = calloc(1, sizeof(*loop));
    if (!loop) return NULL;
    loop->handle = handle;
    loop->set_wakeup = set_wakeup;
    loop->destroy = destroy;
    loop->post = post_message;
    loop->port = port;
    loop->references = 2;
    mutex_init(&loop->mutex);
    condition_init(&loop->condition);
    // Finalization must neither allocate a thread nor run mpv teardown itself.
#ifdef _WIN32
    HANDLE thread = CreateThread(NULL, 0, worker, loop, 0, NULL);
    const bool started = thread != NULL;
    if (started) CloseHandle(thread);
#else
    pthread_t thread;
    const bool started = pthread_create(&thread, NULL, worker, loop) == 0;
    if (started) pthread_detach(thread);
#endif
    if (!started) {
        condition_destroy(&loop->condition);
        mutex_destroy(&loop->mutex);
        free(loop);
        return NULL;
    }
    set_wakeup(handle, wakeup, loop);
    return loop;
}

MK_EXPORT void media_kit_event_loop_destroy(mk_event_loop *loop) {
    media_kit_event_loop_stop(loop);
    mutex_lock(&loop->mutex);
    loop->closing = true;
    condition_signal(&loop->condition);
    mutex_unlock(&loop->mutex);
}

// GC and isolate shutdown allow no Dart API calls here.
MK_EXPORT void media_kit_event_loop_finalize(void *opaque) {
    mk_event_loop *loop = opaque;
    mutex_lock(&loop->mutex);
    loop->port = 0;
    mutex_unlock(&loop->mutex);
    media_kit_event_loop_destroy(loop);
    release(loop);
}

MK_EXPORT void media_kit_event_loop_release(mk_event_loop *loop) {
    release(loop);
}
