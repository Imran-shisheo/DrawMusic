package com.imranshisheo.scribblesong

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.ImageFormat
import android.graphics.Paint
import android.graphics.Path
import android.media.Image
import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.SystemClock
import org.json.JSONObject
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.ceil
import kotlin.math.roundToInt

/** Offline document rendering, never a screen/microphone recording. */
internal class CanvasVideoEncoder {
    private val fps = 30
    private fun checkCancelled(cancel: AtomicBoolean) { if (cancel.get()) throw CancellationException("Export canceled") }

    fun export(document: String, pcm: ByteArray, width: Int, output: File, cancel: AtomicBoolean,
        progress: (Double) -> Unit): Map<String, Any> {
        require(width == 1080 || width == 640)
        require(pcm.isNotEmpty() && pcm.size % 2 == 0 && pcm.size <= 2_000_000)
        val height = width * 5 / 4
        val doc = JSONObject(document)
        val tempo = doc.getInt("tempo")
        require(tempo in 60..200)
        val loopSeconds = 480.0 / tempo
        require(kotlin.math.abs(pcm.size / 2.0 / 44100 - (loopSeconds + 1.25)) < .001)
        val scratch = File(output.parentFile, ".video-${output.name}")
        check(scratch.mkdirs()) { "Could not allocate video workspace" }
        val encodedAudio = File(scratch, "encoded-audio.m4a")
        val audio = File(scratch, "audio.m4a")
        val video = File(scratch, "video.mp4")
        var complete = false
        try {
            checkCancelled(cancel)
            val audioFrames = pcm.size / 2
            val audioFormat = MediaFormat.createAudioFormat("audio/mp4a-latm", 44100, 1).apply {
                setInteger(MediaFormat.KEY_AAC_PROFILE, MediaCodecInfo.CodecProfileLevel.AACObjectLC)
                setInteger(MediaFormat.KEY_BIT_RATE, 128000)
                setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 16384)
            }
            // Flush codec priming and retain the complete release tail.
            val paddedPcm = pcm.copyOf(pcm.size + 8192 * 2)
            val audioInputs = (paddedPcm.size / 2 + 1023) / 1024
            encodeTrack(audioFormat, encodedAudio, audioInputs, paddedPcm.size / 2 * 1_000_000L / 44100, cancel,
                { progress(.2 * it) }) { codec, index, ordinal ->
                val offset = ordinal * 2048
                val count = minOf(2048, paddedPcm.size - offset)
                val buffer = codec.getInputBuffer(index) ?: error("Audio encoder input unavailable")
                buffer.clear(); check(buffer.remaining() >= count)
                buffer.put(paddedPcm, offset, count)
                codec.queueInputBuffer(index, 0, count, (offset / 2) * 1_000_000L / 44100, 0)
            }
            val residualDelay = AacAlignment.align(encodedAudio, audio, pcm, cancel)
            // AAC can pad its final packet. Match video to the encoded track,
            // retaining the same PCM and a bounded release tail.
            val durationUs = trackDuration(audio).coerceAtLeast(audioFrames * 1_000_000L / 44100)
            val frames = ceil(durationUs * fps / 1_000_000.0).toInt()
            val videoFormat = MediaFormat.createVideoFormat("video/avc", width, height).apply {
                setInteger(MediaFormat.KEY_COLOR_FORMAT, MediaCodecInfo.CodecCapabilities.COLOR_FormatYUV420Flexible)
                setInteger(MediaFormat.KEY_BIT_RATE, if (width == 1080) 4_000_000 else 2_000_000)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT601_NTSC)
                setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
                if (android.os.Build.VERSION.SDK_INT >= 29) setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
            }
            val renderer = DocumentFrames(doc, width, height)
            try {
                encodeTrack(videoFormat, video, frames, frames * 1_000_000L / fps, cancel,
                    { progress(.2 + .7 * it) }) { codec, index, ordinal ->
                    val fraction = (ordinal / fps.toDouble() / loopSeconds).coerceIn(0.0, 1.0)
                    val pixels = renderer.render(fraction)
                    val image = codec.getInputImage(index) ?: error("This encoder does not expose YUV input. Try compact resolution.")
                    try { fillYuv(image, pixels, width, height, cancel) } finally { image.close() }
                    codec.queueInputBuffer(index, 0, width * height * 3 / 2, ordinal * 1_000_000L / fps, 0)
                }
            } finally { renderer.close() }
            checkCancelled(cancel)
            mux(video, audio, output, cancel)
            progress(.98)
            val extractor = MediaExtractor()
            try {
                extractor.setDataSource(output.path)
                val formats = (0 until extractor.trackCount).map { extractor.getTrackFormat(it) }
                check(formats.any { it.getString(MediaFormat.KEY_MIME) == "video/avc" })
                check(formats.any { it.getString(MediaFormat.KEY_MIME) == "audio/mp4a-latm" })
                check(output.length() > 0)
            } finally { extractor.release() }
            checkCancelled(cancel)
            complete = true
            progress(1.0)
            return mapOf("durationSeconds" to durationUs / 1_000_000.0, "width" to width, "height" to height, "audioResidualDelayFrames" to residualDelay)
        } finally {
            scratch.deleteRecursively()
            if (!complete) output.delete()
        }
    }

    private fun encodeTrack(format: MediaFormat, file: File, inputs: Int, endUs: Long,
        cancel: AtomicBoolean, progress: (Double) -> Unit,
        fill: (MediaCodec, Int, Int) -> Unit) {
        val codec = MediaCodec.createEncoderByType(format.getString(MediaFormat.KEY_MIME)!!)
        var codecStarted = false
        var muxer: MediaMuxer? = null
        var muxerStarted = false
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start(); codecStarted = true
            muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
            var track = -1
            var submitted = 0
            var inputEnded = false
            var outputEnded = false
            var lastWork = SystemClock.elapsedRealtime()
            val info = MediaCodec.BufferInfo()
            while (!outputEnded) {
                checkCancelled(cancel)
                check(SystemClock.elapsedRealtime() - lastWork < 30000) { "Video encoder stalled. Try compact resolution." }
                if (!inputEnded) {
                    val input = codec.dequeueInputBuffer(10000)
                    if (input >= 0) {
                        if (submitted < inputs) {
                            fill(codec, input, submitted++)
                            progress(submitted.toDouble() / inputs)
                        } else {
                            codec.queueInputBuffer(input, 0, 0, endUs, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                            inputEnded = true
                        }
                        lastWork = SystemClock.elapsedRealtime()
                    }
                }
                var draining = true
                while (draining && !outputEnded) {
                    checkCancelled(cancel)
                    val output = codec.dequeueOutputBuffer(info, 10000)
                    when {
                        output == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            check(!muxerStarted)
                            track = muxer.addTrack(codec.outputFormat)
                            muxer.start(); muxerStarted = true
                            lastWork = SystemClock.elapsedRealtime()
                        }
                        output >= 0 -> {
                            if (info.size > 0 && info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG == 0) {
                                check(muxerStarted)
                                val buffer = codec.getOutputBuffer(output) ?: error("Encoder output unavailable")
                                buffer.position(info.offset); buffer.limit(info.offset + info.size)
                                info.presentationTimeUs = maxOf(0L, info.presentationTimeUs)
                                muxer.writeSampleData(track, buffer, info)
                            }
                            outputEnded = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                            codec.releaseOutputBuffer(output, false)
                            lastWork = SystemClock.elapsedRealtime()
                        }
                        else -> draining = false
                    }
                }
            }
            check(muxerStarted)
            muxer.stop(); muxerStarted = false
        } finally {
            if (codecStarted) try { codec.stop() } catch (_: Exception) { }
            codec.release()
            if (muxerStarted) try { muxer?.stop() } catch (_: Exception) { }
            muxer?.release()
        }
    }
    private fun trackDuration(file: File): Long {
        val extractor = MediaExtractor()
        try {
            extractor.setDataSource(file.path)
            val format = extractor.getTrackFormat(0)
            return if (format.containsKey(MediaFormat.KEY_DURATION)) format.getLong(MediaFormat.KEY_DURATION) else 0L
        } finally { extractor.release() }
    }
    private fun mux(video: File, audio: File, output: File, cancel: AtomicBoolean) {
        val sources = listOf(MediaExtractor(), MediaExtractor())
        val muxer = MediaMuxer(output.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)
        var started = false
        try {
            sources[0].setDataSource(video.path); sources[1].setDataSource(audio.path)
            val tracks = sources.map { extractor -> extractor.selectTrack(0); muxer.addTrack(extractor.getTrackFormat(0)) }
            muxer.start(); started = true
            val buffer = ByteBuffer.allocateDirect(4 * 1024 * 1024)
            val info = MediaCodec.BufferInfo()
            while (true) {
                checkCancelled(cancel)
                // Interleave globally by timestamp, keeping muxer input bounded
                // rather than feeding the entire video ahead of the audio.
                val index = sources.indices.filter { sources[it].sampleTime >= 0 }
                    .minByOrNull { sources[it].sampleTime } ?: break
                val extractor = sources[index]
                buffer.clear()
                val count = extractor.readSampleData(buffer, 0)
                check(count >= 0) { "Encoded track ended unexpectedly" }
                info.set(0, count, extractor.sampleTime,
                    if (extractor.sampleFlags and MediaExtractor.SAMPLE_FLAG_SYNC != 0) MediaCodec.BUFFER_FLAG_KEY_FRAME else 0)
                buffer.position(0); buffer.limit(count)
                muxer.writeSampleData(tracks[index], buffer, info)
                extractor.advance()
            }
            muxer.stop(); started = false
        } finally {
            sources.forEach { it.release() }
            if (started) try { muxer.stop() } catch (_: Exception) { }
            muxer.release()
        }
    }

    private fun fillYuv(image: Image, pixels: IntArray, width: Int, height: Int, cancel: AtomicBoolean) {
        check(image.format == ImageFormat.YUV_420_888 && image.planes.size == 3)
        val y = image.planes[0]; val u = image.planes[1]; val v = image.planes[2]
        for (row in 0 until height) {
            if (row % 32 == 0) checkCancelled(cancel)
            for (column in 0 until width) {
                val pixel = pixels[row * width + column]
                val r = (pixel shr 16) and 255; val g = (pixel shr 8) and 255; val b = pixel and 255
                val value = ((66*r + 129*g + 25*b + 128) shr 8) + 16
                y.buffer.put(row*y.rowStride + column*y.pixelStride, value.coerceIn(0,255).toByte())
            }
        }
        for (row in 0 until height step 2) for (column in 0 until width step 2) {
            var r = 0; var g = 0; var b = 0
            for (dy in 0..1) for (dx in 0..1) {
                val pixel = pixels[(row+dy)*width + column+dx]
                r += (pixel shr 16) and 255; g += (pixel shr 8) and 255; b += pixel and 255
            }
            r /= 4; g /= 4; b /= 4
            val uu = (((-38*r - 74*g + 112*b + 128) shr 8) + 128).coerceIn(0,255)
            val vv = (((112*r - 94*g - 18*b + 128) shr 8) + 128).coerceIn(0,255)
            u.buffer.put(row/2*u.rowStride + column/2*u.pixelStride, uu.toByte())
            v.buffer.put(row/2*v.rowStride + column/2*v.pixelStride, vv.toByte())
        }
    }
}

