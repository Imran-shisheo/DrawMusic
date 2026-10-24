package com.imranshisheo.scribblesong

/** Monotonic native control envelope; it never schedules musical events. */
internal class AudioGainEnvelope(private val durationNanos:Long=16_000_000L) {
    private var from=0f
    private var target=0f
    private var started=0L
    init {require(durationNanos>0)}
    fun valueAt(now:Long):Float {
        val fraction=((now-started).coerceIn(0,durationNanos)).toDouble()/durationNanos
        return (from+(target-from)*fraction).toFloat().coerceIn(0f,1f)
    }
    fun moveTo(value:Float,now:Long) {
        require(value.isFinite() && value in 0f..1f)
        from=valueAt(now);target=value;started=now
    }
    fun reset(value:Float) {require(value.isFinite() && value in 0f..1f);from=value;target=value}
    fun finished(now:Long):Boolean=from==target || now-started>=durationNanos
}
