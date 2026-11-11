package com.luigir86.low_end

import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import org.junit.Assert.fail
import org.robolectric.Shadows.shadowOf

/** Stands in for Flutter: calls the app's channels as the Dart side would,
 * and keeps what the app calls back. */
class FakeMessenger : BinaryMessenger {
    private val codec = StandardMethodCodec.INSTANCE
    private val handlers = mutableMapOf<String, BinaryMessenger.BinaryMessageHandler>()

    /** Calls from the app to Dart: (channel, method, arguments). */
    val sent = mutableListOf<Triple<String, String, Any?>>()

    override fun send(channel: String, message: ByteBuffer?) = send(channel, message, null)

    override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {
        message!!.rewind()
        val call = codec.decodeMethodCall(message)
        sent += Triple(channel, call.method, call.arguments)
        callback?.reply(null)
    }

    override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) {
        if (handler == null) handlers.remove(channel) else handlers[channel] = handler
    }

    /** Calls [method] on [channel] and waits (running the main thread) for
     * the answer: the value, or a [Failure] if the app answered an error. */
    fun call(channel: String, method: String, arguments: Any? = null): Any? {
        val answer = start(channel, method, arguments)
        waitFor { answer() !== Pending }
        return answer()
    }

    /** Calls [method] without waiting: the answer, [Pending] until it comes. */
    fun start(channel: String, method: String, arguments: Any? = null): () -> Any? {
        val handler = handlers[channel] ?: error("Nothing listens on $channel")
        var answer: Any? = Pending
        val message = codec.encodeMethodCall(MethodCall(method, arguments))
        message.rewind()
        handler.onMessage(message) { reply ->
            answer = if (reply == null) {
                Failure("notImplemented", null)
            } else {
                reply.rewind()
                try {
                    codec.decodeEnvelope(reply)
                } catch (e: FlutterException) {
                    Failure(e.code, e.message)
                }
            }
        }
        return { answer }
    }

    data class Failure(val code: String, val message: String?)

    object Pending
}

/** Runs the main thread until [done], for work the app does on another
 * thread before answering on the main one. */
fun waitFor(done: () -> Boolean) {
    val end = System.currentTimeMillis() + 10_000
    while (!done()) {
        shadowOf(Looper.getMainLooper()).idle()
        if (done()) return
        if (System.currentTimeMillis() > end) fail("Timed out waiting for the app")
        Thread.sleep(10)
    }
}
