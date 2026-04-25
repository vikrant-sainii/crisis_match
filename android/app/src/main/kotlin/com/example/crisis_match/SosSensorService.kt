package com.example.crisis_match

import android.app.*
import android.content.*
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.*
import androidx.core.app.NotificationCompat

class SosSensorService : Service() {

    companion object {
        const val CHANNEL_ID = "sos_sensor_channel"
        const val ACTION_SOS_BUTTON = "com.example.crisis_match.ACTION_SOS_BUTTON"
        const val SOS_TRIGGER_EXTRA = "SOS_TRIGGER"

        // Shake detection constants
        private const val SHAKE_THRESHOLD_GRAVITY = 2.7f
        private const val SHAKE_SLOP_TIME_MS = 500L
        private const val SHAKE_COUNT_RESET_TIME_MS = 3000L
        private const val REQUIRED_SHAKES = 3
    }

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null

    private var shakeTimestamp: Long = 0
    private var shakeCount: Int = 0
    private var lastDebugTime: Long = 0

    // Receiver to listen for the "SEND SOS" button pressed on the notification
    private val notificationActionReceiver =
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    if (intent.action == ACTION_SOS_BUTTON) {
                        triggerSos()
                    }
                }
            }

    private val sensorListener =
            object : SensorEventListener {
                override fun onSensorChanged(event: SensorEvent) {
                    val x = event.values[0]
                    val y = event.values[1]
                    val z = event.values[2]

                    // G-Force on Z axis (1.0 = resting face up on table)
                    val gZ = z / SensorManager.GRAVITY_EARTH

                    // If we are significantly bouncing the phone up/down along the Z axis
                    if (kotlin.math.abs(gZ - 1.0f) > 1.5f
                    ) { // threshold of 1.5g above/below gravity
                        val now = System.currentTimeMillis()

                        // Reset shake count if too much time has passed
                        if (shakeTimestamp + SHAKE_COUNT_RESET_TIME_MS < now) {
                            shakeCount = 0
                        }

                        // Ignore shakes too close to each other
                        if (shakeTimestamp + SHAKE_SLOP_TIME_MS < now) {
                            shakeTimestamp = now
                            shakeCount++

                            if (shakeCount >= REQUIRED_SHAKES) {
                                shakeCount = 0
                                triggerSos()
                            }
                        }
                    }

                    // Stream debug visualization strictly to Flutter (throttled to 10 FPS)
                    val now = System.currentTimeMillis()
                    if (now - lastDebugTime > 100) {
                        lastDebugTime = now
                        if (MainActivity.methodChannel != null) {
                            val payload = mapOf("gZ" to gZ.toDouble(), "count" to shakeCount)
                            Handler(Looper.getMainLooper()).post {
                                MainActivity.methodChannel?.invokeMethod("sensorDebug", payload)
                            }
                        }
                    }
                }

                override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
            }

    override fun onCreate() {
        super.onCreate()

        // Register receiver for the notification button
        registerReceiver(
                notificationActionReceiver,
                IntentFilter(ACTION_SOS_BUTTON),
                Context.RECEIVER_NOT_EXPORTED
        )

        // Start foreground with the interactive notification
        startForeground(1001, buildNotification())

        // Start Accelerometer listener
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        accelerometer?.let {
            sensorManager.registerListener(sensorListener, it, SensorManager.SENSOR_DELAY_UI)
        }
    }

    private fun triggerSos() {
        // App is alive in background, call flutter directly natively
        if (MainActivity.methodChannel != null) {
            Handler(Looper.getMainLooper()).post {
                MainActivity.methodChannel?.invokeMethod("sosTrigger", null)
            }
            return
        }

        // App was killed, launch via Intent
        val intent =
                packageManager.getLaunchIntentForPackage(packageName)!!.apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    putExtra(SOS_TRIGGER_EXTRA, true)
                }
        try {
            startActivity(intent)
        } catch (e: Exception) {}
    }

    private fun buildNotification(): Notification {
        val chan =
                NotificationChannel(
                        CHANNEL_ID,
                        "CrisisMatch SOS",
                        NotificationManager.IMPORTANCE_HIGH
                )
        getSystemService(NotificationManager::class.java).createNotificationChannel(chan)

        // Create PendingIntent for the "SEND SOS" button
        val sosIntent = Intent(ACTION_SOS_BUTTON)
        val sosPendingIntent =
                PendingIntent.getBroadcast(
                        this,
                        0,
                        sosIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                )

        return NotificationCompat.Builder(this, CHANNEL_ID)
                .setContentTitle("🛡️ SOS Guardian Active")
                .setContentText("Shake violently × 4 or Tap below")
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setOngoing(true)
                .addAction(android.R.drawable.ic_menu_call, "🚨 SEND SOS NOW", sosPendingIntent)
                .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        sensorManager.unregisterListener(sensorListener)
        unregisterReceiver(notificationActionReceiver)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
