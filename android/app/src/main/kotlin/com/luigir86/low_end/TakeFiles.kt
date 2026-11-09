package com.luigir86.low_end

import android.app.Activity
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

object TakeFiles {
    private const val SAVE = 4602
    private val session = UUID.randomUUID().toString()
    private var pending: Pair<File, MethodChannel.Result>? = null

    fun attach(host: Activity, messenger: BinaryMessenger) {
        val root = File(host.cacheDir, "takes")
        val working = File(root, session)
        working.mkdirs()
        // A killed process cannot release its temporary takes.
        root.listFiles()?.filter { it.name != session }?.forEach { it.deleteRecursively() }
        val exports = File(host.cacheDir, "shared-takes")
        exports.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86400000L }
            ?.forEach { it.delete() }
        MethodChannel(messenger, "low_end/takes").setMethodCallHandler { call, result ->
            try {
                val arg = call.arguments as String
                if (call.method == "path") {
                    require(arg == File(arg).name && arg != "." && arg != "..")
                    result.success(File(working, arg).absolutePath)
                    return@setMethodCallHandler
                }
                val source = File(arg).canonicalFile
                require(source.parentFile == working.canonicalFile && source.isFile)
                when (call.method) {
                    "save" -> {
                        check(pending == null)
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "audio/mp4"
                            putExtra(Intent.EXTRA_TITLE, source.name)
                        }
                        host.startActivityForResult(intent, SAVE)
                        pending = source to result
                    }
                    "share" -> {
                        // The receiving app may open its attachment after the player changes track.
                        exports.mkdirs()
                        val copy = File(exports, source.name)
                        // Both paths are on the app's private cache volume.
                        // Linking keeps large takes shareable without copying
                        // audio on the UI thread.
                        if (!copy.exists()) android.system.Os.link(source.path, copy.path)
                        copy.setLastModified(System.currentTimeMillis())
                        val uri = FileProvider.getUriForFile(host, host.packageName + ".takes", copy)
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "audio/mp4"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            clipData = ClipData.newRawUri(source.name, uri)
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        host.startActivity(Intent.createChooser(send, null))
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("recording", e.message, null)
            }
        }
    }

    fun onResult(host: Activity, request: Int, code: Int, data: Intent?) {
        if (request != SAVE) return
        val (source, result) = pending ?: return
        pending = null
        val destination = data?.data
        if (code != Activity.RESULT_OK || destination == null) {
            result.success(false)
            return
        }
        Thread {
            try {
                requireNotNull(host.contentResolver.openOutputStream(destination, "wt")).use { out ->
                    source.inputStream().use { it.copyTo(out) }
                }
                host.runOnUiThread { result.success(true) }
            } catch (e: Exception) {
                host.runOnUiThread { result.error("save", e.message, null) }
            }
        }.start()
    }
}
