package com.luigir86.low_end

import android.net.Uri
import androidx.core.content.FileProvider

/**
 * Hands shared takes to other apps as plain files, not as audio. WhatsApp
 * sends an audio file as a voice-style message and drops its name; as a
 * file (a document) it keeps the name the person gave the take.
 */
class TakeProvider : FileProvider() {
    override fun getType(uri: Uri): String = DOCUMENT

    companion object {
        const val DOCUMENT = "application/octet-stream"
    }
}
