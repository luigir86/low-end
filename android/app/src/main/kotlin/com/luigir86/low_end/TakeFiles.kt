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
    internal const val SAVE = 4602
    private val session = UUID.randomUUID().toString()
    private var pending: Pair<File, MethodChannel.Result>? = null

    fun attach(host: Activity, messenger: BinaryMessenger) {
        val root = File(host.cacheDir, "takes")
        val working = File(root, session)
        working.mkdirs()
        // A killed process cannot release its temporary takes.
        root.listFiles()?.filter { it.name != session }?.forEach { it.deleteRecursively() }
        val exports = File(host.cacheDir, "shared-takes")
        // A shared take is let go a day later.
        exports.listFiles()?.filter { System.currentTimeMillis() - it.lastModified() > 86400000L }
            ?.forEach { it.deleteRecursively() }
        MethodChannel(messenger, "low_end/takes").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "path" -> {
                        val name = call.arguments as String
                        require(name == File(name).name && name != "." && name != "..")
                        result.success(File(working, name).absolutePath)
                        return@setMethodCallHandler
                    }
                }
                val path = call.argument<String>("path")!!
                val name = fileName(call.argument<String>("name"), path)
                val source = File(path).canonicalFile
                require(source.parentFile == working.canonicalFile && source.isFile)
                when (call.method) {
                    "save" -> {
                        check(pending == null)
                        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = mimeType(source)
                            putExtra(Intent.EXTRA_TITLE, name)
                        }
                        host.startActivityForResult(intent, SAVE)
                        pending = source to result
                    }
                    "share" -> {
                        // The receiving app may open its attachment after the
                        // player changes track, so it gets a copy of its own.
                        // A copy, not a hard link: Android refuses links to
                        // apps (SELinux), which made sharing fail.
                        exports.mkdirs()
                        val copy = File(exports, name)
                        Thread {
                            try {
                                // An older take shared with the same name gives way.
                                source.copyTo(copy, overwrite = true)
                                copy.setLastModified(System.currentTimeMillis())
                                host.runOnUiThread {
                                    try {
                                        val uri = FileProvider.getUriForFile(host, host.packageName + ".takes", copy)
                                        val send = Intent(Intent.ACTION_SEND).apply {
                                            // As a file, not as audio: WhatsApp then keeps its name.
                                            type = TakeProvider.DOCUMENT
                                            putExtra(Intent.EXTRA_STREAM, uri)
                                            clipData = ClipData.newRawUri(name, uri)
                                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        }
                                        host.startActivity(Intent.createChooser(send, null))
                                        result.success(true)
                                    } catch (e: Exception) {
                                        result.error("share", e.message, null)
                                    }
                                }
                            } catch (e: Exception) {
                                host.runOnUiThread { result.error("share", e.message, null) }
                            }
                        }.start()
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("recording", e.message, null)
            }
        }
    }

    /// The name the person gave the take, made safe for a file and kept
    /// with the extension of the take; the take's own name if none.
    internal fun fileName(asked: String?, path: String): String {
        val source = File(path)
        val extension = source.extension
        var base = (asked ?: "").replace(Regex("[\\\\/:*?\"<>|\\x00-\\x1F]"), "_").trim()
        if (extension.isNotEmpty() && base.endsWith(".$extension", ignoreCase = true)) {
            base = base.dropLast(extension.length + 1).trim()
        }
        base = base.trimStart('.').take(80).trim()
        if (base.isEmpty()) base = source.nameWithoutExtension
        return if (extension.isEmpty()) base else "$base.$extension"
    }

    internal fun mimeType(file: File) = if (file.extension == "wav") "audio/wav" else "audio/mp4"

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
