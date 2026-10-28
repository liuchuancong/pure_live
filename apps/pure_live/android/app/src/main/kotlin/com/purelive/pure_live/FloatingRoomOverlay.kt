package com.purelive.pure_live

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.util.DisplayMetrics
import android.view.Gravity
import android.view.WindowInsets
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference
import kotlin.math.roundToInt

/**
 * The app's own floating window over the other apps ("离开应用时自动小窗",
 * channel `pure_live/floating_overlay`).
 *
 * When the app is left while a room plays, the app's *one* Flutter engine moves
 * from the activity's view into a small [FlutterView] in a
 * `TYPE_APPLICATION_OVERLAY` window and back on return, so the player, its
 * picture and its danmaku go on untouched — no second engine, no handoff. Dart
 * draws only its floating player while [showing], because the overlay view is
 * exactly the size of the small window.
 *
 * A second engine was tried first (`flutter_overlay_window`): it registers no
 * plugins, so none of the app's video backends (media_kit's texture channel,
 * flv_lzc, better_player) can render in it.
 *
 * Needs "display over other apps" ([permitted]). The app asks for it when the
 * viewer turns the setting on; a leave without it simply leaves the app.
 *
 * Channel: `status`, `openSettings`, `arm {enabled, width, height}` (physical
 * pixels), `move {dx, dy}` (logical pixels), `close`, `backToApp`; to Dart,
 * `changed` (true/false).
 */
object FloatingRoomOverlay {
    const val CHANNEL = "pure_live/floating_overlay"

    private const val MARGIN_DP = 12f

    private var channel: MethodChannel? = null
    private var engine: FlutterEngine? = null
    private var activity = WeakReference<Activity>(null)

    private var armed = false
    private var armedWidth = 0
    private var armedHeight = 0

    /** The app is being left with the window armed: the window takes over. */
    var leaving = false
        private set

    /** The floating window shows. */
    var showing = false
        private set

    private var view: FlutterView? = null
    private var params: WindowManager.LayoutParams? = null

