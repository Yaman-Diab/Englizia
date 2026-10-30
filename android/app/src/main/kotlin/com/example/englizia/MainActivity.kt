package com.example.englizia

import android.content.ActivityNotFoundException
import android.content.Intent
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
