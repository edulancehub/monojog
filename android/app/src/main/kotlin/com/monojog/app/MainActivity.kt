package com.monojog.app

import android.app.AlarmManager
import android.app.AppOpsManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import android.app.NotificationManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.monojog.app/focus"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermissions" -> {
                    val permissions = mapOf(
                        "hasUsagePermission" to hasUsageStatsPermission(),
                        "hasOverlayPermission" to hasOverlayPermission()
                    )
                    result.success(permissions)
                }
                "requestUsagePermission" -> {
                    requestUsageStatsPermission()
                    result.success(null)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(null)
                }
                "getInstalledApps" -> {
                    val apps = getInstalledApps()
                    result.success(apps)
                }
                "startFocusMode" -> {
                    val blockedApps = call.argument<List<String>>("blockedApps") ?: listOf()
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 25
                    startFocusMode(blockedApps, durationMinutes)
                    result.success(null)
                }
                "stopFocusMode" -> {
                    stopFocusMode()
                    result.success(null)
                }
                "enableDND" -> {
                    val enabled = enableDndMode()
                    result.success(enabled)
                }
                "disableDND" -> {
                    val disabled = disableDndMode()
                    result.success(disabled)
                }
                "updateHomeWidget" -> {
                    val isActive = call.argument<Boolean>("isActive") ?: false
                    val isBreak = call.argument<Boolean>("isBreak") ?: false
                    val isPaused = call.argument<Boolean>("isPaused") ?: false
                    val time = call.argument<String>("time") ?: "25:00"
                    val targetMinutes = call.argument<Int>("targetMinutes") ?: 25
                    val pomodoroCount = call.argument<Int>("pomodoroCount") ?: 0

                    FocusStatusWidgetProvider.updateAllWidgets(
                        context = this,
                        isActive = isActive,
                        isBreak = isBreak,
                        isPaused = isPaused,
                        time = time,
                        targetMinutes = targetMinutes,
                        pomodoroCount = pomodoroCount
                    )
                    result.success(true)
                }
                "scheduleAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 7
                    val minute = call.argument<Int>("minute") ?: 0
                    scheduleWakeUpAlarm(hour, minute)
                    result.success(true)
                }
                "cancelAlarm" -> {
                    cancelWakeUpAlarm()
                    result.success(true)
                }
                "getSocialMediaApps" -> {
                    val apps = getSocialMediaAppsList()
                    result.success(apps)
                }
                "blockSocialMedia" -> {
                    val durationMinutes = call.argument<Int>("durationMinutes") ?: 60
                    blockSocialMediaApps(durationMinutes)
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun requestUsageStatsPermission() {
        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
    }

    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(
                Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                Uri.parse("package:$packageName")
            )
            startActivity(intent)
        }
    }

    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        val apps = mutableListOf<Map<String, Any>>()
        
        val packages = pm.getInstalledApplications(PackageManager.GET_META_DATA)
        
        for (appInfo in packages) {
            // Skip our own app
            if (appInfo.packageName == packageName) continue
            
            val isSystemApp = (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            
            try {
                val appName = pm.getApplicationLabel(appInfo).toString()
                
                // Skip apps without a launcher intent (background services)
                val launchIntent = pm.getLaunchIntentForPackage(appInfo.packageName)
                if (launchIntent == null && isSystemApp) continue
                
                apps.add(mapOf(
                    "packageName" to appInfo.packageName,
                    "appName" to appName,
                    "isSystemApp" to isSystemApp
                ))
            } catch (e: Exception) {
                // Skip apps that throw exceptions
            }
        }
        
        return apps.sortedBy { it["appName"] as String }
    }

    private fun startFocusMode(blockedApps: List<String>, durationMinutes: Int) {
        val intent = Intent(this, FocusService::class.java).apply {
            action = FocusService.ACTION_START
            putStringArrayListExtra(FocusService.EXTRA_BLOCKED_APPS, ArrayList(blockedApps))
            putExtra(FocusService.EXTRA_DURATION_MINUTES, durationMinutes)
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopFocusMode() {
        val intent = Intent(this, FocusService::class.java).apply {
            action = FocusService.ACTION_STOP
        }
        startService(intent)
    }

    private fun enableDndMode(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            val intent = Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            return false
        }

        return try {
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_NONE)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun disableDndMode(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (!notificationManager.isNotificationPolicyAccessGranted) {
            return false
        }

        return try {
            notificationManager.setInterruptionFilter(NotificationManager.INTERRUPTION_FILTER_ALL)
            true
        } catch (_: Exception) {
            false
        }
    }

    // ── Alarm scheduling ──
    private fun scheduleWakeUpAlarm(hour: Int, minute: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val calendar = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            // If the time has already passed today, schedule for tomorrow
            if (timeInMillis <= System.currentTimeMillis()) {
                add(Calendar.DAY_OF_YEAR, 1)
            }
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (alarmManager.canScheduleExactAlarms()) {
                    alarmManager.setAlarmClock(
                        AlarmManager.AlarmClockInfo(calendar.timeInMillis, pendingIntent),
                        pendingIntent
                    )
                } else {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent
                    )
                }
            } else {
                alarmManager.setAlarmClock(
                    AlarmManager.AlarmClockInfo(calendar.timeInMillis, pendingIntent),
                    pendingIntent
                )
            }
        } catch (_: Exception) {
            // Fallback to inexact alarm
            alarmManager.set(AlarmManager.RTC_WAKEUP, calendar.timeInMillis, pendingIntent)
        }
    }

    private fun cancelWakeUpAlarm() {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(this, AlarmReceiver::class.java)
        val pendingIntent = PendingIntent.getBroadcast(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        alarmManager.cancel(pendingIntent)
    }

    // ── Social media detection & blocking ──
    private val socialMediaPackages = listOf(
        "com.facebook.katana",        // Facebook
        "com.facebook.lite",          // Facebook Lite
        "com.facebook.orca",          // Messenger
        "com.instagram.android",      // Instagram
        "com.google.android.youtube", // YouTube
        "com.zhiliaoapp.musically",   // TikTok
        "com.ss.android.ugc.trill",   // TikTok (variants)
        "com.snapchat.android",       // Snapchat
        "com.twitter.android",        // X/Twitter
        "com.reddit.frontpage",       // Reddit
        "com.pinterest",              // Pinterest
        "com.linkedin.android"        // LinkedIn
    )

    private fun getSocialMediaAppsList(): List<Map<String, Any>> {
        val pm = packageManager
        val installed = mutableListOf<Map<String, Any>>()

        for (pkg in socialMediaPackages) {
            try {
                val appInfo = pm.getApplicationInfo(pkg, 0)
                val appName = pm.getApplicationLabel(appInfo).toString()
                installed.add(mapOf(
                    "packageName" to pkg,
                    "appName" to appName,
                    "isInstalled" to true
                ))
            } catch (_: PackageManager.NameNotFoundException) {
                // Not installed, skip
            }
        }
        return installed
    }

    private fun blockSocialMediaApps(durationMinutes: Int) {
        val pm = packageManager
        val installedSocial = mutableListOf<String>()

        for (pkg in socialMediaPackages) {
            try {
                pm.getApplicationInfo(pkg, 0)
                installedSocial.add(pkg)
            } catch (_: PackageManager.NameNotFoundException) {
                // Not installed
            }
        }

        if (installedSocial.isNotEmpty()) {
            startFocusMode(installedSocial, durationMinutes)
        }
    }
}
