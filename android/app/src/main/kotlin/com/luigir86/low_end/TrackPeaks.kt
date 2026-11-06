package com.luigir86.low_end

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.Process
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import java.io.ByteArrayOutputStream
import java.nio.ByteOrder
import java.util.concurrent.Executors
import java.util.concurrent.ThreadFactory
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

// The peaks of a track (see lib/audio/track_files.dart, RF-PLY-15): the
// strongest sample of every 10 ms, decoded with the system's own codecs in
// the background and sent in pieces while the file is read, as little-endian
// 16-bit values (0..32767). One track at a time: a new request ends the
// previous one. It reads the file again from the start, apart from what the
// player has already opened: the player does not share its decoder.
object TrackPeaks {
    private const val FRAME_US = 10_000L
    private const val SEND_EVERY_MS = 250L
    private const val TIMEOUT_US = 10_000L

    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor(ThreadFactory { job ->
        Thread({
            Process.setThreadPriority(Process.THREAD_PRIORITY_BACKGROUND)
            job.run()
        }, "track-peaks")
    })

    // Set when the reading in progress must stop.
    private var stopCurrent: AtomicBoolean? = null

    fun attach(context: Context, messenger: BinaryMessenger) {
        val app = context.applicationContext
        EventChannel(messenger, "low_end/track_peaks").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                val uri = (arguments as? Map<*, *>)?.get("uri") as? String
                if (uri == null) {
                    events.error("unreadable", "No address given.", null)
                    return
                }
                stopCurrent?.set(true)
                val stop = AtomicBoolean(false)
                stopCurrent = stop
                worker.execute { read(app, Uri.parse(uri), events, stop) }
            }

            override fun onCancel(arguments: Any?) {
                stopCurrent?.set(true)
                stopCurrent = null
            }
        })
    }

    private fun read(context: Context, uri: Uri, events: EventChannel.EventSink, stop: AtomicBoolean) {
        var extractor: MediaExtractor? = null
        var codec: MediaCodec? = null
        try {
            if (stop.get()) return
            extractor = MediaExtractor()
            extractor.setDataSource(context, uri, null)
            var chosen: MediaFormat? = null
            for (i in 0 until extractor.trackCount) {
                val f = extractor.getTrackFormat(i)
                if (f.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                    extractor.selectTrack(i)
                    chosen = f
                    break
                }
            }
            if (chosen == null) {
                fail(events, stop, "No audio track.")
                return
            }
            val decoder = MediaCodec.createDecoderByType(chosen.getString(MediaFormat.KEY_MIME)!!)
            codec = decoder
            decoder.configure(chosen, null, null, 0)
            decoder.start()

            var sampleRate = chosen.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            var channels = max(1, chosen.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
            var encoding = AudioFormat.ENCODING_PCM_16BIT

            val out = ByteArrayOutputStream()
            var nextFrame = 0L      // the frame being filled
            var inFrame = 0         // samples (per channel) already in it
            var framePeak = 0       // its strongest sample so far
            var channel = 0         // which channel the next sample is of

            fun emit(peak: Int) {
                out.write(peak and 0xFF)
                out.write((peak shr 8) and 0xFF)
                nextFrame++
            }

            val info = MediaCodec.BufferInfo()
            var inputDone = false
            var outputDone = false
            var lastSend = System.currentTimeMillis()
            while (!outputDone && !stop.get()) {
                if (!inputDone) {
                    val index = decoder.dequeueInputBuffer(TIMEOUT_US)
                    if (index >= 0) {
                        val buffer = decoder.getInputBuffer(index)!!
                        val size = extractor.readSampleData(buffer, 0)
                        if (size < 0) {
                            decoder.queueInputBuffer(index, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputDone = true
                        } else {
                            decoder.queueInputBuffer(index, 0, size, extractor.sampleTime, 0)
                            extractor.advance()
                        }
                    }
                }
                val index = decoder.dequeueOutputBuffer(info, TIMEOUT_US)
                if (index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val f = decoder.outputFormat
                    sampleRate = f.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    channels = max(1, f.getInteger(MediaFormat.KEY_CHANNEL_COUNT))
                    encoding = if (f.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
                        f.getInteger(MediaFormat.KEY_PCM_ENCODING)
                    } else {
                        AudioFormat.ENCODING_PCM_16BIT
                    }
                    if (encoding != AudioFormat.ENCODING_PCM_16BIT && encoding != AudioFormat.ENCODING_PCM_FLOAT) {
                        fail(events, stop, "Unsupported PCM encoding $encoding.")
                        return
                    }
                } else if (index >= 0) {
                    val perFrame = max(1, sampleRate / 100)
                    if (info.size > 0) {
                        // Follow the file's own clock: a buffer that starts
                        // later than the count says (the decoder skipped a
                        // piece) is filled up with silence.
                        val expectedUs = nextFrame * FRAME_US + inFrame * 1_000_000L / sampleRate
                        if (info.presentationTimeUs - expectedUs > FRAME_US) {
                            if (inFrame > 0) emit(framePeak)
                            inFrame = 0
                            framePeak = 0
                            channel = 0
                            val target = info.presentationTimeUs / FRAME_US
                            while (nextFrame < target) emit(0)
                        }
                        val buffer = decoder.getOutputBuffer(index)!!
                        buffer.position(info.offset)
                        buffer.limit(info.offset + info.size)
                        buffer.order(ByteOrder.LITTLE_ENDIAN)
                        if (encoding == AudioFormat.ENCODING_PCM_FLOAT) {
                            val samples = buffer.asFloatBuffer()
                            while (samples.hasRemaining()) {
                                val v = min(32767, (abs(samples.get()) * 32767f).toInt())
                                if (v > framePeak) framePeak = v
                                if (++channel == channels) {
                                    channel = 0
                                    if (++inFrame == perFrame) {
                                        emit(framePeak)
                                        inFrame = 0
                                        framePeak = 0
                                    }
                                }
                            }
                        } else {
                            val samples = buffer.asShortBuffer()
                            while (samples.hasRemaining()) {
                                val v = min(32767, abs(samples.get().toInt()))
                                if (v > framePeak) framePeak = v
                                if (++channel == channels) {
                                    channel = 0
                                    if (++inFrame == perFrame) {
                                        emit(framePeak)
                                        inFrame = 0
                                        framePeak = 0
                                    }
                                }
                            }
                        }
                    }
                    decoder.releaseOutputBuffer(index, false)
                    if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) outputDone = true
                }
                val now = System.currentTimeMillis()
                if (now - lastSend >= SEND_EVERY_MS) {
                    send(events, stop, out)
                    lastSend = now
                }
            }
            if (stop.get()) return
            if (inFrame > 0) emit(framePeak)
            send(events, stop, out)
            main.post { if (!stop.get()) events.endOfStream() }
        } catch (e: Exception) {
            fail(events, stop, e.message ?: e.javaClass.simpleName)
        } finally {
            try { codec?.stop() } catch (_: Exception) {}
            try { codec?.release() } catch (_: Exception) {}
            try { extractor?.release() } catch (_: Exception) {}
        }
    }

    // Sends what has been read since the last time.
    private fun send(events: EventChannel.EventSink, stop: AtomicBoolean, out: ByteArrayOutputStream) {
        if (out.size() == 0) return
        val data = out.toByteArray()
        out.reset()
        main.post { if (!stop.get()) events.success(data) }
    }

    private fun fail(events: EventChannel.EventSink, stop: AtomicBoolean, message: String) {
        main.post { if (!stop.get()) events.error("unreadable", message, null) }
    }
}
