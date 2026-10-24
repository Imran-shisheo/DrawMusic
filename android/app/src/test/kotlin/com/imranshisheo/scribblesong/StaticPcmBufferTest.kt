package com.imranshisheo.scribblesong

import android.media.AudioTrack
import org.junit.Assert.*
import org.junit.Test

class StaticPcmBufferTest {
    // MODE_STATIC buffers have no data before write(), even when allocation
    // succeeded. Model this Android contract instead of an always-ready fake.
    private class Buffer(
        override var state: Int = AudioTrack.STATE_NO_STATIC_DATA,
        val initializeOnWrite: Boolean = true,
        val writeResult: Int? = null,
        val loopResult: Int = AudioTrack.SUCCESS
    ) : StaticPcmBuffer {
        val calls = mutableListOf<String>()
        var written: ByteArray? = null
        var loopFrames: Int? = null
        var released = false
        override fun write(pcm: ByteArray): Int {
            calls.add("write")
            written = pcm.copyOf()
            if (initializeOnWrite) state = AudioTrack.STATE_INITIALIZED
            return writeResult ?: pcm.size
        }
        override fun loop(frames: Int): Int {
            check(state == AudioTrack.STATE_INITIALIZED)
            calls.add("loop")
            loopFrames = frames
            return loopResult
        }
        override fun release() { released = true; calls.add("release") }
    }
    private val pcm = byteArrayOf(0, 0, 100, 0, -100, -1, 0, 0)

    @Test fun staticBufferBecomesReadyAfterFirstPcmWrite() {
        val buffer = Buffer()
        loadStaticPcm(buffer, pcm)
        assertArrayEquals(pcm, buffer.written)
        assertEquals(listOf("write", "loop"), buffer.calls)
        assertEquals(pcm.size / 2, buffer.loopFrames)
        assertFalse(buffer.released)
    }
    @Test fun alreadyInitializedBufferIsAlsoAccepted() {
        val buffer = Buffer(state = AudioTrack.STATE_INITIALIZED)
        loadStaticPcm(buffer, pcm)
        assertEquals(listOf("write", "loop"), buffer.calls)
    }
    @Test fun failedAllocationIsReleasedWithoutWriting() {
        val buffer = Buffer(state = AudioTrack.STATE_UNINITIALIZED)
        assertThrows(IllegalStateException::class.java) { loadStaticPcm(buffer, pcm) }
        assertEquals(listOf("release"), buffer.calls)
    }
    @Test fun shortWriteIsReleasedWithoutLooping() {
        val buffer = Buffer(writeResult = pcm.size - 2)
        assertThrows(IllegalStateException::class.java) { loadStaticPcm(buffer, pcm) }
        assertEquals(listOf("write", "release"), buffer.calls)
    }
    @Test fun writeThatDoesNotInitializeIsReleasedWithoutLooping() {
        val buffer = Buffer(initializeOnWrite = false)
        assertThrows(IllegalStateException::class.java) { loadStaticPcm(buffer, pcm) }
        assertEquals(listOf("write", "release"), buffer.calls)
    }
    @Test fun failedLoopConfigurationReleasesBuffer() {
        val buffer = Buffer(loopResult = AudioTrack.ERROR_BAD_VALUE)
        assertThrows(IllegalStateException::class.java) { loadStaticPcm(buffer, pcm) }
        assertEquals(listOf("write", "loop", "release"), buffer.calls)
        assertTrue(buffer.released)
    }
}
