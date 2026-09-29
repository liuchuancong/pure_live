/*
 * Copyright (c) 2023-2026 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
#include <jni.h>
#include <android/native_window_jni.h>
#include <android/log.h>
//#include <vulkan/vulkan.h> // before any mdk header
#include <mdk/Player.h>
#include <mdk/MediaInfo.h>
#include <cassert>
#include <unordered_map>
#include <iostream>
#include <sys/system_properties.h>

using namespace std;

class TexturePlayer final : public mdk::Player
{
public:
    TexturePlayer(jlong handle)
        : mdk::Player(reinterpret_cast<mdkPlayerAPI*>(handle))
    {
    }

    int width = 0;
    int height = 0;
    jobject surface = nullptr;
    void* vo_opaque = nullptr; // can change by TextureRegistry.SurfaceProducer.Callback
    bool directSurface = false; // decoder renders into the surface, no GL renderer
private:
};

static unordered_map<int64_t, shared_ptr<TexturePlayer>> players;


extern "C" {

JNIEXPORT jint JNI_OnLoad(JavaVM *vm, void *reserved) {
    clog << "JNI_OnLoad" << endl;
    mdk::javaVM(vm);
    mdk::SetGlobalOption("profiler.gpu", 1);

    JNIEnv *env = nullptr;
    if (vm->GetEnv((void **) &env, JNI_VERSION_1_4) != JNI_OK || !env) {
        clog << "GetEnv for JNI_VERSION_1_4 failed" << endl;
        return -1;
    }

    return JNI_VERSION_1_4;
}

void JNI_OnUnload(JavaVM *vm, void *reserved) {
    clog << "JNI_OnUnload" << endl;
}
}

extern "C"
JNIEXPORT void JNICALL
Java_com_mediadevkit_fvp_FvpPlugin_nativeSetSurface(JNIEnv *env, jobject thiz, jlong player_handle,
                                                    jlong tex_id, jobject surface, jint w, jint h, jboolean tunnel) {
    if (!player_handle || !surface) {
        if (auto it = players.find(tex_id); it != players.end()) {
            auto& player = it->second;
            auto s = player->surface;
            if (player->directSurface) {
                // Release the codec BEFORE the surface dies, or it wedges
                // (dequeue -10000) and the stream is marked decode-error, so
                // the next surface never shows a frame. Empty list, not a
                // surface-less re-open: that costs ~600ms of codec restart
                // and pipeline re-prime, here on the UI thread inside
                // surfaceDestroyed.
                player->setDecoders(mdk::MediaType::Video, {});
            }
            player->updateNativeSurface(nullptr);
            players.erase(it);
            if (s) {
                env->DeleteGlobalRef(s);
            }
        } else {
            clog << "player not found(already removed?) for textureId " + std::to_string(tex_id) + " surface " + std::to_string((intptr_t)surface) << endl;
        }
        return;
    }
    assert(surface && "null surface");
    auto player = make_shared<TexturePlayer>(player_handle);
    clog << __func__ << endl;
    if (tunnel) {
        // MediaCodec writes into the surface's buffer queue itself: no GL
        // renderer, no EGLConfig, no GPU copy. image=0 drops the AImageReader
        // readback path; dv=1 is needed for Dolby Vision profile 5 on older
        // SDKs. The surface only exists after prepare(), so setDecoders is
        // what forces the re-open that makes it take effect.
        player->surface = env->NewGlobalRef(surface);
        player->directSurface = true;
        player->setDecoders(mdk::MediaType::Video,
            {"AMediaCodec:dv=1:image=0:surface=" + std::to_string((intptr_t)player->surface)});
    } else {
        player->surface = env->NewGlobalRef(surface);
        player->updateNativeSurface(player->surface, w, h);
        player->vo_opaque = player->surface;
    }
    player->width = w;
    player->height = h;
    players[tex_id] = player;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_mediadevkit_fvp_FvpPlugin_nativeSetSurfaceSize(JNIEnv *env, jobject thiz, jlong tex_id,
                                                        jint w, jint h) {
    auto it = players.find(tex_id);
    if (it == players.end()) {
        return;
    }
    auto& player = it->second;
    player->width = w;
    player->height = h;
    // Only the GL renderer draws at the surface size; with tunnel the decoder
    // owns the geometry and the compositor scales its layer.
    if (!player->directSurface && player->surface) {
        player->updateNativeSurface(player->surface, w, h);
    }
}

extern "C"
JNIEXPORT bool JNICALL
MdkIsEmulator()
{
    // run getprop to see all properties
    char v[PROP_VALUE_MAX+1];
    __system_property_get("ro.kernel.qemu", v);
    if (atoi(v) == 1)
        return true;
    __system_property_get("ro.boot.qemu", v);
    if (atoi(v) == 1)
        return true;
    __system_property_get("ro.product.board", v);
    if (strstr(v, "goldfish"))
        return true;
    __system_property_get("ro.hardware.egl", v);
    if (strstr(v, "emulation"))
        return true;
    __system_property_get("ro.hardware", v);
    if (strstr(v, "ranchu"))
        return true;
    __system_property_get("ro.build.characteristics", v);
    if (strstr(v, "emulator"))
        return true;
    return false;
}

extern "C"
JNIEXPORT void* JNICALL
MdkGetPlayerVid(int64_t tex_id)
{
    if (tex_id < 0)
        return nullptr;
    if (const auto it = players.find(tex_id); it != players.end()) {
        const auto& player = it->second;
        return player->vo_opaque;
    }
    return nullptr;
}