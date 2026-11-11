package com.luigir86.low_end

import android.app.Activity
import android.content.Intent
import android.net.Uri
import androidx.core.content.FileProvider
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

// Sharing and saving a take (lib/features/player/recording_controls.dart
// asks; TakeFiles does it on the phone). Every bug found on the phone so
// far has a test here: the name lost, the hard link Android refuses, the
// file sent as audio (WhatsApp then drops its name).
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TakeFilesTest {
    private val channel = "low_end/takes"
    private lateinit var host: Activity
    private lateinit var dart: FakeMessenger
    private val audio = ByteArray(4096) { (it % 251).toByte() }

    @Before
    fun setUp() {
        forgetProviderFolders()
        host = Robolectric.buildActivity(Activity::class.java).setup().get()
        dart = FakeMessenger()
        TakeFiles.attach(host, dart)
    }

    /** A take as the recorder leaves it: in the folder "path" gives. */
    private fun record(name: String = "take 20261111-101500.m4a"): String {
        val path = dart.call(channel, "path", name) as String
        File(path).writeBytes(audio)
        return path
    }

    @Test
    fun fileNameKeepsTheNameAndTheExtension() {
        val path = "/x/take 1.m4a"
        assertEquals("Take1_9_nov_2026.m4a", TakeFiles.fileName("Take1_9_nov_2026", path))
        assertEquals("Bass_ line.m4a", TakeFiles.fileName("Bass: line", path))
        assertEquals("a_b_c_.m4a", TakeFiles.fileName("a/b\\c?", path))
        // The extension typed by the person is not doubled.
        assertEquals("Lesson.m4a", TakeFiles.fileName("Lesson.M4A", path))
        // A hidden or empty name falls back to the take's own.
        assertEquals("take 1.m4a", TakeFiles.fileName("...", path))
        assertEquals("take 1.m4a", TakeFiles.fileName("   ", path))
        assertEquals("take 1.m4a", TakeFiles.fileName(null, path))
        assertEquals(80 + ".wav".length, TakeFiles.fileName("x".repeat(200), "/x/t.wav").length)
    }

    @Test
    fun mimeTypeFollowsTheFormat() {
        assertEquals("audio/wav", TakeFiles.mimeType(File("a.wav")))
        assertEquals("audio/mp4", TakeFiles.mimeType(File("a.m4a")))
    }

    @Test
    fun pathRefusesNamesOutsideTheTakesFolder() {
        assertTrue(dart.call(channel, "path", "../evil.m4a") is FakeMessenger.Failure)
        assertTrue(dart.call(channel, "path", "..") is FakeMessenger.Failure)
    }

    @Test
    fun shareSendsACopyAsADocumentWithTheChosenName() {
        val path = record()

        assertEquals(true, dart.call(channel, "share", mapOf("path" to path, "name" to "Bass: line")))

        val chooser = shadowOf(host).nextStartedActivity
        assertEquals(Intent.ACTION_CHOOSER, chooser.action)
        @Suppress("DEPRECATION")
        val send = chooser.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)!!
        assertEquals(Intent.ACTION_SEND, send.action)
        // A document (MP4 file), not audio: WhatsApp keeps the name, and
        // the student can open it with Low End.
        assertEquals("application/mp4", send.type)
        assertTrue(send.flags and Intent.FLAG_GRANT_READ_URI_PERMISSION != 0)
        @Suppress("DEPRECATION")
        val uri = send.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)!!
        assertEquals("content", uri.scheme)
        assertEquals(host.packageName + ".takes", uri.authority)
        assertEquals("Bass_ line.m4a", uri.lastPathSegment)
        assertEquals(uri, send.clipData!!.getItemAt(0).uri)

        // The copy is a file of its own (not a link) with the same sound.
        val copy = File(File(host.cacheDir, "shared-takes"), "Bass_ line.m4a")
        assertArrayEquals(audio, copy.readBytes())
        File(path).delete()
        assertArrayEquals(audio, copy.readBytes())

        // What the other app reads through the provider.
        serveTakes(host)
        assertEquals("application/mp4", host.contentResolver.getType(uri))
        host.contentResolver.openInputStream(uri)!!.use { assertArrayEquals(audio, it.readBytes()) }
    }

    @Test
    fun aTakeSharedAgainWithTheSameNameReplacesTheOldOne() {
        val first = record("take a.m4a")
        assertEquals(true, dart.call(channel, "share", mapOf("path" to first, "name" to "Same")))
        val second = record("take b.m4a")
        File(second).writeBytes(byteArrayOf(1, 2, 3))
        assertEquals(true, dart.call(channel, "share", mapOf("path" to second, "name" to "Same")))
        val copy = File(File(host.cacheDir, "shared-takes"), "Same.m4a")
        assertArrayEquals(byteArrayOf(1, 2, 3), copy.readBytes())
    }

    @Test
    fun shareRefusesFilesThatAreNotTakes() {
        val other = File(host.filesDir, "other.m4a").apply { writeBytes(audio) }
        val answer = dart.call(channel, "share", mapOf("path" to other.path, "name" to "x"))
        assertTrue(answer is FakeMessenger.Failure)
        val missing = dart.call(channel, "share", mapOf("path" to File(File(record()).parent, "gone.m4a").path, "name" to "x"))
        assertTrue(missing is FakeMessenger.Failure)
    }

    @Test
    fun theProviderServesSharedTakesOnly() {
        val shared = File(File(host.cacheDir, "shared-takes"), "Take1.m4a")
        val uri = FileProvider.getUriForFile(host, host.packageName + ".takes", shared)
        assertEquals("content://com.luigir86.low_end.takes/audio/Take1.m4a", uri.toString())
        assertEquals("application/mp4", TakeProvider().getType(uri))
        val elsewhere = File(host.filesDir, "Take1.m4a")
        val refused = runCatching { FileProvider.getUriForFile(host, host.packageName + ".takes", elsewhere) }
        assertTrue(refused.isFailure)
    }

    @Test
    fun saveAsksWhereWithTheChosenNameAndType() {
        val path = record()
        // "save" answers only when the person has chosen where.
        val answer = dart.start(channel, "save", mapOf("path" to path, "name" to "Lesson 3"))

        val ask = shadowOf(host).nextStartedActivity
        assertEquals(Intent.ACTION_CREATE_DOCUMENT, ask.action)
        assertEquals("audio/mp4", ask.type)
        assertEquals("Lesson 3.m4a", ask.getStringExtra(Intent.EXTRA_TITLE))
        assertTrue(ask.categories.contains(Intent.CATEGORY_OPENABLE))
        assertEquals(FakeMessenger.Pending, answer())

        // Saved where the person chose (here a file the provider serves).
        serveTakes(host)
        val shared = File(host.cacheDir, "shared-takes").apply { mkdirs() }
        val where = FileProvider.getUriForFile(host, host.packageName + ".takes", File(shared, "Lesson 3.m4a"))
        TakeFiles.onResult(host, TakeFiles.SAVE, Activity.RESULT_OK, Intent().setData(where))
        waitFor { answer() != FakeMessenger.Pending }
        assertEquals(true, answer())
        assertArrayEquals(audio, File(shared, "Lesson 3.m4a").readBytes())
    }

    @Test
    fun saveCancelledAnswersFalseAndAllowsAnotherSave() {
        val path = record()
        val first = dart.start(channel, "save", mapOf("path" to path, "name" to "x"))
        TakeFiles.onResult(host, TakeFiles.SAVE, Activity.RESULT_CANCELED, null)
        waitFor { first() != FakeMessenger.Pending }
        assertEquals(false, first())
        // Nothing left waiting: a second save is asked again.
        val second = dart.start(channel, "save", mapOf("path" to path, "name" to "x"))
        assertEquals(Intent.ACTION_CREATE_DOCUMENT, shadowOf(host).nextStartedActivity.action)
        TakeFiles.onResult(host, TakeFiles.SAVE, Activity.RESULT_OK, null)
        waitFor { second() != FakeMessenger.Pending }
        assertEquals(false, second())
    }
}
