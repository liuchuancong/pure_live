/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Surface;

import java.lang.reflect.Method;
import java.util.Locale;
import java.util.Objects;

import io.flutter.view.TextureRegistry;

public class VideoOutput implements TextureRegistry.SurfaceProducer.Callback {

    private static final String TAG = "VideoOutput";

    /**
     * mpv applies WID changes asynchronously.
     * Delay deleting the JNI global reference to avoid racing with native code.
     */
    private static final long WID_RELEASE_DELAY_MS = 5000L;

    private static final Method newGlobalObjectRef;
    private static final Method deleteGlobalObjectRef;
    private static final Handler handler = new Handler(Looper.getMainLooper());

    static {
        try {
            // com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper is part of package:media_kit_libs_android_video & package:media_kit_libs_android_audio packages.
            // Use reflection to invoke methods of com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper.
            Class<?> mediaKitAndroidHelperClass = Class.forName("com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper");

            newGlobalObjectRef = mediaKitAndroidHelperClass.getDeclaredMethod("newGlobalObjectRef", Object.class);

            deleteGlobalObjectRef = mediaKitAndroidHelperClass.getDeclaredMethod("deleteGlobalObjectRef", long.class);

            newGlobalObjectRef.setAccessible(true);
            deleteGlobalObjectRef.setAccessible(true);

        } catch (Throwable e) {
            Log.i("media_kit", "package:media_kit_libs_android_video missing. " + "Make sure you have added it to pubspec.yaml.");

            throw new RuntimeException("Failed to initialize " + "com.alexmercerind.media_kit_video.VideoOutput.");
        }
    }

    private long id = 0;

    /**
     * Native window id passed to mpv.
     */
    private long wid = 0;

    /**
     * Surface currently referenced by the current WID.
     */
    private Surface referencedSurface;
    private boolean disposed = false;

    private final TextureUpdateCallback textureUpdateCallback;

    private final boolean enableSurfaceProducer;

    /**
     * New Android SurfaceProducer rendering path.
     */
    private final TextureRegistry.SurfaceProducer surfaceProducer;

    /**
     * Legacy SurfaceTexture rendering path.
     */
    private final TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;

    /**
     * Surface created from SurfaceTexture.
     */
    private Surface surfaceTextureSurface;

    /**
     * Last known SurfaceProducer size.
     * <p>
     * Do not rely on surfaceProducer.getWidth()/getHeight()
     * during cleanup because the producer may already be
     * transitioning its lifecycle.
     */
    private int lastSurfaceWidth = 1;
    private int lastSurfaceHeight = 1;

    /**
     * SurfaceTexture size.
     */
    private int surfaceTextureWidth = 1;
    private int surfaceTextureHeight = 1;

    private boolean surfaceTextureNotified = false;

    private final Object lock = new Object();

    VideoOutput(TextureRegistry textureRegistryReference, boolean enableSurfaceProducer, TextureUpdateCallback textureUpdateCallback) {
        this.textureUpdateCallback = textureUpdateCallback;
        this.enableSurfaceProducer = enableSurfaceProducer;

        if (enableSurfaceProducer) {
            Log.i(TAG, "Android video output rendering path: SurfaceProducer");

            surfaceProducer = textureRegistryReference.createSurfaceProducer();

            surfaceProducer.setCallback(this);
            surfaceTextureEntry = null;

        } else {
            Log.i(TAG, "Android video output rendering path: SurfaceTexture");

            surfaceProducer = null;

            surfaceTextureEntry = textureRegistryReference.createSurfaceTexture();

            id = surfaceTextureEntry.id();

            createSurfaceTextureSurface();
        }
    }

    public void dispose() {
        synchronized (lock) {
            if (disposed) {
                return;
            }
            disposed = true;
            if (enableSurfaceProducer) {
                try {
                    surfaceProducer.setCallback(null);
                } catch (Throwable e) {
                    Log.w(TAG, "Unable to clear SurfaceProducer callback", e);
                }
                detachSurfaceReference();
                try {
                    surfaceProducer.release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose SurfaceProducer", e);
                }

            } else {
                onSurfaceTextureCleanup();

                try {
                    surfaceTextureEntry.release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose SurfaceTexture", e);
                }
            }
        }
    }

    public void setSurfaceSize(int width, int height) {
        setSurfaceSize(width, height, false);
    }

    private void setSurfaceSize(int width, int height, boolean force) {
        synchronized (lock) {
            if (disposed || width <= 0 || height <= 0) {
                return;
            }

            if (enableSurfaceProducer) {
                try {
                    if (!force && surfaceProducer.getWidth() == width && surfaceProducer.getHeight() == height) {
                        publishCurrentSurface();
                        return;
                    }
                    surfaceProducer.setSize(width, height);
                    // SurfaceProducer is allowed to replace its Surface after
                    // setSize. Query it again instead of reusing the old JNI
                    // reference while waiting for a lifecycle callback.
                    publishCurrentSurface();
                } catch (Throwable e) {
                    Log.e(TAG, "setSurfaceSize SurfaceProducer", e);
                }

            } else {
                try {
                    if (!force && surfaceTextureNotified && surfaceTextureWidth == width && surfaceTextureHeight == height) {
                        return;
                    }

                    surfaceTextureEntry.surfaceTexture().setDefaultBufferSize(width, height);

                    surfaceTextureWidth = width;
                    surfaceTextureHeight = height;
                    surfaceTextureNotified = true;

                    createSurfaceTextureSurface();

                    textureUpdateCallback.onTextureUpdate(id, wid, surfaceTextureWidth, surfaceTextureHeight);

                } catch (Throwable e) {
                    Log.e(TAG, "setSurfaceSize SurfaceTexture", e);
                }
            }
        }
    }

