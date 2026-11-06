package com.finavig.finavig

import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.text.TextUtils
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth so
// the App Lock can present the biometric prompt on Android.
class MainActivity : FlutterFragmentActivity() {

    companion object {
        const val CHANNEL = "com.finavig.finavig/notification_listener"
        // Static reference so the NotificationListenerService can send events
        // back to Flutter even when it runs in its own lifecycle.
        var methodChannel: MethodChannel? = null
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "isPermissionGranted" -> {
                    result.success(isNotificationListenerEnabled())
                }
                "requestPermission" -> {
                    openNotificationListenerSettings()
                    result.success(null)
                }
                "openNotificationSettings" -> {
                    openNotificationListenerSettings()
                    result.success(null)
                }
                "startListening" -> {
                    // The listener starts automatically once permission is granted.
                    // We just confirm the permission state.
                    result.success(isNotificationListenerEnabled())
                }
                "stopListening" -> {
                    // Android doesn't let us programmatically stop the listener;
                    // the user must revoke permission in settings. The Dart side
                    // simply ignores incoming notifications when disabled.
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        // Re-check permission when the user returns from system settings.
        methodChannel?.invokeMethod("onPermissionChanged", isNotificationListenerEnabled())
    }

    private fun isNotificationListenerEnabled(): Boolean {
        val flat = Settings.Secure.getString(contentResolver, "enabled_notification_listeners")
        if (TextUtils.isEmpty(flat)) return false
        val componentName = ComponentName(this, FinavigNotificationListener::class.java).flattenToString()
        return flat.split(":").any { it == componentName }
    }

    private fun openNotificationListenerSettings() {
        val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
    }
}
