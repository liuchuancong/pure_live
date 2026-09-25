// Standalone POSIX/Android check of the actual production bridge. No Flutter
// installation or changes to an installed application's data are required.
#include <assert.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>
#include <pthread.h>
#include "dart_native_api.h"

extern void *mpv_create(void);
extern void mpv_set_wakeup_callback(void *, void (*)(void *), void *);
extern void mpv_terminate_destroy(void *);
extern void fixture_start_stress(void *);
extern int fixture_destroyed(void);
extern int fixture_violations(void);
extern void fixture_block_destroy(int);
extern void *media_kit_event_loop_create(void *, void *, void *, void *, int64_t);
extern void media_kit_event_loop_destroy(void *);
extern void media_kit_event_loop_finalize(void *);
extern void media_kit_event_loop_release(void *);

static pthread_mutex_t gate = PTHREAD_MUTEX_INITIALIZER;
static bool port_open, acknowledged;
static int deliveries;

static bool post_message(Dart_Port port, Dart_CObject *message) {
    pthread_mutex_lock(&gate);
    assert(port == 1 && port_open);
    assert(message->type == Dart_CObject_kInt64);
    if (message->value.as_int64 == 0) acknowledged = true;
    else deliveries++;
    pthread_mutex_unlock(&gate);
    return true;
}

int main(void) {
    for (int iteration = 0; iteration < 600; iteration++) {
        pthread_mutex_lock(&gate);
        port_open = true;
        acknowledged = false;
        pthread_mutex_unlock(&gate);
        int before = fixture_destroyed();
        void *handle = mpv_create();
        void *owner = media_kit_event_loop_create(handle,
            (void *)mpv_set_wakeup_callback, (void *)mpv_terminate_destroy,
            (void *)post_message, 1);
        assert(owner);
        fixture_start_stress(handle);
        usleep(1000);
        if (iteration % 3 == 0) {
            media_kit_event_loop_destroy(owner);
            for (int retries = 0; ; retries++) {
                pthread_mutex_lock(&gate);
                bool done = acknowledged;
                pthread_mutex_unlock(&gate);
                if (done) break;
                assert(retries < 10000);
                usleep(1000);
            }
            media_kit_event_loop_release(owner);
        } else {
            if (iteration % 3 == 1) {
                fixture_block_destroy(1);
                media_kit_event_loop_destroy(owner);
            }
            media_kit_event_loop_finalize(owner);
            pthread_mutex_lock(&gate);
            port_open = false;
            pthread_mutex_unlock(&gate);
            fixture_block_destroy(0);
        }
        for (int retries = 0; fixture_destroyed() != before + 1; retries++) {
            assert(retries < 10000);
            usleep(1000);
        }
        assert(fixture_violations() == 0);
    }
    printf("PASS: 600 native lifecycles, %d wakeups, %d destroyed, %d violations\n",
           deliveries, fixture_destroyed(), fixture_violations());
    return 0;
}
