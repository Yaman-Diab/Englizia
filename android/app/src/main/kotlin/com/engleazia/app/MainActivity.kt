package com.engleazia.app

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
        // While a lesson's video shows: no screenshot, no recording (they come
        // out black), and no preview among the recent apps.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "englizia/screen_secure")
            .setMethodCallHandler { call, result ->
                if (call.method != "set") return@setMethodCallHandler result.notImplemented()
                if (call.arguments == true) {
                    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                } else {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
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

    /**
     * Opens the mail app, or lets the learner pick when there are several;
     * false when there is none. Each opens as the launcher opens it, in its own
     * task: a mail app's Back from its inbox sends its task to the background,
     * and inside ours it would take the app with it.
     */
    private fun openMailApp(): Boolean {
        val mail = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_APP_EMAIL)
        val apps = packageManager.queryIntentActivities(mail, 0)
            .map { it.activityInfo.packageName }
            .distinct()
            .mapNotNull { packageManager.getLaunchIntentForPackage(it) }
            .onEach { it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK) }
        // A chooser with nothing to choose would show an empty sheet.
        if (apps.isEmpty()) return false
        val open = if (apps.size == 1) {
            apps.first()
        } else {
            Intent.createChooser(apps.first(), null)
                .putExtra(Intent.EXTRA_INITIAL_INTENTS, apps.drop(1).toTypedArray())
        }
        return try {
            startActivity(open)
            true
        } catch (_: ActivityNotFoundException) {
            false
        }
    }
}
