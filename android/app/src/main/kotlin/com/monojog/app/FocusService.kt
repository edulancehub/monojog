package com.monojog.app

import android.app.*
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import androidx.core.app.NotificationCompat

class FocusService : Service() {
    
    companion object {
        const val ACTION_START = "com.monojog.app.action.START"
        const val ACTION_STOP = "com.monojog.app.action.STOP"
        const val EXTRA_BLOCKED_APPS = "blocked_apps"
        const val EXTRA_DURATION_MINUTES = "duration_minutes"
        
        private const val NOTIFICATION_ID = 1001
        private const val CHANNEL_ID = "focus_mode_channel"
        private const val CHECK_INTERVAL = 500L // Check every 500ms
    }
    
    private var blockedApps: List<String> = listOf()
    private var durationMinutes: Int = 25
    private var isRunning = false
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null
    private var usageStatsManager: UsageStatsManager? = null
    private val handler = Handler(Looper.getMainLooper())
    
    private val checkAppsRunnable = object : Runnable {
        override fun run() {
            if (isRunning) {
                checkForegroundApp()
                handler.postDelayed(this, CHECK_INTERVAL)
            }
        }
    }

    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                blockedApps = intent.getStringArrayListExtra(EXTRA_BLOCKED_APPS) ?: listOf()
                durationMinutes = intent.getIntExtra(EXTRA_DURATION_MINUTES, 25)
                startFocusMode()
            }
            ACTION_STOP -> {
                stopFocusMode()
            }
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Focus Mode",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Notification during Focus Mode"
                setShowBadge(false)
            }
            
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun startFocusMode() {
        isRunning = true
        
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Start monitoring apps
        handler.post(checkAppsRunnable)
        
        // Schedule auto-stop after duration
        handler.postDelayed({
            stopFocusMode()
        }, durationMinutes * 60 * 1000L)
    }

    private fun stopFocusMode() {
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        hideOverlay()
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun createNotification(): Notification {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("মনোযোগ মোড সক্রিয়")
            .setContentText("${blockedApps.size} টি অ্যাপ ব্লক করা আছে")
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .build()
    }

    private fun checkForegroundApp() {
        val foregroundApp = getForegroundApp()
        
        if (foregroundApp != null && blockedApps.contains(foregroundApp)) {
            showOverlay()
        } else {
            hideOverlay()
        }
    }

    private fun getForegroundApp(): String? {
        val endTime = System.currentTimeMillis()
        val beginTime = endTime - 10000 // Last 10 seconds
        
        val usageEvents = usageStatsManager?.queryEvents(beginTime, endTime) ?: return null
        
        var lastForegroundApp: String? = null
        
        while (usageEvents.hasNextEvent()) {
            val event = UsageEvents.Event()
            usageEvents.getNextEvent(event)
            
            if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED) {
                lastForegroundApp = event.packageName
            }
        }
        
        return lastForegroundApp
    }

    private fun showOverlay() {
        if (overlayView != null) return
        
        try {
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                else
                    @Suppress("DEPRECATION")
                    WindowManager.LayoutParams.TYPE_PHONE,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT
            ).apply {
                gravity = Gravity.CENTER
            }

            overlayView = LayoutInflater.from(this).inflate(R.layout.overlay_blocked, null)
            
            // Set the blocked message
            overlayView?.findViewById<TextView>(R.id.tvBlockedMessage)?.text = 
                "এই অ্যাপটি ব্লক করা আছে\nমনোযোগ দিয়ে পড়াশোনা করুন!"
            
            overlayView?.findViewById<TextView>(R.id.btnBackToMonojog)?.setOnClickListener {
                // Open Monojog app
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
            }
            
            windowManager?.addView(overlayView, params)
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun hideOverlay() {
        try {
            overlayView?.let {
                windowManager?.removeView(it)
                overlayView = null
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        hideOverlay()
    }
}
