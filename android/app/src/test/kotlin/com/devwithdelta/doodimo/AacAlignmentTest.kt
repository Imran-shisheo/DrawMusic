package com.devwithdelta.doodimo

import org.junit.Assert.*
import org.junit.Test
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.*

class AacAlignmentTest {
    private fun signal():ShortArray=ShortArray(60000) {i ->
        if(i<3000) 0 else {
            val t=(i-3000)/44100.0
            ((sin(t*2*PI*440)+.3*sin(t*2*PI*661))*exp(-t*4)*9000).roundToInt().toShort()
        }
    }
    @Test fun measuresCodecDelayDespiteQuietLeadInAndLossyAmplitude() {
        val reference=signal()
        for(delay in listOf(0,1024,2048,2117)) {
            val decoded=ShortArray(reference.size+8192)
            reference.indices.forEach {decoded[it+delay]=(reference[it]*.92).roundToInt().toShort()}
            assertEquals(delay,AacAlignment.measureDelay(reference,decoded,AtomicBoolean(false)))
        }
    }
    @Test fun completelySilentDrawingNeedsNoPrimingMeasurement() {
        assertEquals(0,AacAlignment.measureDelay(ShortArray(60000),ShortArray(68000),AtomicBoolean(false)))
    }
    @Test fun truncatedOrUnrelatedAudioCannotBePublishedAsAligned() {
        assertThrows(IllegalStateException::class.java) {
            AacAlignment.measureDelay(signal(),ShortArray(1000),AtomicBoolean(false))
        }
        assertThrows(IllegalStateException::class.java) {
            AacAlignment.measureDelay(signal(),ShortArray(68000),AtomicBoolean(false))
        }
    }
    @Test fun measurementRespondsToCancellation() {
        assertThrows(CancellationException::class.java) {
            AacAlignment.measureDelay(signal(),ShortArray(68000),AtomicBoolean(true))
        }
    }
}