    fun attach(activity: Activity, engine: FlutterEngine) {
        this.activity = WeakReference(activity)
        if (this.engine === engine && channel != null) return
        this.engine = engine
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).apply {
            setMethodCallHandler { call, result ->
                val context = this@FloatingRoomOverlay.activity.get()?.applicationContext
                when (call.method) {
                    "status" -> result.success(context != null && permitted(context))
                    "openSettings" -> result.success(context != null && openSettings(context))
                    "arm" -> {
                        armed = call.argument<Boolean>("enabled") ?: false
                        armedWidth = call.argument<Number>("width")?.toInt() ?: 0
                        armedHeight = call.argument<Number>("height")?.toInt() ?: 0
                        result.success(null)
                    }
                    "move" -> {
                        move(call.argument<Number>("dx")?.toFloat() ?: 0f, call.argument<Number>("dy")?.toFloat() ?: 0f)
                        result.success(null)
                    }
                    "close" -> {
                        close()
                        result.success(null)
                    }
                    "backToApp" -> result.success(context != null && backToApp(context))
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun detach() {
        removeWindow()
        showing = false
        leaving = false
        channel?.setMethodCallHandler(null)
        channel = null
        engine = null
    }

    fun permitted(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    /** Home or recents (`onUserLeaveHint`): the window shows once the activity stops. */
    fun onLeaving(activity: Activity) {
        leaving = armed && armedWidth > 0 && armedHeight > 0 && permitted(activity)
    }

    /** The activity stopped; false when the window did not take over. */
    fun show(activity: Activity): Boolean {
        val engine = engine ?: return false
        if (!leaving) return false
        if (showing) return true
        val context = activity.applicationContext
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val margin = (MARGIN_DP * context.resources.displayMetrics.density).roundToInt()
        val (screenWidth, screenHeight) = screenBounds(context)
        val width = armedWidth.coerceAtMost(screenWidth)
        val height = armedHeight.coerceAtMost(screenHeight)
        @Suppress("DEPRECATION")
        val windowType =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
        val layout = WindowManager.LayoutParams(
            width,
            height,
            windowType,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.OPAQUE,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = screenWidth - width - margin
            y = screenHeight - height - margin - bottomInset(context)
        }
        val overlay = FlutterView(context, FlutterSurfaceView(context))
        return try {
            // One engine, one view: the activity's view lets go first.
            activity.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)?.detachFromFlutterEngine()
            overlay.attachToFlutterEngine(engine)
            windowManager.addView(overlay, layout)
            view = overlay
            params = layout
            showing = true
            // The window is the app on screen now; Dart must not think it went
            // to the background and pause.
            engine.lifecycleChannel.appIsResumed()
            channel?.invokeMethod("changed", true)
            true
        } catch (_: RuntimeException) {
            // Refused (the permission was taken away meanwhile): the app leaves
            // as usual.
            overlay.detachFromFlutterEngine()
            activity.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)?.attachToFlutterEngine(engine)
            leaving = false
            false
        }
    }

    /** The activity comes back: the window goes and the activity's view draws again. */
    fun onReturn(activity: Activity) {
        leaving = false
        if (!showing) return
        removeWindow()
        engine?.let { activity.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)?.attachToFlutterEngine(it) }
        channel?.invokeMethod("changed", false)
    }

    /** A new activity is created while the window shows: its own view takes the engine. */
    fun onNewActivity() {
        leaving = false
        if (!showing) return
        removeWindow()
        channel?.invokeMethod("changed", false)
    }

    /** The window's close: it goes and the app stays behind the other apps. */
    private fun close() {
        armed = false
        leaving = false
        if (!showing) return
        removeWindow()
        engine?.let { activity.get()?.findViewById<FlutterView>(FlutterActivity.FLUTTER_VIEW_ID)?.attachToFlutterEngine(it) }
        channel?.invokeMethod("changed", false)
        engine?.lifecycleChannel?.appIsPaused()
    }

    private fun removeWindow() {
        val overlay = view
        view = null
        params = null
        showing = false
        if (overlay == null) return
        overlay.detachFromFlutterEngine()
        val windowManager = overlay.context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            windowManager.removeView(overlay)
        } catch (_: IllegalArgumentException) {
            // Already gone.
        }
    }

    private fun move(dx: Float, dy: Float) {
        val overlay = view ?: return
        val layout = params ?: return
        if (dx == 0f && dy == 0f) return
        val context = overlay.context
        val density = context.resources.displayMetrics.density
        val (screenWidth, screenHeight) = screenBounds(context)
        // Keep half the window on screen; it is still draggable from there.
        layout.x = (layout.x + dx * density).roundToInt()
            .coerceIn(-layout.width / 2, screenWidth - layout.width / 2)
        layout.y = (layout.y + dy * density).roundToInt()
            .coerceIn(0, maxOf(0, screenHeight - layout.height / 2))
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        try {
            windowManager.updateViewLayout(overlay, layout)
        } catch (_: IllegalArgumentException) {
            // The window went between the drag and this frame.
        }
    }

    private fun backToApp(context: Context): Boolean = try {
        context.startActivity(
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT),
        )
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    private fun openSettings(context: Context): Boolean = try {
        context.startActivity(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${context.packageName}"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
        )
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    /** The screen in pixels. */
    private fun screenBounds(context: Context): Pair<Int, Int> {
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val bounds = windowManager.currentWindowMetrics.bounds
            bounds.width() to bounds.height()
        } else {
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            windowManager.defaultDisplay.getRealMetrics(metrics)
            metrics.widthPixels to metrics.heightPixels
        }
    }

    /** What the navigation bar takes at the bottom, so the window clears it. */
    private fun bottomInset(context: Context): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return 0
        val windowManager = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
        return windowManager.currentWindowMetrics.windowInsets
            .getInsetsIgnoringVisibility(WindowInsets.Type.navigationBars())
            .bottom
    }
}
