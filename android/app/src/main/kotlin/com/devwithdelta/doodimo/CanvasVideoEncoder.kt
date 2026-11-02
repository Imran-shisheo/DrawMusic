package com.devwithdelta.doodimo

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
internal class CanvasVideoEncoder(private val backgroundRoot: File? = null) {
    private fun checkCancelled(cancel: AtomicBoolean) { if (cancel.get()) throw CancellationException("Export canceled") }

    fun export(document: String, pcm: ByteArray, width: Int, output: File, cancel: AtomicBoolean, fps: Int = 30,
        progress: (Double) -> Unit): Map<String, Any> {
        require(width == 1080 || width == 640)
        require(fps == 30 || fps == 60) { "Unsupported video frame rate" }
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
                setInteger(MediaFormat.KEY_BIT_RATE, (if (width == 1080) 4_000_000 else 2_000_000) * fps / 30)
                setInteger(MediaFormat.KEY_FRAME_RATE, fps)
                setInteger(MediaFormat.KEY_I_FRAME_INTERVAL, 1)
                setInteger(MediaFormat.KEY_COLOR_STANDARD, MediaFormat.COLOR_STANDARD_BT601_NTSC)
                setInteger(MediaFormat.KEY_COLOR_RANGE, MediaFormat.COLOR_RANGE_LIMITED)
                if (android.os.Build.VERSION.SDK_INT >= 29) setInteger(MediaFormat.KEY_MAX_B_FRAMES, 0)
            }
            val renderer = DocumentFrames(doc, width, height, backgroundRoot)
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
            return mapOf("durationSeconds" to durationUs / 1_000_000.0, "width" to width, "height" to height, "audioResidualDelayFrames" to residualDelay, "fps" to fps)
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

internal class DocumentFrames(document: JSONObject, private val width: Int, private val height: Int, private val backgroundRoot: File? = null) {
    private data class Mark(val path: Path?, val x: Float, val y: Float, val paint: Paint)
    private val background = opaquePaperColor(document.getLong("background").toInt())
    private val paper = document.optJSONObject("paper")
    private val photo: Bitmap? = paper?.takeIf { it.optString("kind") == "photo" }?.let { definition ->
        val id=definition.getString("assetId")
        require(Regex("^[a-f0-9]{64}$").matches(id))
        val root=backgroundRoot ?: error("Photo asset root unavailable")
        val ownedRoot=root.canonicalFile
        val active=File(ownedRoot,"$id.png")
        val stage=File(ownedRoot,".cleanup-staging")
        val file=if(active.exists()) active else {
            require(stage.canonicalPath==File(ownedRoot,".cleanup-staging").absolutePath) {"Background staging link unavailable"}
            File(stage,"$id.png")
        }
        require(file.canonicalPath==file.absolutePath && file.isFile && file.length() in 1..33_554_432)
        val bytes=file.readBytes()
        val hash=java.security.MessageDigest.getInstance("SHA-256").digest(bytes).joinToString(""){"%02x".format(it)}
        require(hash==id) { "Photo asset checksum mismatch" }
        val bounds=android.graphics.BitmapFactory.Options().apply { inJustDecodeBounds=true }
        android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.size,bounds)
        require(bounds.outWidth in 1..2048 && bounds.outHeight in 1..2048)
        android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.size) ?: error("Photo asset unavailable")
    }
    private val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    private val canvas = Canvas(bitmap)
    private val pixels = IntArray(width * height)
    private val cursor = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xff007e73.toInt(); strokeWidth = 2f * width / 400 }
    private val marks: List<Mark>
    init {
        val displayStyle=document.optString("style","smooth")
        require(displayStyle=="smooth" || displayStyle=="pixel") {"Drawing style unavailable"}
        val pixel=displayStyle=="pixel"
        var budget = 0
        val strokes = document.getJSONArray("strokes")
        require(strokes.length() <= 100000)
        marks = (0 until strokes.length()).map { index ->
            val stroke = strokes.getJSONObject(index)
            val color = when (stroke.getString("instrument")) {
                "keys" -> 0xff7961c6.toInt(); "mallet" -> 0xffa46b16.toInt(); "bell" -> 0xff287e61.toInt()
                "warmSynth" -> 0xffa64d34.toInt(); "pluck" -> 0xff456990.toInt(); "flute" -> 0xff536d35.toInt()
                "strings" -> 0xff9b4273.toInt(); "chime" -> 0xff53648c.toInt(); "bass" -> 0xff795548.toInt()
                "chip" -> 0xff6c54a2.toInt(); "electronicBass" -> 0xff925328.toInt(); "guitar" -> 0xff846029.toInt()
                "saxophone" -> 0xff986b17.toInt(); else -> 0xff7961c6.toInt()
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
            val cells=mutableSetOf<Int>()
            var previousX=0;var previousY=0
            for (p in 0 until points.length()) {
                val point = points.getJSONArray(p)
                val u = point.getDouble(0); val v = point.getDouble(1)
                require(u.isFinite() && v.isFinite() && u in 0.0..1.0 && v in 0.0..1.0)
                val x = (u*width).toFloat(); val y = (v*height).toFloat()
                if (pixel) {
                    val cx=(u*40).toInt().coerceIn(0,39);val cy=(v*50).toInt().coerceIn(0,49)
                    if(p==0) cells.add(cy*40+cx) else addPixelSegment(cells,previousX,previousY,cx,cy)
                    previousX=cx;previousY=cy
                }
                if (p == 0) { firstX=x; firstY=y; path.moveTo(x,y) } else path.lineTo(x,y)
            }
            if(pixel) {
                path.reset();paint.style=Paint.Style.FILL;paint.isAntiAlias=false
                for(cell in cells) {
                    val cx=cell%40;val cy=cell/40
                    path.addRect(cx*width/40f,cy*height/50f,(cx+1)*width/40f,(cy+1)*height/50f,Path.Direction.CW)
                }
            }
            Mark(if (points.length() == 1 && !pixel) null else path, firstX, firstY, paint)
        }
    }
    fun render(fraction: Double): IntArray {
        drawBackground()
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
    private fun drawBackground() {
        val definition=paper
        if(definition==null) { canvas.drawColor(background); return }
        canvas.drawColor(android.graphics.Color.WHITE)
        val opacity=definition.optDouble("opacity",1.0).also { require(it.isFinite() && it in 0.0..1.0) }
        val paint=Paint(Paint.ANTI_ALIAS_FLAG).apply { alpha=(opacity*255).roundToInt(); isFilterBitmap=true }
        val kind=definition.optString("kind","solid")
        if(kind=="photo") {
            val image=photo ?: error("Photo asset unavailable")
            val crop=definition.optJSONArray("crop")
            val left=crop?.getDouble(0) ?: 0.0; val top=crop?.getDouble(1) ?: 0.0
            val cw=crop?.getDouble(2) ?: 1.0; val ch=crop?.getDouble(3) ?: 1.0
            require(left>=0 && top>=0 && cw>=.05 && ch>=.05 && left+cw<=1.000001 && top+ch<=1.000001)
            val turns=definition.optInt("quarterTurns",0).also { require(it in 0..3) }
            val targetWidth=if(turns%2==1) height.toFloat() else width.toFloat()
            val targetHeight=if(turns%2==1) width.toFloat() else height.toFloat()
            val source=android.graphics.RectF((left*image.width).toFloat(),(top*image.height).toFloat(),((left+cw)*image.width).toFloat(),((top+ch)*image.height).toFloat())
            val ratio=maxOf(targetWidth/source.width(),targetHeight/source.height())
            val sw=targetWidth/ratio;val sh=targetHeight/ratio
            val cover=android.graphics.RectF(source.centerX()-sw/2,source.centerY()-sh/2,source.centerX()+sw/2,source.centerY()+sh/2)
            canvas.save();canvas.clipRect(0f,0f,width.toFloat(),height.toFloat())
            canvas.translate(width/2f,height/2f);canvas.rotate(turns*90f)
            if(definition.optBoolean("mirror",false)) canvas.scale(-1f,1f)
            val matrix=android.graphics.Matrix()
            matrix.setRectToRect(cover,android.graphics.RectF(-targetWidth/2,-targetHeight/2,targetWidth/2,targetHeight/2),android.graphics.Matrix.ScaleToFit.FILL)
            canvas.drawBitmap(image,matrix,paint);canvas.restore()
        } else {
            val stops=definition.getJSONArray("colors")
            require(stops.length() in 1..4)
            val colors=IntArray(maxOf(2,stops.length())) { stops.getLong(minOf(it,stops.length()-1)).toInt() }
            when(kind) {
                "linear" -> paint.shader=android.graphics.LinearGradient(0f,0f,width.toFloat(),height.toFloat(),colors,null,android.graphics.Shader.TileMode.CLAMP)
                "radial" -> paint.shader=android.graphics.RadialGradient(width/2f,height/2f,maxOf(width,height)/2f,colors,null,android.graphics.Shader.TileMode.CLAMP)
                else -> { paint.color=colors[0];paint.alpha=(((colors[0] ushr 24)/255.0)*opacity*255).roundToInt() }
            }
            canvas.drawRect(0f,0f,width.toFloat(),height.toFloat(),paint)
        }
    }
    fun close() { photo?.recycle(); bitmap.recycle() }
}
