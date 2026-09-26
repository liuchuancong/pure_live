/*
 * Copyright (c) 2026 WangBin <wbsecg1 at gmail.com>
 */
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
package com.mediadevkit.fvp;

import android.content.Context;
import android.util.Log;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;

import java.util.Map;

import io.flutter.plugin.platform.PlatformView;

/**
 * SurfaceView video output, used when the app requests
 * VideoViewType.platformView.
 *
 * Unlike the Texture path (ImageReader buffers composited inside the app
 * window), a SurfaceView gets its own display layer. On Android TVs that run
 * the UI layer below the panel resolution (e.g. 1080p UI on a 4K panel) this
 * is the only way to present video at full display resolution — see
 * https://developer.android.com/media/media3/ui/surface. It is also the only
 * surface type that can display tunneled (sideband) playback.
 *
 * The surface buffers are fixed to the video resolution, not the view size,
 * so a 4K video scans out at 4K even when the window is 1080p.
 */
public class FvpVideoView implements PlatformView, SurfaceHolder.Callback {
    private final SurfaceView surfaceView;
    private final long playerHandle;
    // Key into the native players map (fvp_plugin.cpp). Texture ids from
    // TextureRegistry count up from 0, platform view ids do too — offset into
    // negative space so the two id families can never collide.
    private final long surfaceId;
    private final int videoWidth;
    private final int videoHeight;
    private final boolean tunnel;
    private boolean released = false;
    // Last size sent natively; setFixedSize makes most callbacks a no-op.
    private int surfaceWidth;
    private int surfaceHeight;

    FvpVideoView(Context context, int viewId, Map<String, Object> params) {
        playerHandle = ((Number) params.get("player")).longValue();
        videoWidth = ((Number) params.get("width")).intValue();
        videoHeight = ((Number) params.get("height")).intValue();
        tunnel = Boolean.TRUE.equals(params.get("tunnel"));
        surfaceId = -1000L - viewId;
        surfaceView = new SurfaceView(context);
        if (videoWidth > 0 && videoHeight > 0) {
            // Buffers at video resolution; the compositor scales the layer to
            // the view's screen rect at scanout, preserving full detail.
            surfaceView.getHolder().setFixedSize(videoWidth, videoHeight);
        }
        surfaceView.getHolder().addCallback(this);
    }

    @Override
    public View getView() {
        return surfaceView;
    }

    @Override
    public void surfaceCreated(SurfaceHolder holder) {
        Log.i("FvpPlugin", "FvpVideoView surfaceCreated, video " + videoWidth + "x" + videoHeight + ", tunnel " + tunnel);
        FvpPlugin.nativeSetSurface(playerHandle, surfaceId, holder.getSurface(), videoWidth, videoHeight, tunnel);
        surfaceWidth = videoWidth;
        surfaceHeight = videoHeight;
        released = false;
    }

    @Override
    public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
        Log.i("FvpPlugin", "FvpVideoView surfaceChanged " + width + "x" + height + " format " + format);
        if (released || (width == surfaceWidth && height == surfaceHeight)) {
            return;
        }
        surfaceWidth = width;
        surfaceHeight = height;
        // Only reached without setFixedSize, where the GL renderer needs it.
        FvpPlugin.nativeSetSurfaceSize(surfaceId, width, height);
    }

    @Override
    public void surfaceDestroyed(SurfaceHolder holder) {
        release();
    }

    @Override
    public void dispose() {
        surfaceView.getHolder().removeCallback(this);
        release();
    }

    private void release() {
        if (released) {
            return;
        }
        released = true;
        FvpPlugin.nativeSetSurface(0, surfaceId, null, -1, -1, tunnel);
    }
}
