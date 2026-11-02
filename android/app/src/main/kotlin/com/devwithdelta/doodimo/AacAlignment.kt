package com.devwithdelta.doodimo

import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMuxer
import android.os.SystemClock
import java.io.ByteArrayOutputStream
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.sqrt

/** Measure codec priming from decoded samples; never assume a device's AAC delay. */
internal object AacAlignment {
    private fun checkCancel(cancel: AtomicBoolean) {
        if(cancel.get()) throw CancellationException("Export canceled")
    }
    private fun decode(file: File, cancel: AtomicBoolean): ShortArray {
        val extractor=MediaExtractor()
        var codec: MediaCodec?=null
        var started=false
        try {
            extractor.setDataSource(file.path);extractor.selectTrack(0)
            val format=extractor.getTrackFormat(0)
            format.setInteger(MediaFormat.KEY_PCM_ENCODING,AudioFormat.ENCODING_PCM_16BIT)
            val decoder=MediaCodec.createDecoderByType("audio/mp4a-latm")
            codec=decoder;decoder.configure(format,null,null,0);decoder.start();started=true
            var inputDone=false;var outputDone=false
            var lastWork=SystemClock.elapsedRealtime()
            val bytes=ByteArrayOutputStream()
            val info=MediaCodec.BufferInfo()
            while(!outputDone) {
                checkCancel(cancel)
                check(SystemClock.elapsedRealtime()-lastWork<30000) {"AAC decoder stalled"}
                if(!inputDone) {
                    val index=decoder.dequeueInputBuffer(10000)
                    if(index>=0) {
                        val buffer=decoder.getInputBuffer(index)!!;buffer.clear()
                        val size=extractor.readSampleData(buffer,0)
                        if(size<0) {
                            decoder.queueInputBuffer(index,0,0,0,MediaCodec.BUFFER_FLAG_END_OF_STREAM);inputDone=true
                        } else {
                            decoder.queueInputBuffer(index,0,size,extractor.sampleTime,0);extractor.advance()
                        }
                        lastWork=SystemClock.elapsedRealtime()
                    }
                }
                val index=decoder.dequeueOutputBuffer(info,10000)
                if(index==MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val output=decoder.outputFormat
                    check(output.getInteger(MediaFormat.KEY_SAMPLE_RATE)==44100 && output.getInteger(MediaFormat.KEY_CHANNEL_COUNT)==1)
                    if(output.containsKey(MediaFormat.KEY_PCM_ENCODING)) check(output.getInteger(MediaFormat.KEY_PCM_ENCODING)==AudioFormat.ENCODING_PCM_16BIT)
                } else if(index>=0) {
                    if(info.size>0) {
                        val buffer=decoder.getOutputBuffer(index)!!
                        buffer.position(info.offset);buffer.limit(info.offset+info.size)
                        val block=ByteArray(info.size);buffer.get(block);bytes.write(block)
                        check(bytes.size()<=3_000_000) {"Decoded audio exceeds budget"}
                    }
                    outputDone=info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM!=0
                    decoder.releaseOutputBuffer(index,false);lastWork=SystemClock.elapsedRealtime()
                }
            }
            val data=bytes.toByteArray()
            return ShortArray(data.size/2).also {ByteBuffer.wrap(data).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(it)}
        } finally {
            if(started) try {codec?.stop()} catch(_:Exception){}
            codec?.release();extractor.release()
        }
    }
    internal fun measureDelay(reference: ShortArray, decoded: ShortArray, cancel: AtomicBoolean): Int {
        val onset=reference.indexOfFirst {kotlin.math.abs(it.toInt())>32}
        var delay=0
        if(onset>=0) {
            val start=maxOf(0,onset-128)
            val length=minOf(44100,reference.size-start)
            val maxDelay=minOf(8192,decoded.size-start-length)
            check(maxDelay>=0) {"Encoded audio was truncated"}
            fun correlation(lag:Int,step:Int):Double {
                var dot=0.0;var a=0.0;var b=0.0
                var i=0
                while(i<length) {
                    val x=reference[start+i].toDouble();val y=decoded[start+i+lag].toDouble()
                    dot+=x*y;a+=x*x;b+=y*y;i+=step
                }
                return if(a*b>0) dot/sqrt(a*b) else -1.0
            }
            var best=-1.0
            for(lag in 0..maxDelay step 4) {
                if(lag%128==0) checkCancel(cancel)
                val value=correlation(lag,4)
                if(value>best) {best=value;delay=lag}
            }
            val coarse=delay;best=-1.0
            for(lag in maxOf(0,coarse-4)..minOf(maxDelay,coarse+4)) {
                val value=correlation(lag,1)
                if(value>best) {best=value;delay=lag}
            }
            check(best>.9 && delay<8192) {"Could not align this device's AAC output"}
        }
        return delay
    }
    fun align(encoded: File, output: File, pcm: ByteArray, cancel: AtomicBoolean): Int {
        val reference=ShortArray(pcm.size/2).also {ByteBuffer.wrap(pcm).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer().get(it)}
        val decoded=decode(encoded,cancel)
        val delay=measureDelay(reference,decoded,cancel)
        // Remove whole AAC packets only. Remaining delay is below 1024 samples
        // (23.22 ms), inside the 30 FPS one-frame alignment contract.
        val skip=delay/1024
        val residual=delay%1024
        val packets=(reference.size+residual+1023)/1024
        val extractor=MediaExtractor()
        var muxer:MediaMuxer?=null
        var started=false;var complete=false
        try {
            extractor.setDataSource(encoded.path);extractor.selectTrack(0)
            val writer=MediaMuxer(output.path,MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);muxer=writer
            val track=writer.addTrack(extractor.getTrackFormat(0));writer.start();started=true
            repeat(skip) {check(extractor.advance()) {"AAC priming exceeded output"}}
            val buffer=ByteBuffer.allocateDirect(65536)
            val info=MediaCodec.BufferInfo()
            repeat(packets) {ordinal ->
                checkCancel(cancel);buffer.clear()
                val size=extractor.readSampleData(buffer,0)
                check(size>0) {"AAC release tail was truncated"}
                info.set(0,size,ordinal*1024*1_000_000L/44100,0)
                buffer.position(0);buffer.limit(size);writer.writeSampleData(track,buffer,info)
                extractor.advance()
            }
            writer.stop();started=false;complete=true
            return residual
        } finally {
            extractor.release()
            if(started) try {muxer?.stop()} catch(_:Exception){}
            muxer?.release();if(!complete) output.delete()
        }
    }
}
