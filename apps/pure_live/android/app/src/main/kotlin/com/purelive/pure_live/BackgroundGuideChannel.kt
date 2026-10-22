package com.purelive.pure_live

import android.annotation.SuppressLint
import android.app.Activity
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `pure_live/background_guide` ("后台播放设置"): what this phone does to an app
 * in the background, where an app may read it, and the system pages that
 * change it.
 *
 * - `status`: the build (`Build` fields and the vendors' system properties,
 *   read once), notifications, the battery exemption, Android 9's background
 *   restriction, the Data Saver and the battery saver;
 * - `open {pages}`: opens the first page of the list that opens and answers
 *   its index (-1: none). The vendor pages and their order are Dart's; this
 *   only builds the intents. `{package}` and `{label}` in extras become this
 *   app's package and name.
 */
internal object BackgroundGuideChannel {
    private const val CHANNEL = "pure_live/background_guide"

    private val PROPS = listOf(
        "ro.mi.os.version.name",
        "ro.miui.ui.version.name",
        "ro.build.version.opporom",
        "ro.build.version.oplusrom",
        "ro.build.version.realmeui",
        "ro.oxygen.version",
        "ro.vivo.os.name",
        "ro.vivo.os.version",
        "ro.vivo.os.build.display.id",
        "ro.build.version.emui",
        "hw_sc.build.platform.version",
        "ro.build.version.magic",
        "ro.build.version.oneui",
    )

    @Volatile
    private var props: Map<String, String>? = null

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private val main = Handler(Looper.getMainLooper())

    fun attach(channel: MethodChannel) {
        this.channel = channel
        channel.setMethodCallHandler { call, result -> handle(call, result) }
    }

    fun attachActivity(activity: Activity) {
        this.activity = activity
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        channel = null
        activity = null
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        val context = activity?.applicationContext ?: run {
            result.success(null)
            return
        }
        when (call.method) {
            "status" -> {
                // Reading the properties may take a process the first time.
                Thread {
                    val build = systemProps()
                    main.post { result.success(status(context, build)) }
                }.start()
            }

            "open" -> {
                @Suppress("UNCHECKED_CAST")
                val pages = call.argument<List<Map<String, Any?>>>("pages") ?: emptyList()
                result.success(open(context, pages))
            }

            else -> result.notImplemented()
        }
    }

    private fun status(context: Context, build: Map<String, String>): Map<String, Any?> {
        val notifications = context.getSystemService(Context.NOTIFICATION_SERVICE) as? NotificationManager
        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        val activities = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
        val connectivity = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val restricted = Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && activities?.isBackgroundRestricted == true
        val dataSaver = when (connectivity?.restrictBackgroundStatus) {
            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_ENABLED -> "restricted"
            ConnectivityManager.RESTRICT_BACKGROUND_STATUS_WHITELISTED -> "allowed"
            else -> "off"
        }
        return mapOf(
            "sdk" to Build.VERSION.SDK_INT,
            "manufacturer" to (Build.MANUFACTURER ?: ""),
            "brand" to (Build.BRAND ?: ""),
            "model" to (Build.MODEL ?: ""),
            "display" to (Build.DISPLAY ?: ""),
            "props" to build,
            "notifications" to (notifications?.areNotificationsEnabled() ?: true),
            "batteryUnrestricted" to (power?.isIgnoringBatteryOptimizations(context.packageName) ?: true),
            "backgroundRestricted" to restricted,
            "dataSaver" to dataSaver,
            "powerSave" to (power?.isPowerSaveMode ?: false),
        )
    }

    /** The vendors' properties: `SystemProperties.get`, else one `getprop`. */
    @SuppressLint("PrivateApi")
    private fun systemProps(): Map<String, String> {
        props?.let { return it }
        val read = try {
            val get = Class.forName("android.os.SystemProperties").getMethod("get", String::class.java)
            PROPS.associateWith { (get.invoke(null, it) as? String).orEmpty() }
        } catch (_: Throwable) {
            null
        } ?: getprop()
        props = read
        return read
    }

    private fun getprop(): Map<String, String> = try {
        val process = ProcessBuilder("getprop").redirectErrorStream(true).start()
        val all = process.inputStream.bufferedReader().use { reader ->
            reader.lineSequence().mapNotNull { line ->
                // [ro.mi.os.version.name]: [OS2.0]
                val match = Regex("""^\[(.+?)]: \[(.*)]$""").find(line.trim()) ?: return@mapNotNull null
                match.groupValues[1] to match.groupValues[2]
            }.toMap()
        }
        process.waitFor()
        PROPS.associateWith { all[it].orEmpty() }
    } catch (_: Exception) {
        emptyMap()
    }

    private fun open(context: Context, pages: List<Map<String, Any?>>): Int {
        val starter: Context = activity ?: context
        pages.forEachIndexed { index, page ->
            val intent = intentOf(starter, page) ?: return@forEachIndexed
            try {
                if (starter !is Activity) intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                starter.startActivity(intent)
                return index
            } catch (_: ActivityNotFoundException) {
                // The next one.
            } catch (_: SecurityException) {
                // Not exported on this build: the next one.
            } catch (_: RuntimeException) {
                // A vendor page that refuses its extras: the next one.
            }
        }
        return -1
    }

    private fun intentOf(context: Context, page: Map<String, Any?>): Intent? {
        val action = page["action"] as? String
        val pkg = page["package"] as? String
        val cls = page["class"] as? String
        if (action == null && (pkg == null || cls == null)) return null
        val intent = if (action != null) Intent(action) else Intent()
        if (pkg != null && cls != null) intent.setClassName(pkg, cls)
        if (page["packageUri"] == true) intent.data = Uri.fromParts("package", context.packageName, null)
        val label = context.applicationInfo.loadLabel(context.packageManager).toString()
        (page["extras"] as? Map<*, *>)?.forEach { (key, value) ->
            if (key is String && value is String) {
                intent.putExtra(key, value.replace("{package}", context.packageName).replace("{label}", label))
            }
        }
        return intent
    }
}
