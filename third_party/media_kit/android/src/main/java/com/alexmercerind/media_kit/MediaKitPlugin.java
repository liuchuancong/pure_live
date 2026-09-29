package com.alexmercerind.media_kit;

import androidx.annotation.NonNull;
import io.flutter.embedding.engine.plugins.FlutterPlugin;
import com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper;

public final class MediaKitPlugin implements FlutterPlugin {
    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        System.loadLibrary("mpv");
        MediaKitAndroidHelper.setApplicationContextJava(binding.getApplicationContext());
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        // The application context and JVM outlive individual engines.
    }
}
