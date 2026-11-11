package com.luigir86.low_end

import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Looper
import androidx.core.content.FileProvider
import java.io.File
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config

// "Open with Low End": a track sent by the teacher on WhatsApp, or found in
// the files app, opens in the Player (ReceivedTracks, the manifest's intent
// filters, lib/audio/system_track_files_io.dart receivedTracks).
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ReceivedTracksTest {
    private val content = Uri.parse("content://com.whatsapp.provider.media/item/42")

    @Before
    fun setUp() = forgetProviderFolders()

    /** Waits for the copies under way and runs what they post. */
    private fun finishReceiving() {
        ReceivedTracks.worker.submit {}.get()
        shadowOf(Looper.getMainLooper()).idle()
    }

    @Test
    fun audioOfTakesViewedAndSharedFiles() {
        // WhatsApp and the files app often leave the type out of the intent.
        assertEquals(content, ReceivedTracks.audioOf(Intent(Intent.ACTION_VIEW, content)))
        assertEquals(content, ReceivedTracks.audioOf(Intent(Intent.ACTION_VIEW).setDataAndType(content, "audio/mpeg")))
        val file = Uri.parse("file:///sdcard/Music/a.mp3")
        assertEquals(file, ReceivedTracks.audioOf(Intent(Intent.ACTION_VIEW, file)))
        val send = Intent(Intent.ACTION_SEND).setType("audio/mpeg").putExtra(Intent.EXTRA_STREAM, content)
        assertEquals(content, ReceivedTracks.audioOf(send))
    }

    @Test
    fun audioOfLeavesEverythingElseAlone() {
        // The app's own links run actions, they are not files.
        assertNull(ReceivedTracks.audioOf(Intent(Intent.ACTION_VIEW, Uri.parse("lowend://action/drone_play?note=A"))))
        assertNull(ReceivedTracks.audioOf(Intent(Intent.ACTION_MAIN)))
        assertNull(ReceivedTracks.audioOf(Intent(Intent.ACTION_SEND).setType("audio/mpeg")))
        assertNull(ReceivedTracks.audioOf(Intent(Intent.ACTION_VIEW)))
        assertNull(ReceivedTracks.audioOf(null))
    }

    @Test
    fun theManifestOffersLowEndForAudioOnly() {
        val host = Robolectric.buildActivity(Activity::class.java).setup().get()
        val packages = host.packageManager
        fun opens(intent: Intent) = packages.queryIntentActivities(intent.setPackage(host.packageName), PackageManager.MATCH_DEFAULT_ONLY)
            .any { it.activityInfo.name == MainActivity::class.java.name }

        assertTrue(opens(Intent(Intent.ACTION_VIEW).setDataAndType(content, "audio/mpeg")))
        assertTrue(opens(Intent(Intent.ACTION_VIEW).setDataAndType(content, "audio/mp4")))
        assertTrue(opens(Intent(Intent.ACTION_VIEW).setDataAndType(content, "application/ogg")))
        assertTrue(opens(Intent(Intent.ACTION_SEND).setType("audio/x-wav")))
        assertTrue(opens(Intent(Intent.ACTION_VIEW, Uri.parse("lowend://action/drone_play"))))
        assertTrue(!opens(Intent(Intent.ACTION_VIEW).setDataAndType(content, "image/jpeg")))
        assertTrue(!opens(Intent(Intent.ACTION_SEND).setType("text/plain")))
    }

    @Test
    fun aReceivedFileIsCopiedAndHandedToThePlayer() {
        val host = Robolectric.buildActivity(Activity::class.java).setup().get()
        val dart = FakeMessenger()
        ReceivedTracks.attach(dart)
        // Another app lends a file through its provider, with no audio type
        // (this one is the app's own provider, which says
        // application/octet-stream, as WhatsApp's often does).
        serveTakes(host)
        val lent = File(host.cacheDir, "shared-takes").apply { mkdirs() }
        val sound = ByteArray(1000) { it.toByte() }
        File(lent, "Lesson 3.mp3").writeBytes(sound)
        val uri = FileProvider.getUriForFile(host, host.packageName + ".takes", File(lent, "Lesson 3.mp3"))

        // Before the Player listens (the app is still starting) it waits.
        ReceivedTracks.receive(host, uri)
        finishReceiving()
        val waiting = dart.call("low_end/received_tracks", "ready") as List<*>
        val track = waiting.single() as Map<*, *>
        assertEquals("Lesson 3.mp3", track["name"])
        assertEquals(1000L, (track["size"] as Number).toLong())
        val copy = File(Uri.parse(track["uri"] as String).path!!)
        assertArrayEquals(sound, copy.readBytes())
        // The other app takes its file back: the Player keeps its copy.
        File(lent, "Lesson 3.mp3").delete()
        assertArrayEquals(sound, copy.readBytes())
        assertEquals(copy.canonicalFile, ReceivedTracks.copyOf(host, Uri.fromFile(copy)))
        assertNull(ReceivedTracks.copyOf(host, Uri.fromFile(File(host.filesDir, "x.mp3"))))
        assertNull(ReceivedTracks.copyOf(host, Uri.parse(track["uri"] as String).buildUpon().scheme("content").build()))

        // Once it listens, the next file goes straight to it.
        File(lent, "Scale.m4a").writeBytes(sound)
        ReceivedTracks.receive(host, FileProvider.getUriForFile(host, host.packageName + ".takes", File(lent, "Scale.m4a")))
        finishReceiving()
        val (channel, _, arguments) = dart.sent.single { it.second == "open" }
        assertEquals("low_end/received_tracks", channel)
        assertEquals("Scale.m4a", (arguments as Map<*, *>)["name"])
    }

    @Test
    fun aFileThatCannotBeReadIsDropped() {
        val host = Robolectric.buildActivity(Activity::class.java).setup().get()
        val dart = FakeMessenger()
        ReceivedTracks.attach(dart)
        dart.call("low_end/received_tracks", "ready")
        ReceivedTracks.receive(host, Uri.parse("content://nobody.here/a.mp3"))
        finishReceiving()
        // Nothing is opened and no folder is left.
        assertTrue(dart.sent.none { it.second == "open" })
        assertTrue(ReceivedTracks.folder(host).listFiles().orEmpty().all { it.listFiles().orEmpty().isNotEmpty() })
    }
}
