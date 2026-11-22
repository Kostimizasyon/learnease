package com.learnese.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

object NotificationFactory {
    const val CHANNEL_ID = "learnese_recording_channel"
    const val NOTIFICATION_ID = 4101
    const val EXTRA_OPEN_ACTIVE_SESSION = "com.learnese.app.OPEN_ACTIVE_SESSION"

    private const val REQUEST_CODE_OPEN_APP = 2001
    private const val REQUEST_CODE_STOP_SESSION = 2002

    fun ensureChannel(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return

        val channel = NotificationChannel(
            CHANNEL_ID,
            "Recording Session",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Shown while Learnese is buffering device audio output."
            setShowBadge(false)
            enableVibration(false)
            setSound(null, null)
        }
        manager.createNotificationChannel(channel)
    }

    fun buildRecordingNotification(
        context: Context,
        bufferSeconds: Int,
        savedClipCount: Int = 0,
    ): Notification {
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_OPEN_ACTIVE_SESSION, true)
        }
        val openPendingIntent = PendingIntent.getActivity(
            context,
            REQUEST_CODE_OPEN_APP,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val stopIntent = Intent(context, RecordingService::class.java).apply {
            action = RecordingService.ACTION_STOP_SESSION
        }
        val stopPendingIntent = PendingIntent.getService(
            context,
            REQUEST_CODE_STOP_SESSION,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val contentText = "Learnese is recording the last ${bufferSeconds}s"
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_stat_learnese)
            .setColor(ContextCompat.getColor(context, R.color.learnese_primary_light))
            .setContentTitle("Learnese")
            .setContentText(contentText)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .setContentIntent(openPendingIntent)
            .addAction(0, "Stop Session", stopPendingIntent)

        if (savedClipCount > 0) {
            val label = if (savedClipCount == 1) "1 clip saved" else "$savedClipCount clips saved"
            builder.setSubText(label)
        }

        return builder.build()
    }
}
