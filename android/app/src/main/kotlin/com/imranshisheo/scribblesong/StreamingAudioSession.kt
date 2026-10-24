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
    private val envelope = AudioGainEnvelope()
    private var userVolume = 1f
    private var appliedVolume = Float.NaN
    private var pauseWhenSilent = false
    private var frozenPosition: LoopPosition? = timeline.position(0)
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
    private fun applyGain(now: Long):Float {
        val gain=envelope.valueAt(now)
        val volume=userVolume*gain
        if(volume!=appliedVolume) {
            check(track.setVolume(volume)==AudioTrack.SUCCESS) {"Audio gain unavailable"}
            appliedVolume=volume
        }
        return gain
    }
    fun play() {
        synchronized(ioLock) {
            check(!released && failure==null) {failure ?: "Audio output stopped"}
            val now=System.nanoTime()
            pauseWhenSilent=false
            envelope.moveTo(1f,now)
            applyGain(now)
            track.play();requestedPlaying=true;frozenPosition=null
        }
        synchronized(monitor) {monitor.notifyAll()}
    }
    fun pause(smooth:Boolean=false) {
        synchronized(ioLock) {
            if(released) return
            if(smooth && requestedPlaying && track.playState==AudioTrack.PLAYSTATE_PLAYING) {
                envelope.moveTo(0f,System.nanoTime());pauseWhenSilent=true
            } else {
                requestedPlaying=false;pauseWhenSilent=false
                envelope.reset(0f);applyGain(System.nanoTime());pauseTrack()
            }
        }
        synchronized(monitor) {monitor.notifyAll()}
    }
    // Some outputs publish a final hardware quantum after pause() returns.
    // Latch the cursor at the pause boundary; resume reads the hardware clock
    // again. Do not poll a paused device and expose that settling as UI motion.
    private fun pauseTrack() {
        track.pause()
        frozenPosition=timeline.position(counter.update(track.playbackHeadPosition))
    }
    fun setVolume(volume:Float)=synchronized(ioLock) {
        require(volume.isFinite())
        if(!released) {userVolume=volume.coerceIn(0f,1f);applyGain(System.nanoTime())}
    }
    fun status(): Map<String, Any> = synchronized(ioLock) {
        check(failure == null) { failure ?: "Audio output stopped" }
        val position = frozenPosition ?: timeline.position(counter.update(track.playbackHeadPosition))
        mapOf("playing" to (!released && track.playState == AudioTrack.PLAYSTATE_PLAYING),
            "revision" to position.revision, "targetRevision" to position.targetRevision,
            "fraction" to position.fraction, "tempo" to position.tempo)
    }
    fun close() {
        synchronized(ioLock) {
            if(released) return
            requestedPlaying=false;pauseWhenSilent=false;released=true
            pauseTrack();track.flush();track.release()
        }
        synchronized(monitor) {monitor.notifyAll()}
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
                        val now=System.nanoTime()
                        applyGain(now)
                        if(pauseWhenSilent && envelope.finished(now)) {
                            requestedPlaying=false;pauseWhenSilent=false;pauseTrack()
                            0
                        } else {
                        timeline.position(counter.update(track.playbackHeadPosition)) // prune consumed clock spans
                        track.write(blended ?: next.loop.pcm, (if (blended == null) next.offsetFrames * 2 else 0) + sentBytes,
                            next.frames * 2 - sentBytes, AudioTrack.WRITE_NON_BLOCKING)
                        }
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
