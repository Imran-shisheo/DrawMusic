package com.devwithdelta.doodimo

/** Same integer alpha-over-white policy as the pure Dart document renderer. */
internal fun opaquePaperColor(argb: Int): Int {
    val alpha = argb ushr 24
    fun channel(shift: Int) = (((argb ushr shift) and 255) * alpha + 255 * (255 - alpha) + 127) / 255
    return (0xff shl 24) or (channel(16) shl 16) or (channel(8) shl 8) or channel(0)
}
