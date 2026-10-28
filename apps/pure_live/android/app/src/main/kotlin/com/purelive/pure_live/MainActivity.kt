package com.purelive.pure_live

import android.os.Build
import android.os.Bundle
import android.window.OnBackInvokedCallback
import android.window.OnBackInvokedDispatcher
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app's activity.
 *
 * `pure_live/predictive_back` is the live room's back arbitration: while a room
 * page holds it (Android 13+'s gesture at overlay priority, so the room runs
 * before Flutter's own pop and before the keyboard), every back is handed to
 * Dart, which leaves the presentation first and the route second.
 *
 * The activity also hands the app's engine to the floating window while the
 * app is left with a room playing (`FloatingRoomOverlay`): the window is the
 * app on screen then, so the lifecycle must not tell Dart it went away.
 */
class MainActivity : FlutterActivity() {
    private var predictiveBackEnabled = false
    private var predictiveBackRegistered = false
    private var predictiveBackChannel: MethodChannel? = null

    private val predictiveBackCallback =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            @Suppress("NewApi")
            OnBackInvokedCallback { dispatchPresentationBack() }
        } else {
            null
        }

    // A new activity while the floating window shows: its own view takes the
    // engine back before Flutter builds a second one.
    override fun onCreate(savedInstanceState: Bundle?) {
        FloatingRoomOverlay.onNewActivity()
        super.onCreate(savedInstanceState)
    }

    // The app's floating window keeps the app on screen; its stopping is ours
    // to report, and only when the window did not take over (see onStop).
    override fun shouldDispatchAppLifecycleState(): Boolean =
        !FloatingRoomOverlay.leaving && !FloatingRoomOverlay.showing

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FloatingRoomOverlay.attach(this, flutterEngine)
        BackgroundGuideChannel.attach(
            MethodChannel(
                flutterEngine.dartExecutor.binaryMessenger,
                "pure_live/background_guide",
            ),
        )
        BackgroundGuideChannel.attachActivity(this)
        predictiveBackChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PREDICTIVE_BACK_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setEnabled" -> {
                        setPredictiveBackEnabled(call.argument<Boolean>("enabled") ?: false)
                        result.success(null)
                    }

                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        FloatingRoomOverlay.detach()
        predictiveBackChannel?.setMethodCallHandler(null)
        predictiveBackChannel = null
        BackgroundGuideChannel.detach()
        super.cleanUpFlutterEngine(flutterEngine)
    }

    /** Home or recents: the small window takes over before the activity stops. */
    override fun onUserLeaveHint() {
        super.onUserLeaveHint()
        FloatingRoomOverlay.onLeaving(this)
    }

    override fun onStart() {
        // Before super, so the engine's resumed state is right when the
        // activity's view draws again.
        FloatingRoomOverlay.onReturn(this)
        super.onStart()
    }

    override fun onStop() {
        super.onStop()
        // The window takes the engine over; only a leave it refused is the app
        // actually going to the background (lifecycle reporting is suppressed
        // meanwhile, see shouldDispatchAppLifecycleState).
        if (FloatingRoomOverlay.leaving && !FloatingRoomOverlay.show(this)) {
            flutterEngine?.lifecycleChannel?.appIsPaused()
        }
    }

    private fun dispatchPresentationBack() {
        if (predictiveBackEnabled) {
            predictiveBackChannel?.invokeMethod("backInvoked", null)
        }
    }

    private fun setPredictiveBackEnabled(enabled: Boolean) {
        if (predictiveBackEnabled == enabled) return
        predictiveBackEnabled = enabled
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (enabled) registerPredictiveBack() else unregisterPredictiveBack()
        }
    }

    @Suppress("NewApi")
    private fun registerPredictiveBack() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || predictiveBackRegistered) return
        val callback = predictiveBackCallback ?: return
        // Flutter registers its callback at DEFAULT; the live room must run
        // first so fullscreen Back leaves fullscreen instead of the route.
        onBackInvokedDispatcher.registerOnBackInvokedCallback(
            OnBackInvokedDispatcher.PRIORITY_OVERLAY,
            callback,
        )
        predictiveBackRegistered = true
    }

    @Suppress("NewApi")
    private fun unregisterPredictiveBack() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU || !predictiveBackRegistered) return
        predictiveBackCallback?.let(onBackInvokedDispatcher::unregisterOnBackInvokedCallback)
        predictiveBackRegistered = false
    }

    @Deprecated("Hardware Back on vendor builds still arrives here; keep the live room's arbitration.")
    @Suppress("DEPRECATION")
    override fun onBackPressed() {
        if (predictiveBackEnabled) {
            dispatchPresentationBack()
            return
        }
        super.onBackPressed()
    }

    private companion object {
        const val PREDICTIVE_BACK_CHANNEL = "pure_live/predictive_back"
    }
}
