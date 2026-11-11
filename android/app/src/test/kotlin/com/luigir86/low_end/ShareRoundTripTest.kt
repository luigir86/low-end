package com.luigir86.low_end

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Looper
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

// The teacher's take, shared from Low End, must open in the student's Low
// End: what Share sends (TakeFiles, TakeProvider) must be what "Open with
// Low End" takes (the manifest, ReceivedTracks). On 11/11 it was not: the
// take went as a generic file that no app, Low End included, offered to
// open. Each half had its tests; this one ties them together.
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ShareRoundTripTest {
    private lateinit var host: Activity
    private lateinit var dart: FakeMessenger
    private val audio = ByteArray(3000) { (it * 7).toByte() }

    @Before
    fun setUp() {
        forgetProviderFolders()
        host = Robolectric.buildActivity(Activity::class.java).setup().get()
        dart = FakeMessenger()
        TakeFiles.attach(host, dart)
        ReceivedTracks.attach(dart)
        dart.call("low_end/received_tracks", "ready")
        serveTakes(host)
    }

    /** Records a take and shares it as [name]: the intent the other app
     * (WhatsApp) receives. */
    private fun share(name: String): Intent {
        val path = dart.call("low_end/takes", "path", "take 1.m4a") as String
        File(path).writeBytes(audio)
        assertEquals(true, dart.call("low_end/takes", "share", mapOf("path" to path, "name" to name)))
        @Suppress("DEPRECATION")
        return shadowOf(host).nextStartedActivity.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
    }

    private fun lowEndOpens(intent: Intent) = host.packageManager
        .queryIntentActivities(Intent(intent).setPackage(host.packageName), PackageManager.MATCH_DEFAULT_ONLY)
        .any { it.activityInfo.name == MainActivity::class.java.name }

    private fun received(): Map<*, *> {
        ReceivedTracks.worker.submit {}.get()
        shadowOf(Looper.getMainLooper()).idle()
        return dart.sent.single { it.second == "open" }.third as Map<*, *>
    }

    @Test
    fun aSharedTakeCanBeSharedOnToLowEnd() {
        val send = share("Lezione 3")
        // The student shares it on from WhatsApp to Low End.
        assertTrue(lowEndOpens(send))
        assertTrue(ReceivedTracks.take(host, send))
        val track = received()
        assertEquals("Lezione 3.m4a", track["name"])
        assertArrayEquals(audio, File(Uri.parse(track["uri"] as String).path!!).readBytes())
    }

    @Test
    fun aSharedTakeTappedInTheChatOpensWithLowEnd() {
        @Suppress("DEPRECATION")
        val uri = share("Lezione 3").getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
        // WhatsApp keeps the type it was given and opens the document with it.
        val type = host.contentResolver.getType(uri)
        val view = Intent(Intent.ACTION_VIEW).setDataAndType(uri, type)
        assertTrue("Low End is not offered for $type", lowEndOpens(view))
        // Not audio/*: WhatsApp would send it as a nameless voice message.
        assertTrue(type!!.startsWith("audio/").not())
        assertTrue(ReceivedTracks.take(host, view))
        assertEquals("Lezione 3.m4a", received()["name"])
    }
}
