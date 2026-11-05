package com.example.englizia

import android.content.ActivityNotFoundException
import android.content.Intent
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "englizia/mail_app")
            .setMethodCallHandler { call, result ->
                if (call.method == "open") result.success(openMailApp()) else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "englizia/links")
            .setMethodCallHandler { call, result ->
                val link = call.arguments as? String
                if (call.method == "open" && link != null) result.success(openLink(link)) else result.notImplemented()
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "englizia/screen_awake")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") return@setMethodCallHandler result.notImplemented()
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                }
                result.success(null)
            }
    }

    /** Views a link in the app that handles it (WhatsApp, the browser). */
    private fun openLink(link: String): Boolean = try {
        startActivity(Intent(Intent.ACTION_VIEW, android.net.Uri.parse(link)))
        true
    } catch (_: ActivityNotFoundException) {
        false
    }

    /** Lets the learner pick among the mail apps; false when there is none. */
    private fun openMailApp(): Boolean {
        val mail = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_EMAIL)
        // A chooser with nothing to choose would show an empty sheet.
        if (packageManager.queryIntentActivities(mail, 0).isEmpty()) return false
        return try {
            startActivity(Intent.createChooser(mail, null))
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