    @Override
    public void onSurfaceAvailable() {
        synchronized (lock) {
            publishCurrentSurface();
        }
    }

    @Override
    public void onSurfaceCleanup() {
        synchronized (lock) {
            if (disposed) {
                return;
            }
            Log.i(TAG, "onSurfaceCleanup");
            detachSurfaceReference();
        }
    }

    /**
     * Publishes the Surface currently owned by Flutter.
     *
     * Flutter's SurfaceProducer contract explicitly permits getSurface() to
     * return a different Surface after setSize, rotation or background/resume.
     * The Java object and its JNI global reference must therefore be compared
     * and replaced as one transaction before mpv receives the new WID.
     */
    private void publishCurrentSurface() {
        if (disposed || !enableSurfaceProducer) {
            return;
        }
        try {
            final Surface currentSurface = surfaceProducer.getSurface();
            id = surfaceProducer.id();
            if (currentSurface == null || !currentSurface.isValid()) {
                detachSurfaceReference();
                return;
            }

            if (wid == 0 || currentSurface != referencedSurface) {
                // Detach the previous WID before releasing its JNI reference;
                // this keeps mpv from rendering into a retired Surface.
                detachSurfaceReference();
                referencedSurface = currentSurface;
                wid = newGlobalObjectRef(currentSurface);
            }
            textureUpdateCallback.onTextureUpdate(
                    id,
                    wid,
                    surfaceProducer.getWidth(),
                    surfaceProducer.getHeight()
            );
        } catch (Throwable e) {
            Log.e(TAG, "publishCurrentSurface", e);
            detachSurfaceReference();
        }
    }

    private void detachSurfaceReference() {
        if (enableSurfaceProducer) {
            try {
                textureUpdateCallback.onTextureUpdate(
                        id,
                        0,
                        surfaceProducer.getWidth(),
                        surfaceProducer.getHeight()
                );
            } catch (Throwable e) {
                Log.w(TAG, "Unable to detach Surface", e);
            }
        }
        referencedSurface = null;
        releaseWid();
    }

    private void releaseWid() {
        if (wid == 0) {
            return;
        }
        final long widReference = wid;
        wid = 0;
        // mpv applies WID changes asynchronously. Delay deletion while the
        // detached reference is no longer reachable from this owner.
        handler.postDelayed(() -> deleteGlobalObjectRef(widReference), 5000);
    }

    private void createSurfaceTextureSurface() {
        // The SurfaceTexture fallback is only effective with Android's Skia backend.
        if (surfaceTextureSurface != null) {
            return;
        }

        surfaceTextureSurface = new Surface(surfaceTextureEntry.surfaceTexture());

        wid = newGlobalObjectRef(surfaceTextureSurface);

        Log.i(TAG, "createSurfaceTextureSurface: id=" + id + ", wid=" + wid);
    }

    private void onSurfaceTextureCleanup() {
        Log.i(TAG, "onSurfaceTextureCleanup: id=" + id + ", wid=" + wid + ", size=" + surfaceTextureWidth + "x" + surfaceTextureHeight);

        try {
            textureUpdateCallback.onTextureUpdate(id, 0, surfaceTextureWidth, surfaceTextureHeight);
        } catch (Throwable e) {
            Log.w(TAG, "Unable to detach SurfaceTexture", e);
        }

        if (surfaceTextureSurface != null) {
            try {
                surfaceTextureSurface.release();
            } catch (Throwable e) {
                Log.e(TAG, "onSurfaceTextureCleanup release", e);
            }

            surfaceTextureSurface = null;
        }

        if (wid != 0) {
            final long widReference = wid;

            wid = 0;

            Log.i(TAG, "schedule delete SurfaceTexture WID: " + widReference);

            handler.postDelayed(() -> deleteGlobalObjectRef(widReference), WID_RELEASE_DELAY_MS);
        }
    }

    private static long newGlobalObjectRef(Object object) {
        Log.i(TAG, String.format(Locale.ENGLISH, "newGlobalRef: object = %s", object));
        try {
            return (long) Objects.requireNonNull(newGlobalObjectRef.invoke(null, object));
        } catch (Throwable e) {
            Log.e(TAG, "newGlobalRef", e);

            return 0;
        }
    }

    private static void deleteGlobalObjectRef(long ref) {
        Log.i(TAG, String.format(Locale.ENGLISH, "deleteGlobalObjectRef: ref = %d", ref));
        try {
            deleteGlobalObjectRef.invoke(null, ref);
        } catch (Throwable e) {
            Log.e(TAG, "deleteGlobalObjectRef", e);
        }
    }
}
