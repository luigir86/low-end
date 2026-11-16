package com.luigir86.low_end

import android.app.Application
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.os.Looper
import androidx.test.core.app.ApplicationProvider
import com.google.common.collect.ImmutableList
import java.time.Duration
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.AudioDeviceInfoBuilder

// Where the sound goes, headphones pulled out and calls (AudioRoute.kt; the
// Dart side is lib/audio/audio_route.dart). The Player pauses when the
// headphones come out, the metronome and Harmony when a call comes, and the
// beat on screen waits for the Bluetooth delay: all of it starts here.
// Android 11 (sdk 30) is the oldest path: no audio-mode listener, so the
// mode is read once a second while the app plays.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [30])
class AudioRouteTest {
    private val channel = "low_end/audio_route"
    private lateinit var app: Application
    private lateinit var dart: FakeMessenger
    private lateinit var manager: AudioManager

    @Before
    fun setUp() {
        forgetAudioRoute()
        app = ApplicationProvider.getApplicationContext()
        manager = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        dart = FakeMessenger()
        AudioRoute.attach(app, dart)
        // Android tells the devices there at once (theRouteIsSentAsSoonAsAttached).
        shadowOf(Looper.getMainLooper()).idle()
        dart.sent.clear()
    }

    /** AudioRoute lives as long as the app; each test starts a new app. */
    private fun forgetAudioRoute() {
        for (name in listOf("context", "channel")) {
            AudioRoute::class.java.getDeclaredField(name).apply { isAccessible = true }.set(null, null)
        }
        AudioRoute::class.java.getDeclaredField("watching").apply { isAccessible = true }.setBoolean(null, false)
        AudioRoute::class.java.getDeclaredField("lastMode").apply { isAccessible = true }
            .setInt(null, AudioManager.MODE_NORMAL)
    }

    private fun device(type: Int): AudioDeviceInfo = AudioDeviceInfoBuilder.newBuilder().setType(type).build()

    private fun sentToDart() = dart.sent.filter { it.first == channel }.map { it.second to it.third }

