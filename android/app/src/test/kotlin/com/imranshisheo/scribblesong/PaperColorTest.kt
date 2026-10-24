package com.imranshisheo.scribblesong

import org.junit.Assert.assertEquals
import org.junit.Test

class PaperColorTest {
    @Test fun translucentPaperCompositesOverWhiteWithoutDarkeningInk() {
        assertEquals(0xffffffff.toInt(), opaquePaperColor(0x00112233))
        assertEquals(0xff112233.toInt(), opaquePaperColor(0xff112233.toInt()))
        assertEquals(0xff889099.toInt(), opaquePaperColor(0x80112233.toInt()))
        assertEquals(0xff7f7f7f.toInt(), opaquePaperColor(0x80000000.toInt()))
    }
}
