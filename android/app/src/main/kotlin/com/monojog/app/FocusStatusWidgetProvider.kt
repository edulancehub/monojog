package com.monojog.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

class FocusStatusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        super.onUpdate(context, appWidgetManager, appWidgetIds)
        for (widgetId in appWidgetIds) {
            val views = buildViews(
                context = context,
                isActive = false,
                isBreak = false,
                isPaused = false,
                time = "25:00",
                targetMinutes = 25,
                pomodoroCount = 0
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        fun updateAllWidgets(
            context: Context,
            isActive: Boolean,
            isBreak: Boolean,
            isPaused: Boolean,
            time: String,
            targetMinutes: Int,
            pomodoroCount: Int
        ) {
            val appWidgetManager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, FocusStatusWidgetProvider::class.java)
            val appWidgetIds = appWidgetManager.getAppWidgetIds(componentName)

            for (widgetId in appWidgetIds) {
                val views = buildViews(
                    context = context,
                    isActive = isActive,
                    isBreak = isBreak,
                    isPaused = isPaused,
                    time = time,
                    targetMinutes = targetMinutes,
                    pomodoroCount = pomodoroCount
                )
                appWidgetManager.updateAppWidget(widgetId, views)
            }
        }

        private fun buildViews(
            context: Context,
            isActive: Boolean,
            isBreak: Boolean,
            isPaused: Boolean,
            time: String,
            targetMinutes: Int,
            pomodoroCount: Int
        ): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.monojog_focus_widget)

            val status = when {
                isBreak -> "Break Time"
                isActive && isPaused -> "Focus Paused"
                isActive -> "Focus Running"
                else -> "Ready for Focus"
            }

            views.setTextViewText(R.id.widget_title, "Monojog Focus")
            views.setTextViewText(R.id.widget_status, status)
            views.setTextViewText(R.id.widget_time, time)
            views.setTextViewText(
                R.id.widget_meta,
                "Target ${targetMinutes}m • Sessions $pomodoroCount"
            )

            val launchIntent = Intent(context, MainActivity::class.java)
            val pendingIntent = PendingIntent.getActivity(
                context,
                0,
                launchIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)

            return views
        }
    }
}
