package com.example.crisis_match

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val SOS_CHANNEL = "com.crismatch.sos/trigger"
        var methodChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SOS_CHANNEL)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Ensure SOS app can turn on the screen and show above the lock screen
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                    android.view.WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            android.view.WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
            )
        }

        // App was CLOSED — launched by SosSensorService
        if (intent?.getBooleanExtra(SosSensorService.SOS_TRIGGER_EXTRA, false) == true) {
            triggerFlutterSos(2500L) // Wait slightly longer for Flutter Engine to boot
        }
        // Start the sensor service if not already running
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            startForegroundService(Intent(this, SosSensorService::class.java))
        } else {
            startService(Intent(this, SosSensorService::class.java))
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // App was ALIVE (minimized) — brought to foreground by SosSensorService
        if (intent.getBooleanExtra(SosSensorService.SOS_TRIGGER_EXTRA, false)) {
            triggerFlutterSos(0L) // Already alive, no delay needed
        }
    }

    private fun triggerFlutterSos(delayMs: Long) {
        val handler = android.os.Handler(android.os.Looper.getMainLooper())
        var retries = 0
        var retryRunnable: Runnable? = null

        retryRunnable = Runnable {
            methodChannel?.invokeMethod(
                    "sosTrigger",
                    null,
                    object : io.flutter.plugin.common.MethodChannel.Result {
                        override fun success(result: Any?) {}
                        override fun error(
                                errorCode: String,
                                errorMessage: String?,
                                errorDetails: Any?
                        ) {}
                        override fun notImplemented() {
                            if (retries < 10) {
                                retries++
                                retryRunnable?.let { handler.postDelayed(it, 1000L) }
                            }
                        }
                    }
            )
        }

        handler.postDelayed(retryRunnable, delayMs)
    }

    override fun onDestroy() {
        methodChannel = null
        super.onDestroy()
    }
}
