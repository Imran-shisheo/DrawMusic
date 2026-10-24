package com.imranshisheo.scribblesong

import android.media.AudioTrack

/** Narrow boundary for testing the documented MODE_STATIC state transition. */
internal interface StaticPcmBuffer {
    val state: Int
    fun write(pcm: ByteArray): Int
    fun loop(frames: Int): Int
    fun release()
}

internal class AndroidStaticPcmBuffer(private val track: AudioTrack) : StaticPcmBuffer {
    override val state: Int get() = track.state
    override fun write(pcm: ByteArray) = track.write(pcm, 0, pcm.size)
    override fun loop(frames: Int) = track.setLoopPoints(0, frames, -1)
    override fun release() = track.release()
}

internal fun loadStaticPcm(buffer: StaticPcmBuffer, pcm: ByteArray) {
    try {
        // MODE_STATIC is STATE_NO_STATIC_DATA until its first successful write.
        // Only STATE_UNINITIALIZED means construction actually failed.
        check(buffer.state != AudioTrack.STATE_UNINITIALIZED) { "Audio output unavailable. Please retry." }
        check(buffer.write(pcm) == pcm.size) { "Audio preparation incomplete. Please retry." }
        check(buffer.state == AudioTrack.STATE_INITIALIZED) { "Audio output did not initialize. Please retry." }
        check(buffer.loop(pcm.size / 2) == AudioTrack.SUCCESS) { "Audio loop could not be prepared. Please retry." }
    } catch (error: Exception) {
        buffer.release()
        throw error
    }
}
