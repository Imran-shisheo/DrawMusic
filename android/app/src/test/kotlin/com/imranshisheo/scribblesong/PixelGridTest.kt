package com.imranshisheo.scribblesong
import org.junit.Assert.assertEquals
import org.junit.Test
class PixelGridTest {
    @Test fun sparseSegmentsConnectAndReverseToIdenticalCells() {
        val forward=mutableSetOf<Int>();val reverse=mutableSetOf<Int>()
        addPixelSegment(forward,0,0,39,49);addPixelSegment(reverse,39,49,0,0)
        assertEquals(forward,reverse);assertEquals(50,forward.size)
        val horizontal=mutableSetOf<Int>();addPixelSegment(horizontal,0,25,39,25)
        assertEquals((1000..1039).toSet(),horizontal)
        val dot=mutableSetOf<Int>();addPixelSegment(dot,39,49,39,49)
        assertEquals(setOf(1999),dot)
    }
}
