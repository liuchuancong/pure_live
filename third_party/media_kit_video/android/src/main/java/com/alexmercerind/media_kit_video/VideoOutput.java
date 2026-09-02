package com.alexmercerind.media_kit_video;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.view.Surface;
import java.lang.reflect.Method;
import java.util.HashSet;
import java.util.Locale;
import java.util.Objects;
import io.flutter.view.TextureRegistry;
public class VideoOutput implements TextureRegistry.SurfaceProducer.Callback {
    private static final String TAG = "VideoOutput";
    private static final Method newGlobalObjectRef;
    private static final Method deleteGlobalObjectRef;
    private static final HashSet<Long> deletedGlobalObjectRefs = new HashSet<>();
    private static final Handler handler = new Handler(Looper.getMainLooper());
    static {
        try {
            Class<?> mediaKitAndroidHelperClass = Class.forName("com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper");
            newGlobalObjectRef = mediaKitAndroidHelperClass.getDeclaredMethod("newGlobalObjectRef", Object.class);
            deleteGlobalObjectRef = mediaKitAndroidHelperClass.getDeclaredMethod("deleteGlobalObjectRef", long.class);
            newGlobalObjectRef.setAccessible(true);
            deleteGlobalObjectRef.setAccessible(true);
        } catch (Throwable e) {
            Log.i("media_kit", "package:media_kit_libs_android_video missing. Make sure you have added it to pubspec.yaml.");
            throw new RuntimeException("Failed to initialize com.alexmercerind.media_kit_video.VideoOutput.");
        }
    }
    private long id = 0;
    private long wid = 0;
    private Surface referencedSurface;
    private final TextureUpdateCallback textureUpdateCallback;
    private final boolean enableSurfaceProducer;
    private final TextureRegistry.SurfaceProducer surfaceProducer;
    private final TextureRegistry.SurfaceTextureEntry surfaceTextureEntry;
    private Surface surfaceTextureSurface;
    private int surfaceTextureWidth = 1;
    private int surfaceTextureHeight = 1;
    private boolean surfaceTextureNotified = false;
    private int lastSurfaceWidth = 0;
    private int lastSurfaceHeight = 0;
    private boolean surfaceOrientationPortrait = false;
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
            if (enableSurfaceProducer) {
                try {
                    textureUpdateCallback.onTextureUpdate(id, 0, surfaceProducer.getWidth(), surfaceProducer.getHeight());
                } catch (Throwable ignored) {
                }
                releaseWid();
                referencedSurface = null;
                try {
                    surfaceProducer.getSurface().release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose", e);
                }
                try {
                    surfaceProducer.release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose", e);
                }
            } else {
                onSurfaceTextureCleanup();
                try {
                    surfaceTextureEntry.release();
                } catch (Throwable e) {
                    Log.e(TAG, "dispose", e);
                }
            }
        }
    }
    public void setSurfaceSize(int width, int height) {
        setSurfaceSize(width, height, false);
    }
    private void setSurfaceSize(int width, int height, boolean force) {
        synchronized (lock) {
            if (width <= 0 || height <= 0) {
                return;
            }
            if (enableSurfaceProducer) {
                try {
                    final int oldWidth = surfaceProducer.getWidth();
                    final int oldHeight = surfaceProducer.getHeight();
                    final boolean oldPortrait = oldHeight > oldWidth;
                    final boolean newPortrait = height > width;
                    final boolean orientationChanged = oldWidth > 0 && oldHeight > 0 && oldPortrait != newPortrait;
                    Log.i(TAG, "REQUEST Surface size: " + width + " x " + height + ", aspect=" + String.format(Locale.ENGLISH, "%.4f", (double) width / height));
                    Log.i(TAG, "CURRENT Surface size: " + oldWidth + " x " + oldHeight + ", aspect=" + (oldHeight > 0 ? String.format(Locale.ENGLISH, "%.4f", (double) oldWidth / oldHeight) : "0"));
                    if (!force && oldWidth == width && oldHeight == height && !orientationChanged) {
                        onSurfaceAvailable();
                        return;
                    }
                    if (orientationChanged) {
                        Log.i(TAG, "Surface orientation changed: " + (oldPortrait ? "PORTRAIT" : "LANDSCAPE") + " -> " + (newPortrait ? "PORTRAIT" : "LANDSCAPE"));
                        refreshSurfaceReference();
                    }
                    surfaceProducer.setSize(width, height);
                    lastSurfaceWidth = width;
                    lastSurfaceHeight = height;
                    surfaceOrientationPortrait = newPortrait;
                    Log.i(TAG, "AFTER setSize SurfaceProducer: " + surfaceProducer.getWidth() + " x " + surfaceProducer.getHeight() + ", aspect=" + String.format(Locale.ENGLISH, "%.4f", surfaceProducer.getHeight() > 0 ? (double) surfaceProducer.getWidth() / surfaceProducer.getHeight() : 0.0));
                    onSurfaceAvailable();
                } catch (Throwable e) {
                    Log.e(TAG, "setSurfaceSize", e);
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
                    Log.e(TAG, "setSurfaceSize", e);
                }
            }
        }
    }
    private void refreshSurfaceReference() {
        if (!enableSurfaceProducer) {
            return;
        }
        try {
            textureUpdateCallback.onTextureUpdate(id, 0, surfaceProducer.getWidth(), surfaceProducer.getHeight());
        } catch (Throwable e) {
            Log.e(TAG, "refreshSurfaceReference notify cleanup", e);
        }
        releaseWid();
        referencedSurface = null;
        final Surface currentSurface = surfaceProducer.getSurface();
        if (currentSurface != null) {
            referencedSurface = currentSurface;
            wid = newGlobalObjectRef(currentSurface);
        }
    }
    @Override
    public void onSurfaceAvailable() {
        synchronized (lock) {
            if (!enableSurfaceProducer) {
                return;
            }
            Log.i(TAG, "onSurfaceAvailable");
            id = surfaceProducer.id();
            final Surface currentSurface = surfaceProducer.getSurface();
            if (currentSurface == null) {
                Log.w(TAG, "onSurfaceAvailable: null Surface");
                return;
            }
            if (referencedSurface != currentSurface || wid == 0) {
                if (wid != 0) {
                    releaseWid();
                }
                referencedSurface = currentSurface;
                wid = newGlobalObjectRef(currentSurface);
            }
            final int width = surfaceProducer.getWidth();
            final int height = surfaceProducer.getHeight();
            Log.i(TAG, "Surface available: id=" + id + ", wid=" + wid + ", size=" + width + "x" + height + ", aspect=" + String.format(Locale.ENGLISH, "%.4f", height > 0 ? (double) width / height : 0.0));
            textureUpdateCallback.onTextureUpdate(id, wid, width, height);
        }
    }
    @Override
    public void onSurfaceCleanup() {
        synchronized (lock) {
            if (!enableSurfaceProducer) {
                return;
            }
            Log.i(TAG, "onSurfaceCleanup");
            try {
                textureUpdateCallback.onTextureUpdate(id, 0, surfaceProducer.getWidth(), surfaceProducer.getHeight());
            } catch (Throwable e) {
                Log.e(TAG, "onSurfaceCleanup callback", e);
            }
            referencedSurface = null;
            releaseWid();
        }
    }
    private void releaseWid() {
        if (wid == 0) {
            return;
        }
        final long oldWid = wid;
        wid = 0;
        handler.postDelayed(() -> deleteGlobalObjectRef(oldWid), 5000);
    }
    private void createSurfaceTextureSurface() {
        if (surfaceTextureSurface != null) {
            return;
        }
        surfaceTextureSurface = new Surface(surfaceTextureEntry.surfaceTexture());
        wid = newGlobalObjectRef(surfaceTextureSurface);
    }
    private void onSurfaceTextureCleanup() {
        Log.i(TAG, "onSurfaceTextureCleanup");
        textureUpdateCallback.onTextureUpdate(id, 0, surfaceTextureWidth, surfaceTextureHeight);
        if (surfaceTextureSurface != null) {
            try {
                surfaceTextureSurface.release();
            } catch (Throwable e) {
                Log.e(TAG, "onSurfaceTextureCleanup", e);
            }
            surfaceTextureSurface = null;
        }
        if (wid != 0) {
            final long widReference = wid;
            wid = 0;
            handler.postDelayed(() -> deleteGlobalObjectRef(widReference), 5000);
        }
    }
    private static long newGlobalObjectRef(Object object) {
        try {
            return (long) Objects.requireNonNull(newGlobalObjectRef.invoke(null, object));
        } catch (Throwable e) {
            Log.e(TAG, "newGlobalRef", e);
            return 0;
        }
    }
    private static void deleteGlobalObjectRef(long ref) {
        if (deletedGlobalObjectRefs.contains(ref)) {
            return;
        }
        if (deletedGlobalObjectRefs.size() > 100) {
            deletedGlobalObjectRefs.clear();
        }
        deletedGlobalObjectRefs.add(ref);
        try {
            deleteGlobalObjectRef.invoke(null, ref);
        } catch (Throwable e) {
            Log.e(TAG, "deleteGlobalObjectRef", e);
        }
    }
}