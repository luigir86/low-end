package com.luigir86.low_end

import android.app.Activity
import android.content.Intent
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

// The Player's files (see lib/audio/track_files.dart): the system's document
// chooser, which needs no permission, and the right to read the file chosen,
// kept so that it can be opened again.
object TrackFiles {
    private const val REQUEST_PICK = 4601

    private var activity: Activity? = null
    private var pending: MethodChannel.Result? = null

    // Reading tags can take a while (a slow card, a cloud file): off the main
    // thread, and one at a time.
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    // Called each time a screen opens on the engine. A chooser left over from
    // a screen that is gone can no longer answer: it is closed with no choice.
    fun attach(activity: Activity, messenger: BinaryMessenger) {
        this.activity = activity
        pending?.success(null)
        pending = null
        MethodChannel(messenger, "low_end/track_files").setMethodCallHandler { call, result ->
            when (call.method) {
                "pick" -> pick(result)
                "canRead" -> canRead(call.argument<String>("uri"), result)
                "tags" -> tags(call.argument<String>("uri"), result)
                "release" -> release(call.argument<String>("uri"), result)
                else -> result.notImplemented()
            }
        }
    }

    private fun pick(result: MethodChannel.Result) {
        val host = activity
        if (host == null) {
            result.success(null)
            return
        }
        if (pending != null) {
            result.error("busy", "The file chooser is already open.", null)
            return
        }
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "audio/*"
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
        }
        host.startActivityForResult(intent, REQUEST_PICK)
    }

    // From MainActivity.onActivityResult.
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK) return
        val result = pending ?: return
        pending = null
        val uri = if (resultCode == Activity.RESULT_OK) data?.data else null
        val host = activity
        if (uri == null || host == null) {
            result.success(null)
            return
        }
        try {
            host.contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        } catch (e: SecurityException) {
            // The permission lasts for this session only; it can be played now.
        }
        result.success(describe(host, uri))
    }

    // Can the track still be opened after a restart: the right to read it was
    // kept (the system may have dropped it) and the file is still there.
    private fun canRead(uri: String?, result: MethodChannel.Result) {
        val host = activity
        if (uri == null || host == null) {
            result.success(false)
            return
        }
        worker.execute {
            val readable = try {
                val target = Uri.parse(uri)
                val kept = host.contentResolver.persistedUriPermissions
                    .any { it.uri == target && it.isReadPermission }
                kept && host.contentResolver.openFileDescriptor(target, "r")?.use { true } == true
            } catch (e: Exception) {
                false
            }
            main.post { result.success(readable) }
        }
    }

    // The title and the artist written in the file, whatever its format.
    private fun tags(uri: String?, result: MethodChannel.Result) {
        val host = activity
        if (uri == null || host == null) {
            result.success(mapOf("title" to null, "artist" to null))
            return
        }
        worker.execute {
            var title: String? = null
            var artist: String? = null
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(host, Uri.parse(uri))
                title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE)
                artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST)
            } catch (e: Exception) {
                // No tags: the name of the file stands in.
            } finally {
                try { retriever.release() } catch (_: Exception) {}
            }
            main.post { result.success(mapOf("title" to title, "artist" to artist)) }
        }
    }

    // Gives back the right to read a file the player let go of: the system
    // keeps only a few hundred.
    private fun release(uri: String?, result: MethodChannel.Result) {
        val host = activity
        if (uri != null && host != null) {
            try {
                host.contentResolver.releasePersistableUriPermission(
                    Uri.parse(uri),
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (e: SecurityException) {
                // It was not kept.
            }
        }
        result.success(null)
    }

    private fun describe(host: Activity, uri: Uri): Map<String, Any?> {
        var name: String? = null
        var size: Long? = null
        host.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            if (cursor.moveToFirst()) {
                val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                val sizeColumn = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (nameColumn >= 0 && !cursor.isNull(nameColumn)) name = cursor.getString(nameColumn)
                if (sizeColumn >= 0 && !cursor.isNull(sizeColumn)) size = cursor.getLong(sizeColumn)
            }
        }
        return mapOf(
            "uri" to uri.toString(),
            "name" to (name ?: uri.lastPathSegment ?: "audio"),
            "size" to size,
        )
    }
}
