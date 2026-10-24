package com.imranshisheo.scribblesong

import org.junit.Assert.*
import org.junit.Test

class AudioGainEnvelopeTest {
    @Test fun startsSilentAndReachesExactTargetsWithoutOvershoot() {
        val envelope=AudioGainEnvelope(160)
        assertEquals(0f,envelope.valueAt(0),0f)
        envelope.moveTo(1f,1000)
        assertEquals(0f,envelope.valueAt(1000),0f)
        assertEquals(.5f,envelope.valueAt(1080),.00001f)
        assertFalse(envelope.finished(1080))
        assertEquals(1f,envelope.valueAt(1160),0f)
        assertEquals(1f,envelope.valueAt(2000),0f)
        assertTrue(envelope.finished(1160))
    }
    @Test fun rapidPauseResumeReversesFromCurrentGainWithoutAJump() {
        val envelope=AudioGainEnvelope(160)
        envelope.reset(1f);envelope.moveTo(0f,1000)
        val before=envelope.valueAt(1080)
        envelope.moveTo(1f,1080)
        assertEquals(before,envelope.valueAt(1080),0f)
        assertEquals(.75f,envelope.valueAt(1160),.00001f)
        assertEquals(1f,envelope.valueAt(1240),0f)
    }
    @Test fun immediateInterruptionResetCancelsAnyOutstandingRamp() {
        val envelope=AudioGainEnvelope(160)
        envelope.moveTo(1f,1000)
        envelope.reset(0f)
        assertEquals(0f,envelope.valueAt(5000),0f)
        assertTrue(envelope.finished(5000))
    }
    @Test fun invalidGainsAndDurationsCannotReachTheAudioTrack() {
        assertThrows(IllegalArgumentException::class.java) {AudioGainEnvelope(0)}
        val envelope=AudioGainEnvelope()
        for(value in listOf(Float.NaN,Float.POSITIVE_INFINITY,-1f,2f)) {
            assertThrows(IllegalArgumentException::class.java) {envelope.moveTo(value,100)}
        }
    }
}
