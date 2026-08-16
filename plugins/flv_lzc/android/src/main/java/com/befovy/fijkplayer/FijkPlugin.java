//MIT License
//
//Copyright (c) [2019-2020] [Befovy]
//
//Permission is hereby granted, free of charge, to any person obtaining a copy
//of this software and associated documentation files (the "Software"), to deal
//in the Software without restriction, including without limitation the rights
//to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//copies of the Software, and to permit persons to whom the Software is
//furnished to do so, subject to the following conditions:
//
//The above copyright notice and this permission notice shall be included in all
//copies or substantial portions of the Software.
//
//THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//SOFTWARE.

package com.befovy.fijkplayer;

import android.annotation.TargetApi;
import android.app.Activity;
import android.content.Context;
import android.content.pm.ActivityInfo;
import android.content.res.Configuration;
import android.media.AudioAttributes;
import android.media.AudioFocusRequest;
import android.media.AudioManager;
import android.os.Build;
import android.provider.Settings;
import android.text.TextUtils;
import android.util.Log;
import android.util.SparseArray;
import android.view.KeyEvent;
import android.view.WindowManager;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.lang.ref.WeakReference;
import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;
import io.flutter.view.TextureRegistry;
import tv.danmaku.ijk.media.player.IjkMediaPlayer;

/**
 * FijkPlugin
 */
public class FijkPlugin implements MethodCallHandler, FlutterPlugin, ActivityAware, FijkEngine, FijkVolume.VolumeKeyListener, AudioManager.OnAudioFocusChangeListener {

    // show system volume changed UI if no playable player
    // hide system volume changed UI if some players are in playable state
    private static final int NO_UI_IF_PLAYABLE = 0;
    // show system volume changed UI if no start state player
    // hide system volume changed UI if some players are in start state
    private static final int NO_UI_IF_PLAYING = 1;
    // never show system volume changed UI
    @SuppressWarnings("unused")
    private static final int NEVER_SHOW_UI = 2;
    // always show system volume changed UI
    private static final int ALWAYS_SHOW_UI = 3;

    final private SparseArray<FijkPlayer> fijkPlayers = new SparseArray<>();

    private final QueuingEventSink mEventSink = new QueuingEventSink();

    private WeakReference<Activity> mActivity;
    private WeakReference<Context> mContext;
    private FlutterPluginBinding mBinding;

    // Count of playable players
    private int playableCnt = 0;
    // Count of playing players
    private int playingCnt = 0;
    private int volumeUIMode = ALWAYS_SHOW_UI;
    private float volStep = 1.0f / 16.0f;
    private boolean eventListening = false;
    // non-local field prevent GC
    private EventChannel mEventChannel;
    private Object mAudioFocusRequest;
    private boolean mAudioFocusRequested = false;


    // Old plugin registration method removed for compatibility with new Flutter embedding

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        final MethodChannel channel = new MethodChannel(binding.getBinaryMessenger(), "befovy.com/fijk");
        initWithBinding(binding);
        channel.setMethodCallHandler(this);

        // A SurfaceTexture must be registered only after the Flutter engine is
        // fully attached. The upstream attach-time probe created and released
        // one while plugins were still registering. Recent Flutter engines
        // abort that race in platform_view_android.cc, which made cold starts
        // succeed intermittently. Real players allocate their texture lazily
        // from setupSurface after Dart creates a player.