internal class DocumentFrames(document: JSONObject, private val width: Int, private val height: Int) {
    private data class Mark(val path: Path?, val x: Float, val y: Float, val paint: Paint)
    private val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    private val canvas = Canvas(bitmap)
    private val pixels = IntArray(width * height)
    private val background = opaquePaperColor(document.getLong("background").toInt())
    private val cursor = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xff007e73.toInt(); strokeWidth = 2f * width / 400 }
    private val marks: List<Mark>
    init {
        var budget = 0
        val strokes = document.getJSONArray("strokes")
        require(strokes.length() <= 100000)
        marks = (0 until strokes.length()).map { index ->
            val stroke = strokes.getJSONObject(index)
            val color = when (stroke.getString("instrument")) {
                "keys" -> 0xff7961c6.toInt(); "mallet" -> 0xffa46b16.toInt(); "bell" -> 0xff287e61.toInt()
                else -> error("Instrument unavailable")
            }
            val points = stroke.getJSONArray("points")
            budget += points.length(); require(points.length() > 0 && budget <= 100000)
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color; strokeWidth = stroke.getDouble("width").toFloat() * width
                require(strokeWidth > 0 && strokeWidth <= width*.1f)
                strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND; style = Paint.Style.STROKE
            }
            var firstX = 0f; var firstY = 0f
            val path = Path()
            for (p in 0 until points.length()) {
                val point = points.getJSONArray(p)
                val u = point.getDouble(0); val v = point.getDouble(1)
                require(u.isFinite() && v.isFinite() && u in 0.0..1.0 && v in 0.0..1.0)
                val x = (u*width).toFloat(); val y = (v*height).toFloat()
                if (p == 0) { firstX=x; firstY=y; path.moveTo(x,y) } else path.lineTo(x,y)
            }
            Mark(if (points.length() == 1) null else path, firstX, firstY, paint)
        }
    }
    fun render(fraction: Double): IntArray {
        canvas.drawColor(background)
        for (mark in marks) {
            if (mark.path != null) canvas.drawPath(mark.path,mark.paint)
            else { mark.paint.style=Paint.Style.FILL; canvas.drawCircle(mark.x,mark.y,mark.paint.strokeWidth/2,mark.paint) }
        }
        val x = minOf(width - 1.0, fraction * width).toFloat()
        canvas.drawLine(x,0f,x,height.toFloat(),cursor)
        canvas.drawCircle(x,6f*width/400,5f*width/400,cursor)
        bitmap.getPixels(pixels,0,width,0,0,width,height)
        return pixels
    }
    fun close() { bitmap.recycle() }
}
