package com.example.premia

import android.content.Intent
import android.provider.CalendarContract
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // FLAG_SECURE blocks screenshots / screen recording and blanks the
        // recents thumbnail. Toggled from Dart while a premiere is playing.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "premia/screen_protection")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "disable" -> {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    }
                    "isCaptured" -> result.success(false)
                    "addCalendarEvent" -> {
                        try {
                            val title = call.argument<String>("title") ?: "Premia Premiere"
                            val description = call.argument<String>("description") ?: ""
                            val location = call.argument<String>("location") ?: "Premia Digital Cinema"
                            val beginTime = call.argument<Number>("beginTime")?.toLong() ?: System.currentTimeMillis()
                            val endTime = call.argument<Number>("endTime")?.toLong() ?: (beginTime + 7200000L)

                            val intent = Intent(Intent.ACTION_INSERT).apply {
                                data = CalendarContract.Events.CONTENT_URI
                                putExtra(CalendarContract.Events.TITLE, title)
                                putExtra(CalendarContract.Events.DESCRIPTION, description)
                                putExtra(CalendarContract.Events.EVENT_LOCATION, location)
                                putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, beginTime)
                                putExtra(CalendarContract.EXTRA_EVENT_END_TIME, endTime)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.success(false)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
