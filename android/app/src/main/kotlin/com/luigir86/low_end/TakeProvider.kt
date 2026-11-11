package com.luigir86.low_end

import android.net.Uri
import androidx.core.content.FileProvider

/**
 * Hands shared takes to other apps as MP4 files (application/mp4), not as
 * audio (audio/mp4). WhatsApp sends an audio/* file as a voice-style
 * message and drops its name; any other type goes as a document with the
 * name the person gave the take. application/mp4 rather than a generic
 * file (application/octet-stream, until 11/11): WhatsApp keeps the type it
 * was given, and a generic "BIN" file could not be opened again, while an
 * MP4 file opens with Low End (the manifest's intent filters).
 */
class TakeProvider : FileProvider() {
    override fun getType(uri: Uri): String = DOCUMENT

    companion object {
        const val DOCUMENT = "application/mp4"
    }
}
