package com.monojog.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class FocusWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    companion object {
        fun updateAppWidget(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetId: Int
        ) {
            val views = RemoteViews(context.packageName, R.layout.widget_focus)

            // Load saved focus data from SharedPreferences
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val todayMinutes = prefs.getInt("flutter.focus_today_minutes", 0)
            val dailyGoal = prefs.getInt("flutter.daily_goal_minutes", 120)
            val streak = prefs.getInt("flutter.current_streak", 0)
            val level = prefs.getInt("flutter.user_level", 1)
            val sessions = prefs.getInt("flutter.sessions_today", 0)

            // Set text values
            views.setTextViewText(R.id.tvFocusMinutes, "$todayMinutes")
            views.setTextViewText(R.id.tvGoalMinutes, "/ $dailyGoal min")
            views.setTextViewText(R.id.tvStreak, "$streak day streak 🔥")
            views.setTextViewText(R.id.tvLevel, "Level $level")
            views.setTextViewText(R.id.tvSessions, "$sessions sessions today")

            // Progress bar
            val progress = if (dailyGoal > 0) (todayMinutes * 100 / dailyGoal).coerceAtMost(100) else 0
            views.setProgressBar(R.id.progressFocus, 100, progress, false)

            // Click -> open app
            val intent = Intent(context, MainActivity::class.java)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val pendingIntent = PendingIntent.getActivity(
                context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widgetRoot, pendingIntent)

            // Start Focus button -> open app to focus tab
            val focusIntent = Intent(context, MainActivity::class.java)
            focusIntent.putExtra("navigate_to", "focus")
            focusIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            val focusPendingIntent = PendingIntent.getActivity(
                context, 1, focusIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.btnStartFocus, focusPendingIntent)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