    private fun runFor(seconds: Long) = shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(seconds))

    @Test
    fun theRouteIsSentAsSoonAsAttached() {
        // A new app, where Android tells the devices already there: Dart
        // learns the route without asking.
        forgetAudioRoute()
        val fresh = FakeMessenger()
        AudioRoute.attach(app, fresh)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf(Triple(channel, "route", "speaker" as Any?)), fresh.sent.distinct())
    }

    @Test
    fun theSpeakerWhenNothingIsPluggedIn() {
        assertEquals("speaker", dart.call(channel, "route"))
    }

    @Test
    fun wiredAndUsbHeadphonesAreWired() {
        for (type in listOf(
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
        )) {
            shadowOf(manager).setOutputDevices(listOf(device(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER), device(type)))
            assertEquals("type $type", "wired", dart.call(channel, "route"))
        }
    }

    @Test
    fun bluetoothWinsOverWiredAndSpeaker() {
        shadowOf(manager).setOutputDevices(
            listOf(
                device(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER),
                device(AudioDeviceInfo.TYPE_WIRED_HEADPHONES),
                device(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP),
            ),
        )
        assertEquals("bluetooth", dart.call(channel, "route"))
    }

    @Test
    fun aBluetoothCallHeadsetAloneIsNotWhereMusicGoes() {
        // A headset connected only for calls (SCO): music stays on the speaker.
        shadowOf(manager).setOutputDevices(
            listOf(device(AudioDeviceInfo.TYPE_BUILTIN_SPEAKER), device(AudioDeviceInfo.TYPE_BLUETOOTH_SCO)),
        )
        assertEquals("speaker", dart.call(channel, "route"))
    }

    @Test
    fun headphonesComingAndGoingTellTheNewRoute() {
        val headset = device(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP)
        shadowOf(manager).addOutputDevice(headset, true)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("route" to "bluetooth"), sentToDart())

        dart.sent.clear()
        shadowOf(manager).removeOutputDevice(headset, true)
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("route" to "speaker"), sentToDart())
    }

    @Test
    fun headphonesPulledOutTellDart() {
        app.sendBroadcast(Intent(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(listOf("noisy" to null), sentToDart())
    }

    @Test
    fun otherBroadcastsAreNotHeadphonesPulledOut() {
        app.sendBroadcast(Intent(Intent.ACTION_HEADSET_PLUG))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(emptyList<Pair<String, Any?>>(), sentToDart())
    }

    @Test
    fun aSecondScreenOnTheSameEngineDoesNotDoubleTheListeners() {
        // The screen opens again (audio_service keeps the engine): Dart gets
        // one "noisy", not two.
        val second = FakeMessenger()
        AudioRoute.attach(app, second)
        app.sendBroadcast(Intent(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        shadowOf(Looper.getMainLooper()).idle()
        assertEquals(1, second.sent.count { it.second == "noisy" })
        assertEquals(0, dart.sent.count { it.second == "noisy" })
    }

    @Test
    fun aCallWhilePlayingTellsDart() {
        dart.call(channel, "watch", true)
        runFor(2)
        assertEquals(emptyList<Pair<String, Any?>>(), sentToDart())

        manager.mode = AudioManager.MODE_RINGTONE
        runFor(1)
        assertEquals(listOf("call" to null), sentToDart())

        // Answered: the same call, not a new one.
        manager.mode = AudioManager.MODE_IN_CALL
        runFor(3)
        assertEquals(1, sentToDart().count { it.first == "call" })
    }

    @Test
    fun aCallAppCountsAsACall() {
        dart.call(channel, "watch", true)
        manager.mode = AudioManager.MODE_IN_COMMUNICATION
        runFor(1)
        assertEquals(listOf("call" to null), sentToDart())
    }

    @Test
    fun aCallAlreadyOnWhenTheSoundStartsIsNotANewOne() {
        manager.mode = AudioManager.MODE_IN_CALL
        dart.call(channel, "watch", true)
        runFor(3)
        assertEquals(emptyList<Pair<String, Any?>>(), sentToDart())

        // It ends, then another comes.
        manager.mode = AudioManager.MODE_NORMAL
        runFor(1)
        manager.mode = AudioManager.MODE_RINGTONE
        runFor(1)
        assertEquals(listOf("call" to null), sentToDart())
    }

    @Test
    fun nothingIsReadWhileNothingPlays() {
        dart.call(channel, "watch", true)
        dart.call(channel, "watch", false)
        manager.mode = AudioManager.MODE_RINGTONE
        runFor(3)
        assertEquals(emptyList<Pair<String, Any?>>(), sentToDart())
    }

    @Test
    fun anUnknownCallIsNotImplemented() {
        assertEquals(FakeMessenger.Failure("notImplemented", null), dart.call(channel, "volume"))
    }
}

// From Android 13 the phone says where music goes.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class AudioRouteAndroid13Test {
    private val channel = "low_end/audio_route"

    @Test
    fun theRouteIsTheOneMusicTakes() {
        for (name in listOf("context", "channel")) {
            AudioRoute::class.java.getDeclaredField(name).apply { isAccessible = true }.set(null, null)
        }
        val app = ApplicationProvider.getApplicationContext<Application>()
        val manager = app.getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val dart = FakeMessenger()
        AudioRoute.attach(app, dart)
        val media = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).build()
        val wired = AudioDeviceInfoBuilder.newBuilder().setType(AudioDeviceInfo.TYPE_WIRED_HEADPHONES).build()
        val bluetooth = AudioDeviceInfoBuilder.newBuilder().setType(AudioDeviceInfo.TYPE_BLUETOOTH_A2DP).build()

        // A Bluetooth headset is connected, but music goes to the wired one.
        shadowOf(manager).setOutputDevices(listOf(wired, bluetooth))
        shadowOf(manager).setAudioDevicesForAttributes(media, ImmutableList.of(wired))
        assertEquals("wired", dart.call(channel, "route"))

        shadowOf(manager).setAudioDevicesForAttributes(media, ImmutableList.of(bluetooth))
        assertEquals("bluetooth", dart.call(channel, "route"))

        // Bluetooth LE Audio (TYPE_BLE_HEADSET) has a delay of its own.
        val ble = AudioDeviceInfoBuilder.newBuilder().setType(26).build()
        shadowOf(manager).setAudioDevicesForAttributes(media, ImmutableList.of(ble))
        assertEquals("ble", dart.call(channel, "route"))
    }
}
