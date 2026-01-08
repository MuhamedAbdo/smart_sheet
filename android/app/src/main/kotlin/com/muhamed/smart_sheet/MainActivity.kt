package com.muhamed.smart_sheet

import android.content.Intent
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.smart_sheet/app_control"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                // 🔄 إعادة تشغيل التطبيق (تعمل على Emulator + Device)
                "restartApp" -> {
                    try {
                        Log.d("APP_CONTROL", "restartApp CALLED")

                        val intent =
                            packageManager.getLaunchIntentForPackage(packageName)

                        intent?.addFlags(
                            Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP
                        )

                        startActivity(intent)
                        result.success(true)

                    } catch (e: Exception) {
                        result.error("RESTART_ERROR", e.message, null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }
}
