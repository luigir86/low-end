package com.luigir86.low_end

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import java.util.concurrent.Executor
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

// Where the sound goes (see lib/audio/audio_route.dart). It lives as long as
// the app, not the screen: the sound plays on with the notification after the
// screen has gone (on Android 11 and older, the back button closes it), and
// headphones pulled out then must still stop it.
object AudioRoute {
    private var context: Context? = null
    private var channel: MethodChannel? = null

    // Headphones pulled out: Android is about to play through the speaker.
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action == AudioManager.ACTION_AUDIO_BECOMING_NOISY) {
                channel?.invokeMethod("noisy", null)
            }
        }
    }

    // Headphones or a Bluetooth headset come or go: the sound's delay changes.
    private val deviceCallback = object : AudioDeviceCallback() {
        override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>) = sendRoute()
        override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>) = sendRoute()
    }

    // A call: the phone rings, or a call is on (a phone call, or a call app
    // such as WhatsApp). Read from the phone's audio mode, which needs no
    // permission: the call's own state would need READ_PHONE_STATE. From
    // Android 12 the phone says when the mode changes; before, it is read
    // once a second, only while the app plays (see "watch").
    private val main = Handler(Looper.getMainLooper())
    private var lastMode = AudioManager.MODE_NORMAL
    private var watching = false
    private val poll = object : Runnable {
        override fun run() {
            if (!watching) return
            onMode(audioManager(context ?: return).mode)
            main.postDelayed(this, 1000)
        }
    }

    private fun onMode(mode: Int) {
        if (isCall(mode) && !isCall(lastMode)) channel?.invokeMethod("call", null)
        lastMode = mode
    }

    // Ringing, in a call, in a call app, screening or redirecting a call:
    // every mode past NORMAL (the negative ones are not modes).
    private fun isCall(mode: Int) = mode > AudioManager.MODE_NORMAL

    // Something plays (or stops): before Android 12, read the mode while it
    // plays. A call already on when the sound starts is not a new one.
    private fun watch(on: Boolean) {
        val ctx = context ?: return
        if (Build.VERSION.SDK_INT >= 31 || on == watching) return
        watching = on
        main.removeCallbacks(poll)
        if (on) {
            lastMode = audioManager(ctx).mode
            main.postDelayed(poll, 1000)
        }
    }

    // Called each time a screen opens on the engine (the same engine, kept
    // by audio_service): the listeners are registered the first time only.
    fun attach(appContext: Context, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "low_end/audio_route").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "route" -> result.success(outputKind())
                    "watch" -> {
                        watch(call.arguments == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        if (context != null) return
        context = appContext
        val noisy = IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY)
        if (Build.VERSION.SDK_INT >= 33) {
            appContext.registerReceiver(noisyReceiver, noisy, Context.RECEIVER_NOT_EXPORTED)
        } else {
            appContext.registerReceiver(noisyReceiver, noisy)
        }
        val manager = audioManager(appContext)
        manager.registerAudioDeviceCallback(deviceCallback, main)
        if (Build.VERSION.SDK_INT >= 31) {
            lastMode = manager.mode
            manager.addOnModeChangedListener(Executor { main.post(it) }) { onMode(it) }
        }
    }

    private fun audioManager(context: Context) =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private fun sendRoute() {
        channel?.invokeMethod("route", outputKind())
    }

    // "bluetooth", "ble", "wired" or "speaker": where music plays now. From
    // Android 13 the phone says so; before, a headset connected is taken to
    // be the one in use, as Android routes media to it.
    private fun outputKind(): String {
        val manager = audioManager(context ?: return "speaker")
        val devices = try {
            if (Build.VERSION.SDK_INT >= 33) {
                val media = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build()
                manager.getAudioDevicesForAttributes(media)
            } else {
                manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).toList()
            }
        } catch (e: RuntimeException) {
            emptyList()
        }
        val types = devices.map { it.type }.toSet()
        return when {
            types.any { it in BLUETOOTH } -> "bluetooth"
            types.any { it in BLE } -> "ble"
            types.any { it in WIRED } -> "wired"
            else -> "speaker"
        }
    }

    private val BLUETOOTH = setOf(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP, AudioDeviceInfo.TYPE_HEARING_AID)

    // TYPE_BLE_HEADSET, TYPE_BLE_SPEAKER (Android 12), TYPE_BLE_BROADCAST
    // (Android 13): plain numbers, so the older phones need not know them.
    private val BLE = setOf(26, 27, 30)
    private val WIRED = setOf(
        AudioDeviceInfo.TYPE_WIRED_HEADSET,
        AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
        AudioDeviceInfo.TYPE_USB_HEADSET,
        AudioDeviceInfo.TYPE_USB_DEVICE,
        AudioDeviceInfo.TYPE_LINE_ANALOG,
    )
}
