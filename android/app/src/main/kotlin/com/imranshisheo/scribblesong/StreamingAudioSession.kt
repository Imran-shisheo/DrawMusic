package com.imranshisheo.scribblesong

import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Process

/** Bounded producer queue; the AudioTrack playback head is the transport clock. */
internal class StreamingAudioSession(initial: PcmLoop, attributes: AudioAttributes) {
    private val timeline = LoopTimeline(initial)
    private val counter = PlaybackHeadCounter()
    private val monitor = Object()
    private val ioLock = Any()
    @Volatile private var requestedPlaying = false
    @Volatile private var released = false
    @Volatile private var failure: String? = null
    private val track: AudioTrack
    private val writer: Thread
    init {
        val minimum = AudioTrack.getMinBufferSize(44100, AudioFormat.CHANNEL_OUT_MONO, AudioFormat.ENCODING_PCM_16BIT)
        check(minimum > 0) { "Audio output format unavailable. Please retry." }
        track = AudioTrack.Builder().setAudioAttributes(attributes)
            .setAudioFormat(AudioFormat.Builder().setSampleRate(44100)
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
            .setTransferMode(AudioTrack.MODE_STREAM).setBufferSizeInBytes(maxOf(minimum * 2, 4096)).build()
        // Unlike MODE_STATIC, MODE_STREAM must be initialized at construction.
        if (track.state != AudioTrack.STATE_INITIALIZED) {
            track.release()
            error("Audio output unavailable. Please retry.")
        }
        writer = Thread({ produce() }, "ScribbleSong-audio").also { it.isDaemon = true; it.start() }
    }
    fun queue(loop: PcmLoop, boundary: UpdateBoundary) { check(!released); timeline.queue(loop, boundary) }
    fun play() {
        check(failure == null) { failure ?: "Audio output stopped" }
        synchronized(ioLock) { check(!released); track.play(); requestedPlaying = true }
        synchronized(monitor) { monitor.notifyAll() }
    }
    fun pause() {
        requestedPlaying = false
        synchronized(ioLock) { if (!released) track.pause() }
    }
    fun setVolume(volume: Float) = synchronized(ioLock) { if (!released) track.setVolume(volume.coerceIn(0f, 1f)) }
    fun status(): Map<String, Any> = synchronized(ioLock) {
        check(failure == null) { failure ?: "Audio output stopped" }
        val position = timeline.position(counter.update(if (released) 0 else track.playbackHeadPosition))
        mapOf("playing" to (!released && track.playState == AudioTrack.PLAYSTATE_PLAYING),
            "revision" to position.revision, "targetRevision" to position.targetRevision,
            "fraction" to position.fraction, "tempo" to position.tempo)
    }
    fun close() {
        requestedPlaying = false
        released = true
        synchronized(monitor) { monitor.notifyAll() }
        synchronized(ioLock) { track.pause(); track.flush(); track.release() }
        writer.join(100)
    }
    private fun produce() {
        try { Process.setThreadPriority(Process.THREAD_PRIORITY_AUDIO) } catch (_: SecurityException) { /* Scheduling correctness does not depend on priority. */ }
        var chunk: PcmChunk? = null
        var sentBytes = 0
        var blended: ByteArray? = null
        try {
            while (!released) {
                synchronized(monitor) { while (!requestedPlaying && !released) monitor.wait() }
                if (released) break
                val next = chunk ?: timeline.nextChunk(512).also { chunk = it; sentBytes = 0; blended = transitionPcm(it) }
                val count = synchronized(ioLock) {
                    if (released || !requestedPlaying) 0 else {
                        timeline.position(counter.update(track.playbackHeadPosition)) // prune consumed clock spans
                        track.write(blended ?: next.loop.pcm, (if (blended == null) next.offsetFrames * 2 else 0) + sentBytes,
                            next.frames * 2 - sentBytes, AudioTrack.WRITE_NON_BLOCKING)
                    }
                }
                check(count >= 0 && count % 2 == 0) { "Audio write failed ($count). Please retry." }
                sentBytes += count
                if (sentBytes == next.frames * 2) chunk = null
                if (count == 0) synchronized(monitor) { if (!released) monitor.wait(5) }
            }
        } catch (error: Exception) {
            if (!released) { failure = error.message ?: "Audio output stopped. Please retry."; pause() }
        }
    }
}