        AudioManager audioManager = audioManager();
        if (audioManager != null) {
            int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
            volStep = Math.max(1.0f / (float) max, volStep);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        mContext = null;
    }

    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        mActivity = new WeakReference<>(binding.getActivity());
        if (mActivity.get() instanceof FijkVolume.CanListenVolumeKey) {
            FijkVolume.CanListenVolumeKey canListenVolumeKey = (FijkVolume.CanListenVolumeKey) mActivity.get();
            canListenVolumeKey.setVolumeKeyListener(this);
        }
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        mActivity = null;
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        mActivity = new WeakReference<>(binding.getActivity());
        if (mActivity.get() instanceof FijkVolume.CanListenVolumeKey) {
            FijkVolume.CanListenVolumeKey canListenVolumeKey = (FijkVolume.CanListenVolumeKey) mActivity.get();
            canListenVolumeKey.setVolumeKeyListener(this);
        }
    }

    @Override
    public void onDetachedFromActivity() {
        mActivity = null;
    }

    @Override
    @Nullable
    public TextureRegistry.SurfaceTextureEntry createSurfaceEntry() {
        if (mBinding != null) {
            return mBinding.getTextureRegistry().createSurfaceTexture();
        }
        return null;
    }

    @Override
    @Nullable
    public BinaryMessenger messenger() {
        if (mBinding != null) {
            return mBinding.getBinaryMessenger();
        }
        return null;
    }

    @Override
    @Nullable
    public Context context() {
        if (mContext != null)
            return mContext.get();
        else
            return null;
    }

    @Nullable
    private Activity activity() {
        if (mActivity != null) {
            return mActivity.get();
        }
        return null;
    }

    @Override
    @Nullable
    public String lookupKeyForAsset(@NonNull String asset, @Nullable String packageName) {
        String path = null;
        if (mBinding != null) {
            if (TextUtils.isEmpty(packageName)) {
                path = mBinding.getFlutterAssets().getAssetFilePathByName(asset);
            } else {
                //noinspection ConstantConditions
                path = mBinding.getFlutterAssets().getAssetFilePathByName(asset, packageName);
            }
        }
        return path;
    }


    // initWithRegistrar method removed for compatibility with new Flutter embedding

    private void initWithBinding(@NonNull FlutterPluginBinding binding) {
        mBinding = binding;
        mContext = new WeakReference<>(binding.getApplicationContext());
        init(binding.getBinaryMessenger());
    }

    /**
     * Maybe call init more than once
     *
     * @param messenger BinaryMessenger from flutter engine
     */
    private void init(BinaryMessenger messenger) {
        if (mEventChannel != null) {
            mEventChannel.setStreamHandler(null);
            mEventSink.setDelegate(null);
        }
        mEventChannel = new EventChannel(messenger, "befovy.com/fijk/event");
        mEventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object o, EventChannel.EventSink eventSink) {
                mEventSink.setDelegate(eventSink);
            }

            @Override
            public void onCancel(Object o) {
                mEventSink.setDelegate(null);
            }
        });

        AudioManager audioManager = audioManager();
        if (audioManager != null) {
            int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
            volStep = Math.max(1.0f / (float) max, volStep);
        }
    }


    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        Activity activity;
        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "init":
                Log.i("FLUTTER", "call init:" + call.arguments.toString());
                result.success(null);
                break;
            case "createPlayer": {
                FijkPlayer fijkPlayer = new FijkPlayer(this, false);
                int playerId = fijkPlayer.getPlayerId();
                fijkPlayers.append(playerId, fijkPlayer);
                result.success(playerId);
                break;
            }
            case "releasePlayer": {
                int pid = -1;
                final Integer arg = call.argument("pid");
                if (arg != null)
                    pid = arg;
                FijkPlayer fijkPlayer = fijkPlayers.get(pid);
                if (fijkPlayer != null) {
                    fijkPlayer.release();
                    fijkPlayers.delete(pid);
                }
                result.success(null);
                break;
            }
            case "logLevel": {
                int level = 500;
                final Integer l = call.argument("level");
                if (l != null)
                    level = l;
                level = level / 100;
                level = Math.max(level, 0);
                level = Math.min(level, 8);
                IjkMediaPlayer.loadLibrariesOnce(null);
                IjkMediaPlayer.setLogLevel(level);
                result.success(null);
                break;
            }
            case "setOrientationPortrait":
                boolean changedPort = false;
                activity = activity();
                if (activity != null) {
                    int current_orientation = activity.getResources().getConfiguration().orientation;
                    if (current_orientation == Configuration.ORIENTATION_LANDSCAPE) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                            activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_USER_PORTRAIT);
                        } else {
                            activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_PORTRAIT);
                        }
                        changedPort = true;
                    }
                }
                result.success(changedPort);
                break;
            case "setOrientationLandscape":
                boolean changedLand = false;
                activity = activity();
                if (activity != null) {
                    int current_orientation = activity.getResources().getConfiguration().orientation;
                    if (current_orientation == Configuration.ORIENTATION_PORTRAIT) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                            activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_USER_LANDSCAPE);
                        } else {
                            activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_SENSOR_LANDSCAPE);
                        }
                        changedLand = true;
                    }
                }
                result.success(changedLand);
                break;
            case "setOrientationAuto":
                activity = activity();
                if (activity != null) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                        activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_FULL_USER);
                    } else {
                        activity.setRequestedOrientation(ActivityInfo.SCREEN_ORIENTATION_FULL_SENSOR);
                    }
                }
                result.success(null);
                break;
            case "setScreenOn":
                boolean screenOn = false;
                if (call.hasArgument("on")) {
                    Boolean on = call.argument("on");
                    screenOn = on != null ? on : false;
                }
                setScreenOn(screenOn);
                result.success(null);
                break;
            case "isScreenKeptOn":
                result.success(isScreenKeptOn());
                break;
            case "brightness":
                float brightnessGot = getScreenBrightness();
                result.success(brightnessGot);
                break;
            case "setBrightness":
                if (call.hasArgument("brightness")) {
                    final Double var = call.argument("brightness");
                    if (var != null) {
                        float brightness = var.floatValue();
                        setScreenBrightness(brightness);
                    }
                }
                break;
            case "requestAudioFocus":
                audioFocus(true);
                result.success(null);
                break;
            case "releaseAudioFocus":
                audioFocus(false);
                result.success(null);
                break;
            case "volumeDown":
                float stepDown = volStep;
                if (call.hasArgument("step")) {
                    final Double step = call.argument("step");
                    stepDown = step != null ? step.floatValue() : stepDown;
                }
                result.success(volumeDown(stepDown));
                break;
            case "volumeUp":
                float stepUp = volStep;
                if (call.hasArgument("step")) {
                    final Double step = call.argument("step");
                    stepUp = step != null ? step.floatValue() : stepUp;
                }
                result.success(volumeUp(stepUp));
                break;
            case "volumeMute":
                result.success(volumeMute());
                break;
            case "systemVolume":
                result.success(systemVolume());
                break;
            case "volumeSet":
                float vol = systemVolume();
                final Double v = call.argument("vol");
                if (v != null) {
                    vol = setSystemVolume(v.floatValue());
                }
                result.success(vol);
                break;
            case "volUiMode":
                final Integer mode = call.argument("mode");
                if (mode != null) {
                    volumeUIMode = mode;
                }
                result.success(null);
                break;
            case "onLoad":
                eventListening = true;
                result.success(null);
                break;
            case "onUnload":
                eventListening = false;
                result.success(null);
                break;
            default:
                Log.w("FLUTTER", "onMethod Call, name: " + call.method);
                result.notImplemented();
                break;
        }
    }


    @Override
    public void onPlayingChange(int delta) {
        playingCnt += delta;
    }

    @Override
    public void onPlayableChange(int delta) {
        playableCnt += delta;
    }

    @Override
    public void onAudioFocusChange(int focusChange) {
        switch (focusChange) {
            case AudioManager.AUDIOFOCUS_GAIN:
                break;
            case AudioManager.AUDIOFOCUS_LOSS:
            case AudioManager.AUDIOFOCUS_LOSS_TRANSIENT:
                mAudioFocusRequested = false;
                mAudioFocusRequest = null;
                break;
        }
        Log.i("FIJKPLAYER", "onAudioFocusChange: " + focusChange);
    }

    /**
     * Set screen on enable or disable
     *
     * @param on true to set keep screen on enable
     *           false to set keep screen on disable
     */
    @Override
    public void setScreenOn(boolean on) {
        Activity activity = activity();
        if (activity == null || activity.getWindow() == null)
            return;
        if (on) {
            activity.getWindow().addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        } else {
            activity.getWindow().clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
        }
    }

    /**
     * Check if screen is kept on
     *
     * @return true if screen is kept on
     */
    private boolean isScreenKeptOn() {
        Activity activity = activity();
        if (activity == null || activity.getWindow() == null)
            return false;
        int flag = activity.getWindow().getAttributes().flags;
        return (flag & WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) != 0;
    }


    private float getScreenBrightness() {
        Activity activity = activity();
        if (activity == null || activity.getWindow() == null)
            return 0;
        float brightness = activity.getWindow().getAttributes().screenBrightness;
        if (brightness < 0) {
            Context context = context();
            Log.w("FIJKPLAYER", "window attribute brightness less than 0");
            try {
                if (context != null) {
                    brightness = Settings.System.getInt(context.getContentResolver(), Settings.System.SCREEN_BRIGHTNESS) / (float) 255;
                }
            } catch (Settings.SettingNotFoundException e) {
                Log.e("FIJKPLAYER", "System brightness settings not found");
                brightness = 1.0f;
            }
        }
        return brightness;
    }

    private void setScreenBrightness(float brightness) {
        Activity activity = activity();
        if (activity == null || activity.getWindow() == null)
            return;
        WindowManager.LayoutParams layoutParams = activity.getWindow().getAttributes();
        layoutParams.screenBrightness = brightness;
        activity.getWindow().setAttributes(layoutParams);
    }

    @TargetApi(26)
    @SuppressWarnings("deprecation")
    private void requestAudioFocus() {
        AudioManager audioManager = audioManager();
        if (audioManager == null)
            return;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            AudioAttributes audioAttributes =
                    new AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_MEDIA)
                            .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                            .build();

            AudioFocusRequest audioFocusRequest =
                    new AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                            .setAudioAttributes(audioAttributes)
                            .setAcceptsDelayedFocusGain(true)
                            .setOnAudioFocusChangeListener(this) // Need to implement listener
                            .build();
            mAudioFocusRequest = audioFocusRequest;
            audioManager.requestAudioFocus(audioFocusRequest);
        } else {
            audioManager.requestAudioFocus(this,
                    AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN);
        }
        mAudioFocusRequested = true;
    }

    @TargetApi(26)
    // @SuppressWarnings("deprecation")
    private void abandonAudioFocus() {
        AudioManager audioManager = audioManager();
        if (audioManager == null)
            return;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            if (mAudioFocusRequest != null) {
                audioManager.abandonAudioFocusRequest((AudioFocusRequest) mAudioFocusRequest);
                mAudioFocusRequest = null;
            }
        } else {
            audioManager.abandonAudioFocus(this);
        }
        mAudioFocusRequested = false;
    }

    /**
     * @param request true to request audio focus
     *                false to release audio focus
     */
    @Override
    public void audioFocus(boolean request) {
        Log.i("FIJKPLAYER", "audioFocus " + (request ? "request" : "release") + " state:" + mAudioFocusRequested);
        if (request && !mAudioFocusRequested) {
            requestAudioFocus();
        } else if (mAudioFocusRequested) {
            abandonAudioFocus();
        }
    }

    @Nullable
    private AudioManager audioManager() {
        Context context = context();
        if (context != null) {
            return (AudioManager) context.getSystemService(Context.AUDIO_SERVICE);
        } else {
            Log.e("FIJKPLAYER", "context null, can't get AudioManager");
            return null;
        }
    }

    private float systemVolume() {
        AudioManager audioManager = audioManager();
        if (audioManager != null) {
            float max = (float) audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
            float vol = (float) audioManager.getStreamVolume(AudioManager.STREAM_MUSIC);
            return vol / max;
        } else {
            return 0.0f;
        }
    }

    private void sendVolumeEvent() {
        if (eventListening) {
            int flag = getVolumeChangeFlag();
            boolean showOsUI = (flag & AudioManager.FLAG_SHOW_UI) > 0;
            Map<String, Object> event = new HashMap<>();
            event.put("event", "volume");
            event.put("sui", showOsUI);
            event.put("vol", systemVolume());
            mEventSink.success(event);
        }
    }

    private float volumeUp(float step) {
        float vol = systemVolume();
        vol = vol + step;
        vol = setSystemVolume(vol);
        return vol;
    }

    private float volumeDown(float step) {
        float vol = systemVolume();
        vol = vol - step;
        vol = setSystemVolume(vol);
        return vol;
    }

    @SuppressWarnings("SameReturnValue")
    private float volumeMute() {
        setSystemVolume(0.0f);
        return 0.0f;
    }

    private int getVolumeChangeFlag() {
        int flag = 0;
        if (volumeUIMode == ALWAYS_SHOW_UI) {
            flag = AudioManager.FLAG_SHOW_UI;
        } else if (volumeUIMode == NO_UI_IF_PLAYING && playingCnt == 0) {
            flag = AudioManager.FLAG_SHOW_UI;
        } else if (volumeUIMode == NO_UI_IF_PLAYABLE && playableCnt == 0) {
            flag = AudioManager.FLAG_SHOW_UI;
        }
        return flag;
    }

    private float setSystemVolume(float vol) {
        int flag = getVolumeChangeFlag();
        AudioManager audioManager = audioManager();
        if (audioManager != null) {
            int max = audioManager.getStreamMaxVolume(AudioManager.STREAM_MUSIC);
            int volIndex = (int) (vol * max);
            volIndex = Math.min(volIndex, max);
            volIndex = Math.max(volIndex, 0);
            audioManager.setStreamVolume(AudioManager.STREAM_MUSIC, volIndex, flag);
            sendVolumeEvent();
            return (float) volIndex / (float) max;
        } else {
            return vol;
        }
    }

    @Override
    public boolean onVolumeKeyDown(int keyCode, KeyEvent event) {
        switch (keyCode) {
            case KeyEvent.KEYCODE_VOLUME_DOWN:
                volumeDown(volStep);
                return true;
            case KeyEvent.KEYCODE_VOLUME_UP:
                volumeUp(volStep);
                return true;
            case KeyEvent.KEYCODE_VOLUME_MUTE:
                volumeMute();
                return true;
        }
        return false;
    }
}
