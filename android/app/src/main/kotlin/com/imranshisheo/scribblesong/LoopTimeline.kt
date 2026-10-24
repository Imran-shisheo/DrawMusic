package com.imranshisheo.scribblesong

import java.util.ArrayDeque
import kotlin.math.roundToInt

internal data class PcmLoop(val pcm: ByteArray, val revision: Long, val tempo: Int) {
    val frames = pcm.size / 2
    init {
        require(pcm.isNotEmpty() && pcm.size % 2 == 0 && pcm.size <= 2_000_000)
        require(tempo in 60..200)
        require(kotlin.math.abs(frames - (480.0 / tempo * 44100).roundToInt()) <= 1)
    }
    fun beatFrame(beat: Int) = (frames * beat / 8.0).roundToInt()
}
internal enum class UpdateBoundary { BEAT, LOOP }
internal data class PcmChunk(val loop: PcmLoop, val offsetFrames: Int, val frames: Int, val previous: PcmLoop? = null, val previousOffset: Int = 0)
internal data class LoopPosition(val revision: Long, val targetRevision: Long, val fraction: Double, val tempo: Int)

/** All decisions use PCM frame numbers. UI polling never schedules a note. */
internal class LoopTimeline(initial: PcmLoop) {
    private data class Pending(val loop: PcmLoop, val boundary: UpdateBoundary)
    private data class Span(val start: Long, var end: Long, val loop: PcmLoop, val offset: Int)
    private var current = initial
    private var offset = 0
    private var written = 0L
    private var pending: Pending? = null
    private var targetRevision = initial.revision
    private val spans = ArrayDeque<Span>()

    @Synchronized fun queue(loop: PcmLoop, boundary: UpdateBoundary) {
        pending = Pending(loop, boundary)
        targetRevision = loop.revision
    }
    @Synchronized fun nextChunk(maxFrames: Int): PcmChunk {
        require(maxFrames > 0)
        val beat = (0..7).firstOrNull { current.beatFrame(it) == offset }
        var previous: PcmLoop? = null
        val previousOffset = offset
        pending?.let { update ->
            if (offset == 0 || (update.boundary == UpdateBoundary.BEAT && beat != null)) {
                previous = current
                current = update.loop
                offset = current.beatFrame(beat ?: 0)
                pending = null
            }
        }
        var length = minOf(maxFrames, current.frames - offset)
        pending?.let { update ->
            if (update.boundary == UpdateBoundary.BEAT) {
                val nextBeat = (1..8).map { current.beatFrame(it) }.first { it > offset }
                length = minOf(length, nextBeat - offset)
            }
        }
        val chunk = PcmChunk(current, offset, length, previous, previousOffset)
        val last = spans.peekLast()
        if (last != null && last.loop === current && last.end == written &&
            last.offset + (last.end - last.start) == offset.toLong()) {
            last.end += length
        } else {
            spans.addLast(Span(written, written + length, current, offset))
        }
        written += length
        offset = (offset + length) % current.frames
        return chunk
    }
    @Synchronized fun position(playedFrames: Long): LoopPosition {
        val head = playedFrames.coerceIn(0, written)
        while (spans.size > 1 && spans.elementAt(1).start <= head) spans.removeFirst()
        val span = spans.peekFirst()
        if (span == null) return LoopPosition(current.revision, targetRevision, 0.0, current.tempo)
        val sourceFrame = (span.offset + (head - span.start).coerceAtMost(span.end - span.start)) % span.loop.frames
        return LoopPosition(span.loop.revision, targetRevision, sourceFrame.toDouble() / span.loop.frames, span.loop.tempo)
    }
}

internal class PlaybackHeadCounter {
    private var previous = 0L
    private var wraps = 0L
    @Synchronized fun update(raw: Int): Long {
        val value = raw.toLong() and 0xffffffffL
        if (value < previous && previous - value > 0x80000000L) wraps += 0x100000000L
        previous = value
        return wraps + value
    }
}

/** Eight-beat schedules stay exact; only a short handoff ramp blends PCM. */
internal fun transitionPcm(chunk: PcmChunk): ByteArray? {
    val previous = chunk.previous ?: return null
    val output = chunk.loop.pcm.copyOfRange(chunk.offsetFrames * 2, (chunk.offsetFrames + chunk.frames) * 2)
    val length = minOf(128, chunk.frames)
    fun sample(data: ByteArray, frame: Int): Int = (data[frame * 2].toInt() and 255) or (data[frame * 2 + 1].toInt() shl 8)
    for (i in 0 until length) {
        val old = sample(previous.pcm, (chunk.previousOffset + i) % previous.frames)
        val next = sample(output, i)
        val fraction = if (length == 1) 1.0 else i.toDouble() / (length - 1)
        val value = (old * (1 - fraction) + next * fraction).roundToInt().coerceIn(-32768,32767)
        output[i * 2] = value.toByte(); output[i * 2 + 1] = (value shr 8).toByte()
    }
    return output
}
