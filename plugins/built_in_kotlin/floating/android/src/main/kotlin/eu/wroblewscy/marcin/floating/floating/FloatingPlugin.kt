package eu.wroblewscy.marcin.floating.floating

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.Context
import android.content.pm.PackageManager
import android.graphics.Rect
import android.os.Build
import android.util.Rational
import androidx.annotation.NonNull
import androidx.annotation.RequiresApi
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.*
import kotlin.concurrent.fixedRateTimer

/** FloatingPlugin */
class FloatingPlugin : FlutterPlugin, MethodCallHandler, ActivityAware {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  private lateinit var activity: Activity

  override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "floating")
    channel.setMethodCallHandler(this)
    context = flutterPluginBinding.applicationContext
  }

  @RequiresApi(Build.VERSION_CODES.N)
  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "enablePip") {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
        val builder = PictureInPictureParams.Builder()
          .setAspectRatio(
            Rational(
              call.argument("numerator") ?: 16,
              call.argument("denominator") ?: 9
            )
          )
        val sourceRectHintLTRB = call.argument<List<Int>>("sourceRectHintLTRB")
        if (sourceRectHintLTRB?.size == 4) {
          val bounds = Rect(
            sourceRectHintLTRB[0],
            sourceRectHintLTRB[1],
            sourceRectHintLTRB[2],
            sourceRectHintLTRB[3]
          )
          builder.setSourceRectHint(bounds)
        }


        val autoEnable = call.argument<Boolean>("autoEnable") ?: false
        if (autoEnable && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
          builder.setAutoEnterEnabled(true)
          activity.setPictureInPictureParams(builder.build())
          result.success(true)
          return
        } else if (autoEnable && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
          result.error(
            "OnLeavePiP not available",
            "OnLeavePiP is only available on SDK higher than 31",
            "Current SDK: ${Build.VERSION.SDK_INT}, required: >=31"
          )
          return
        }

        result.success(
            activity.enterPictureInPictureMode(builder.build())
        )
      } else {
        result.success(activity.enterPictureInPictureMode())
      }
    } else if (call.method == "pipAvailable") {
      result.success(
          activity.packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
      )
    } else if (call.method == "inPipAlready") {
      result.success(
          activity.isInPictureInPictureMode
      )
    } else if (call.method == "cancelAutoEnable") {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        activity.setPictureInPictureParams(PictureInPictureParams.Builder()
          .setAutoEnterEnabled(false).build())
      }
      result.success(true)
    } else
     {
      result.notImplemented()
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
  }

  override fun onDetachedFromActivity() {}

  override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
    useBinding(binding)
  }

  override fun onAttachedToActivity(binding: ActivityPluginBinding) {
    useBinding(binding)
  }

  override fun onDetachedFromActivityForConfigChanges() {}

  private fun useBinding(binding: ActivityPluginBinding) {
    activity = binding.activity
  }
}
