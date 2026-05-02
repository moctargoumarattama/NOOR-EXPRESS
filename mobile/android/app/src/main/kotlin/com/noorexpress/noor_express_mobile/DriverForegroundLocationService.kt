package com.noorexpress.noor_express_mobile

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

class DriverForegroundLocationService : Service() {
    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra(EXTRA_TITLE) ?: DEFAULT_TITLE
        val body = intent?.getStringExtra(EXTRA_BODY) ?: DEFAULT_BODY
        startLocationForeground(buildNotification(title, body))
        isRunning = true
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        stopSelf()
        super.onTaskRemoved(rootIntent)
    }

    override fun onDestroy() {
        isRunning = false
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? {
        return null
    }

    private fun startLocationForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
            return
        }
        startForeground(NOTIFICATION_ID, notification)
    }

    private fun buildNotification(title: String, body: String): Notification {
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            Notification.Builder(this)
        }
        return builder
            .setContentTitle(title)
            .setContentText(body)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentIntent(openAppPendingIntent())
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(Notification.CATEGORY_SERVICE)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .build()
    }

    private fun openAppPendingIntent(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or immutablePendingIntentFlag()
        return PendingIntent.getActivity(this, OPEN_APP_REQUEST_CODE, intent, flags)
    }

    private fun immutablePendingIntentFlag(): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return 0
        }
        return PendingIntent.FLAG_IMMUTABLE
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE)
            as NotificationManager
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        manager.createNotificationChannel(channel)
    }

    companion object {
        @Volatile
        var isRunning = false
            private set

        fun startIntent(context: Context, title: String, body: String): Intent {
            return Intent(context, DriverForegroundLocationService::class.java)
                .putExtra(EXTRA_TITLE, title)
                .putExtra(EXTRA_BODY, body)
        }

        private const val CHANNEL_ID = "driver_location_tracking"
        private const val CHANNEL_NAME = "Suivi chauffeur"
        private const val DEFAULT_TITLE = "Noor Express actif"
        private const val DEFAULT_BODY =
            "Votre position chauffeur est partagee pendant la course."
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_BODY = "body"
        private const val NOTIFICATION_ID = 4101
        private const val OPEN_APP_REQUEST_CODE = 4102
    }
}
