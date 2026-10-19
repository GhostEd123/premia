package com.example.premia

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
                    else -> result.notImplemented()
                }
            }
    }
}
