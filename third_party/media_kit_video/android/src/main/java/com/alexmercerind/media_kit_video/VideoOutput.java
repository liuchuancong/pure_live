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
            /*
             * com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper
             * is provided by:
             *
             * package:media_kit_libs_android_video
             * package:media_kit_libs_android_audio
             */
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

    /**
     * Flutter texture / surface id.
     */
    private long id = 0;

    /**
     * Native window id passed to mpv.
     */
    private long wid = 0;

    /**
     * Surface currently referenced by the current WID.
     */
    private Surface referencedSurface;

    /**
     * Prevent operations after dispose.
     */
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

    /**
     * Protect Surface / WID lifecycle operations.
     */
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

    /**
     * Dispose the video output.
     */
    public void dispose() {
        synchronized (lock) {
            if (disposed) {
                return;
            }

            disposed = true;

            Log.i(TAG, "dispose: id=" + id + ", wid=" + wid + ", producer=" + enableSurfaceProducer);

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

    /**
     * Update SurfaceProducer / SurfaceTexture buffer size.
     */
    public void setSurfaceSize(int width, int height) {
        setSurfaceSize(width, height, false);
    }

    /**
     * Internal Surface size update.
     * <p>
     * For SurfaceProducer:
     * <p>
     * setSize()
     * ↓
     * getSurface()
     * ↓
     * detect Surface replacement
     * ↓
     * create new WID if necessary
     */
    private void setSurfaceSize(int width, int height, boolean force) {
        synchronized (lock) {
            if (disposed || width <= 0 || height <= 0) {
                return;
            }

            if (enableSurfaceProducer) {
                try {
                    final int oldWidth = surfaceProducer.getWidth();
                    final int oldHeight = surfaceProducer.getHeight();

                    Log.i(TAG, "setSurfaceSize: requested=" + width + "x" + height + ", current=" + oldWidth + "x" + oldHeight + ", force=" + force);

                    /*
                     * If the size is already correct, avoid calling
                     * setSize() unnecessarily.
                     *
                     * Still publish the current Surface because Flutter
                     * may have replaced the Surface independently.
                     */
                    if (!force && oldWidth == width && oldHeight == height) {

                        updateLastSurfaceSize(width, height);
                        publishCurrentSurface();

                        return;
                    }

                    /*
                     * Flutter may replace the underlying Surface
                     * when setSize() is called.
                     */
                    surfaceProducer.setSize(width, height);

                    updateLastSurfaceSize(width, height);

                    /*
                     * Query the current Surface again.
                     */
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

    /**
     * Flutter has a valid Surface available.
     */
    @Override
    public void onSurfaceAvailable() {
        synchronized (lock) {
            if (disposed) {
                return;
            }

            Log.i(TAG, "onSurfaceAvailable: id=" + id + ", wid=" + wid);

            publishCurrentSurface();
        }
    }

    /**
     * Flutter is going to clean up the current Surface.
     */
    @Override
    public void onSurfaceCleanup() {
        synchronized (lock) {
            if (disposed) {
                return;
            }

            Log.i(TAG, "onSurfaceCleanup: id=" + id + ", wid=" + wid + ", size=" + lastSurfaceWidth + "x" + lastSurfaceHeight);

            /*
             * Tell native/mpv that the current Surface is no longer valid.
             */
            detachSurfaceReference();
        }
    }

    /**
     * Publish the Surface currently owned by Flutter.
     * <p>
     * SurfaceProducer allows getSurface() to return a different Surface
     * after setSize(), rotation, background/resume, or lifecycle changes.
     * <p>
     * Therefore the Surface object and WID must be updated together.
     */
    private void publishCurrentSurface() {
        if (disposed || !enableSurfaceProducer) {
            return;
        }

        try {
            /*
             * Always query the current Surface.
             */
            final Surface currentSurface = surfaceProducer.getSurface();

            /*
             * Refresh texture id.
             */
            id = surfaceProducer.id();

            /*
             * Read the current size once.
             */
            final int width = surfaceProducer.getWidth();
            final int height = surfaceProducer.getHeight();

            updateLastSurfaceSize(width, height);

            /*
             * Surface may temporarily be null or invalid during
             * Android lifecycle transitions.
             */
            if (currentSurface == null || !currentSurface.isValid()) {

                Log.w(TAG, "publishCurrentSurface: invalid Surface, id=" + id + ", wid=" + wid + ", size=" + width + "x" + height);

                detachSurfaceReference();

                return;
            }

            final boolean surfaceChanged = currentSurface != referencedSurface;

            Log.i(TAG, "publishCurrentSurface: id=" + id + ", oldWid=" + wid + ", surfaceChanged=" + surfaceChanged + ", size=" + width + "x" + height);

            /*
             * Create a new WID when:
             *
             * 1. There is no current WID.
             * 2. Flutter replaced the underlying Surface.
             */
            if (wid == 0 || surfaceChanged) {

                /*
                 * Detach the previous WID first.
                 *
                 * The old WID itself is released asynchronously.
                 */
                detachSurfaceReference();

                /*
                 * Store the new Surface.
                 */
                referencedSurface = currentSurface;

                /*
                 * Create JNI global reference for the new Surface.
                 */
                wid = newGlobalObjectRef(currentSurface);

                Log.i(TAG, "new Surface/WID: id=" + id + ", wid=" + wid + ", size=" + width + "x" + height);
            }

            /*
             * Do not send an invalid WID to native.
             */
            if (wid == 0) {
                Log.e(TAG, "publishCurrentSurface: failed to create WID");

                return;
            }

            /*
             * Publish the current Surface/WID pair.
             */
            textureUpdateCallback.onTextureUpdate(id, wid, width, height);

        } catch (Throwable e) {
            Log.e(TAG, "publishCurrentSurface", e);

            detachSurfaceReference();
        }
    }

    /**
     * Save the last known SurfaceProducer dimensions.
     * <p>
     * This avoids querying SurfaceProducer dimensions during cleanup.
     */
    private void updateLastSurfaceSize(int width, int height) {
        if (width > 0) {
            lastSurfaceWidth = width;
        }

        if (height > 0) {
            lastSurfaceHeight = height;
        }
    }

    /**
     * Detach the current Surface/WID from native/mpv.
     * <p>
     * The WID itself is deleted asynchronously.
     */
    private void detachSurfaceReference() {
        if (enableSurfaceProducer) {
            try {
                textureUpdateCallback.onTextureUpdate(id, 0, lastSurfaceWidth, lastSurfaceHeight);
            } catch (Throwable e) {
                Log.w(TAG, "Unable to detach Surface", e);
            }
        }

        referencedSurface = null;

        releaseWid();
    }

    /**
     * Release the JNI global WID reference after a delay.
     * <p>
     * mpv may process WID changes asynchronously, so deleting the JNI
     * global reference immediately can race with native code.
     */
    private void releaseWid() {
        if (wid == 0) {
            return;
        }

        final long widReference = wid;

        /*
         * Mark the current WID as detached immediately.
         */
        wid = 0;

        Log.i(TAG, "schedule deleteGlobalObjectRef: wid=" + widReference + ", delay=" + WID_RELEASE_DELAY_MS + "ms");

        handler.postDelayed(() -> deleteGlobalObjectRef(widReference), WID_RELEASE_DELAY_MS);
    }

    /**
     * Create the SurfaceTexture Surface used by the legacy path.
     */
    private void createSurfaceTextureSurface() {
        /*
         * Reuse the existing Surface.
         */
        if (surfaceTextureSurface != null) {
            return;
        }

        surfaceTextureSurface = new Surface(surfaceTextureEntry.surfaceTexture());

        wid = newGlobalObjectRef(surfaceTextureSurface);

        Log.i(TAG, "createSurfaceTextureSurface: id=" + id + ", wid=" + wid);
    }

    /**
     * Cleanup legacy SurfaceTexture rendering path.
     */
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

    /**
     * Create JNI global reference.
     */
    private static long newGlobalObjectRef(Object object) {
        Log.i(TAG, String.format(Locale.ENGLISH, "newGlobalRef: object = %s", object));

        try {
            return (long) Objects.requireNonNull(newGlobalObjectRef.invoke(null, object));
        } catch (Throwable e) {
            Log.e(TAG, "newGlobalRef", e);

            return 0;
        }
    }

    /**
     * Delete JNI global reference.
     */
    private static void deleteGlobalObjectRef(long ref) {
        if (ref == 0) {
            return;
        }

        Log.i(TAG, String.format(Locale.ENGLISH, "deleteGlobalObjectRef: ref = %d", ref));

        try {
            deleteGlobalObjectRef.invoke(null, ref);
        } catch (Throwable e) {
            Log.e(TAG, "deleteGlobalObjectRef", e);
        }
    }
}