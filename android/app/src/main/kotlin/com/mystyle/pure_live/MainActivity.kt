package com.mystyle.purelive

import android.content.Intent
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        startNotificationService()
    }

    override fun onDestroy() {
        super.onDestroy()
        stopNotificationService()
    }

    ///TODO: Call this method via channel after remote notification start
    private fun startNotificationService() {
        try {
            val intent = Intent(this, BetterPlayerService::class.java)
            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
        } catch (_: Exception) {
        }
    }

    ///TODO: Call this method via channel after remote notification stop
    private fun stopNotificationService() {
        try {
            val intent = Intent(this, BetterPlayerService::class.java)
            stopService(intent)
        } catch (_: Exception) {

        }
    }
}