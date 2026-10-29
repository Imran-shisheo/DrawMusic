package com.devwithdelta.doodimo

import org.junit.Assert.*
import org.junit.Test
import kotlin.math.roundToInt

class LoopTimelineTest {
    private fun loop(revision: Long = 1, tempo: Int = 120) =
        PcmLoop(ByteArray((480.0 / tempo * 44100).roundToInt() * 2), revision, tempo)

    @Test fun drawingSwitchesExactlyAtLoopAndClockDoesNotJumpAheadOfAudio() {
        val first = loop(); val next = loop(2)
        val timeline = LoopTimeline(first)
        timeline.nextChunk(10000)
        timeline.queue(next, UpdateBoundary.LOOP)
        val remainder = timeline.nextChunk(200000)
        assertEquals(first.frames - 10000, remainder.frames)
        val changed = timeline.nextChunk(512)
        assertSame(next, changed.loop)
        assertEquals(0, changed.offsetFrames)
        assertEquals(1L, timeline.position(first.frames - 1L).revision)
        assertEquals(2L, timeline.position(first.frames.toLong()).revision)
        assertEquals(0.0, timeline.position(first.frames.toLong()).fraction, 0.0)
    }
    @Test fun tempoChangesAtNextBeatAndPreservesMusicalPhase() {
        val first = loop(); val slower = loop(2,60)
        val timeline = LoopTimeline(first)
        timeline.nextChunk(10000)
        timeline.queue(slower, UpdateBoundary.BEAT)
        assertEquals(first.beatFrame(1) - 10000, timeline.nextChunk(100000).frames)
        val changed = timeline.nextChunk(512)
        assertSame(slower, changed.loop)
        assertEquals(slower.beatFrame(1), changed.offsetFrames)
        val heard = timeline.position(first.beatFrame(1).toLong())
        assertEquals(60, heard.tempo)
        assertEquals(.125, heard.fraction, 1e-9)
    }
    @Test fun latestQueuedRevisionWinsBeforeBoundary() {
        val first = loop(); val timeline = LoopTimeline(first)
        timeline.nextChunk(1024)
        timeline.queue(loop(2), UpdateBoundary.LOOP)
        timeline.queue(loop(3), UpdateBoundary.LOOP)
        timeline.nextChunk(200000)
        assertEquals(3L, timeline.nextChunk(512).loop.revision)
        assertEquals(3L, timeline.position(0).targetRevision)
    }
    @Test fun loopUpdateWaitsEvenWhenQueuedAtBeatBoundary() {
        val first = loop(); val timeline = LoopTimeline(first)
        timeline.nextChunk(first.beatFrame(2))
        timeline.queue(loop(2), UpdateBoundary.LOOP)
        assertEquals(1L, timeline.nextChunk(512).loop.revision)
    }
    @Test fun queuedBytesDoNotMakeUiReportRevisionAsAudibleEarly() {
        val first = loop(); val timeline = LoopTimeline(first)
        timeline.nextChunk(first.frames)
        timeline.queue(loop(2), UpdateBoundary.LOOP)
        timeline.nextChunk(512)
        val waiting = timeline.position(first.frames - 200L)
        assertEquals(1L, waiting.revision)
        assertEquals(2L, waiting.targetRevision)
        assertEquals(2L, timeline.position(first.frames.toLong()).revision)
    }
    @Test fun arbitraryChunksNeverCrossLoopBoundariesOrLoseFrames() {
        val first = loop(1,137); val timeline = LoopTimeline(first)
        var output = 0L
        repeat(4000) {
            val chunk = timeline.nextChunk(509)
            assertTrue(chunk.frames > 0 && chunk.frames <= 509)
            assertEquals((output % first.frames).toInt(), chunk.offsetFrames)
            output += chunk.frames
            val position = timeline.position(output)
            assertEquals((output % first.frames).toDouble()/first.frames,position.fraction,1e-9)
        }
    }
    @Test fun pauseRetainsPositionBecauseClockOnlyMovesWithHardwareHead() {
        val timeline = LoopTimeline(loop())
        timeline.nextChunk(10000)
        val a = timeline.position(1234)
        timeline.nextChunk(512)
        assertEquals(a,timeline.position(1234))
    }
    @Test fun playbackHeadExtendsUnsigned32BitWrap() {
        val head = PlaybackHeadCounter()
        assertEquals(0xfffffff0L,head.update(-16))
        assertEquals(0x100000010L,head.update(16))
        assertEquals(0x100000020L,head.update(32))
    }
    @Test fun malformedPcmOrTempoIsRejectedBeforePlayback() {
        assertThrows(IllegalArgumentException::class.java) { PcmLoop(byteArrayOf(1),1,120) }
        assertThrows(IllegalArgumentException::class.java) { loop(1,201) }
        assertThrows(IllegalArgumentException::class.java) { PcmLoop(ByteArray(20),1,120) }
    }
    @Test fun revisionHandoffCrossfadeIsBoundedAndPreservesItsEndpoints() {
        val first=loop();val second=loop(2)
        for(i in 0 until first.frames) { first.pcm[i*2]=0xe8.toByte();first.pcm[i*2+1]=3 }
        for(i in 0 until second.frames) { second.pcm[i*2]=0x18;second.pcm[i*2+1]=(-4).toByte() }
        val timeline=LoopTimeline(first);timeline.nextChunk(first.frames)
        timeline.queue(second,UpdateBoundary.LOOP)
        val pcm=transitionPcm(timeline.nextChunk(512))!!
        fun sample(i:Int)=(pcm[i*2].toInt() and 255) or (pcm[i*2+1].toInt() shl 8)
        assertEquals(1000,sample(0));assertEquals(-1000,sample(127));assertEquals(-1000,sample(511))
        assertTrue((0 until 512).all { sample(it) in -1000..1000 })
        assertEquals(0x18,second.pcm[0].toInt()) // original immutable PCM was not changed
    }

}
