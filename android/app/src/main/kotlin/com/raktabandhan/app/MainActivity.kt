package com.raktabandhan.app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    /**
     * The channels the Cloud Functions push to (functions/src/index.ts,
     * `Channel`). Created on every launch — a no-op once they exist, and
     * users can tune each one separately in system settings. Incoming calls
     * use flutter_callkit_incoming's own channel.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java) ?: return

        val urgentSound = Uri.parse(
            "${ContentResolver.SCHEME_ANDROID_RESOURCE}://$packageName/${R.raw.urgent_alert}"
        )
        val alarmAudio = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()

        manager.createNotificationChannels(
            listOf(
                NotificationChannel("messages", "Messages", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Chat messages and missed calls from the person you're matched with"
                },
                NotificationChannel("requests", "Blood requests", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Nearby requests you can help with, and updates on your own requests"
                },
                NotificationChannel("urgent_alerts", "Urgent alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Loud alert for urgent, compatible requests near you (only if you turned urgent alerts on)"
                    setSound(urgentSound, alarmAudio)
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 400, 200, 400, 200, 400)
                },
                NotificationChannel("general", "Announcements", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "Occasional announcements from the Rakta Bandhan team"
                },
            )
        )
    }
}
