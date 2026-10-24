package com.imranshisheo.scribblesong

import kotlin.math.abs
import kotlin.math.max
import kotlin.math.roundToInt

/** Same symmetric fixed-grid interpolation as Dart's display-only policy. */
internal fun addPixelSegment(cells: MutableSet<Int>, ax: Int, ay: Int, bx: Int, by: Int) {
    val steps=max(abs(bx-ax),abs(by-ay))
    cells.add(ay*40+ax)
    for(i in 1..steps) {
        val x=((ax*(steps-i)+bx*i).toDouble()/steps).roundToInt()
        val y=((ay*(steps-i)+by*i).toDouble()/steps).roundToInt()
        cells.add(y*40+x)
    }
}
