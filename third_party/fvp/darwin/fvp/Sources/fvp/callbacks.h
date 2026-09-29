// Copyright 2022-2026 Wang Bin. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#pragma once
#include <stdbool.h>
#include <stdint.h>

 #ifdef __cplusplus
 #define FVP_EXTERN_C extern "C"
 #else
 #define FVP_EXTERN_C extern
 #endif

#ifdef _WIN32
#define FVP_EXPORT FVP_EXTERN_C __declspec(dllexport)
#else
#define FVP_EXPORT FVP_EXTERN_C __attribute__((visibility("default"))) // will be built with objc compiler, c++ attribute can not be used
#endif

FVP_EXPORT void MdkSetKey(const char* key);
FVP_EXPORT void MdkCallbacksRegisterPort(int64_t handle, void* post_c_object, int64_t send_port);
FVP_EXPORT void MdkCallbacksUnregisterPort(int64_t handle);
FVP_EXPORT void MdkCallbacksRegisterType(int64_t handle, int type, bool reply);
FVP_EXPORT void MdkCallbacksUnregisterType(int64_t handle, int type);
FVP_EXPORT void MdkCallbacksReplyType(int64_t handle, int type, const void* data);
FVP_EXPORT bool MdkPrepare(int64_t handle, int64_t pos, int64_t seekFlag, void* post_c_object, int64_t send_port);// prepare() with a callback to post result to dart to set Completer<int>
FVP_EXPORT bool MdkSeek(int64_t handle, int64_t pos, int64_t seekFlag, void* post_c_object, int64_t send_port);
FVP_EXPORT bool MdkSnapshot(int64_t handle, int64_t texId, int w, int h, void* post_c_object, int64_t send_port);

enum CallbackType {
    Event, // not a callback, no need to wait for reply
    State,
    MediaStatus,
    Prepared,
    Sync,
    Log,
    Seek,       // no register, one time callback
    Snapshot,   // no register, one time callback
    SubtitleText,
    Count,
};

// Callback data from dart if callback has return type or out parameters
union CallbackReply {
    struct {
        bool ret;
    } mediaStatus;
    struct {
        double ret;
    } sync;
    struct {
        bool ret;
        bool boost;
    } prepared;
};
