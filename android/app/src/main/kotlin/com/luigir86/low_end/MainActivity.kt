package com.luigir86.low_end

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// AudioServiceActivity shares the Flutter engine with the media notification,
// so that its buttons reach the app while the screen is off.
class MainActivity : AudioServiceActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The volume buttons set the drone's loudness (media volume), even
        // before it starts, rather than the ringer.
        volumeControlStream = AudioManager.STREAM_MUSIC
    }

    // The Player's file chooser answers here; the plugins get the rest.
    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        TrackFiles.onActivityResult(requestCode, resultCode, data)
        @Suppress("DEPRECATION")
        super.onActivityResult(requestCode, resultCode, data)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        AudioRoute.attach(applicationContext, flutterEngine.dartExecutor.binaryMessenger)
        TrackFiles.attach(this, flutterEngine.dartExecutor.binaryMessenger)
        // Android 13+ shows the notification only if the user allows it.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "low_end/notifications")
            .setMethodCallHandler { call, result ->
                if (call.method == "request") {
                    if (Build.VERSION.SDK_INT >= 33 &&
                        checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                        PackageManager.PERMISSION_GRANTED
                    ) {
                        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 1)
                    }
                    result.success(null)
                } else if (call.method == "cancel") {
                    // The media notification, once nothing plays (1124 is
                    // audio_service's id for it).
                    NotificationManagerCompat.from(applicationContext).cancel(1124)
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        // The app's page in the phone settings, to allow the microphone
        // after saying no.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "low_end/app_settings")
            .setMethodCallHandler { call, result ->
                if (call.method == "open") {
                    startActivity(
                        Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", packageName, null),
                        ),
                    )
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
    }
}
