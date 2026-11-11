package com.luigir86.low_end

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

// "Open with Low End": an audio file opened or shared from another app (a
// track a teacher sent on WhatsApp, an attachment in the mail) opens in the
// Player (lib/audio/system_track_files_io.dart, receivedTracks).
//
// The other app lends the file only for a moment, so it is copied into the
// app's own files (received/<random>/<name>); the Player lets the copy go
// with the track (TrackFiles.release), and remembers it like any track.
object ReceivedTracks {
    internal val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var ready = false
    private val waiting = mutableListOf<Map<String, Any?>>()

    fun attach(messenger: BinaryMessenger) {
        // A new engine (the activity made again) has no Player listening yet.
        ready = false
        val opened = MethodChannel(messenger, "low_end/received_tracks")
        opened.setMethodCallHandler { call, result ->
            if (call.method == "ready") {
                // The Player listens: the files that came before it are its.
                ready = true
                result.success(waiting.toList())
                waiting.clear()
            } else {
                result.notImplemented()
            }
        }
        channel = opened
    }

    fun folder(host: Activity) = File(host.filesDir, "received")

    /** The audio file [intent] brings, if it brings one. The manifest lets
     * only audio through (and lowend:// links, which are not files), and
     * the type is often not in the intent itself: the system found it by
     * asking the other app, so it is not checked again here. */
    fun audioOf(intent: Intent?): Uri? {
        intent ?: return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> intent.data?.takeIf { it.scheme == "content" || it.scheme == "file" }
            Intent.ACTION_SEND -> stream(intent)
            else -> null
        }
    }

    @Suppress("DEPRECATION")
    private fun stream(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    /** Copies the file [uri] while the other app still lends it, then
     * hands it to the Player. */
    fun receive(host: Activity, uri: Uri) {
        worker.execute {
            val track = try {
                copy(host, uri)
            } catch (e: Exception) {
                Log.w("LowEnd", "A file from another app could not be copied: $uri", e)
                null
            }
            main.post {
                if (track == null) return@post
                val opened = channel
                if (ready && opened != null) {
                    opened.invokeMethod("open", track)
                } else {
                    waiting += track
                }
            }
        }
    }

    private fun copy(host: Activity, uri: Uri): Map<String, Any?> {
        var name: String? = null
        host.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
            ?.use { cursor ->
                if (cursor.moveToFirst() && !cursor.isNull(0)) name = cursor.getString(0)
            }
        val safe = (name ?: uri.lastPathSegment ?: "audio")
            .substringAfterLast('/')
            .replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_")
            .trim()
            .trimStart('.')
            .take(120)
            .ifEmpty { "audio" }
        val dir = File(folder(host), UUID.randomUUID().toString())
        dir.mkdirs()
        val target = File(dir, safe)
        try {
            requireNotNull(host.contentResolver.openInputStream(uri)).use { input ->
                target.outputStream().use { input.copyTo(it) }
            }
        } catch (e: Exception) {
            dir.deleteRecursively()
            throw e
        }
        return mapOf(
            "uri" to Uri.fromFile(target).toString(),
            "name" to safe,
            "size" to target.length(),
        )
    }

    /** Whether [uri] is a received copy, and the copy if so. */
    fun copyOf(host: Activity, uri: Uri): File? {
        if (uri.scheme != "file") return null
        val file = File(uri.path ?: return null).canonicalFile
        val root = folder(host).canonicalFile
        return if (file.parentFile?.parentFile == root) file else null
    }
}
