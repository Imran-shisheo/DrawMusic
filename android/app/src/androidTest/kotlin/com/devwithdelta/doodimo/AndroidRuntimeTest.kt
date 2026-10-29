package com.devwithdelta.doodimo

import android.media.AudioAttributes
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.PI
import kotlin.math.roundToInt
import kotlin.math.sin

@RunWith(AndroidJUnit4::class)
class AndroidRuntimeTest {
    private fun loop(revision: Long, tempo: Int): PcmLoop {
        val frames=(480.0/tempo*44100).roundToInt()
        val pcm=ByteArray(frames*2)
        for(i in 0 until frames) {
            val sample=(sin(i*2*PI*440/44100)*2000).roundToInt()
            pcm[i*2]=sample.toByte();pcm[i*2+1]=(sample shr 8).toByte()
        }
        return PcmLoop(pcm,revision,tempo)
    }
    private fun until(timeoutMs: Long=5000, condition:()->Boolean) {
        val deadline=SystemClock.elapsedRealtime()+timeoutMs
        while(!condition()) {check(SystemClock.elapsedRealtime()<deadline) {"Android audio clock did not reach the expected state"};SystemClock.sleep(10)}
    }
    @Test fun streamingTrackAdvancesRealAndroidClockAndAppliesBoundaryRevisions() {
        val attributes=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        val session=StreamingAudioSession(loop(1,200),attributes)
        try {
            session.play()
            until { (session.status()["fraction"] as Double)>.01 }
            session.queue(loop(2,120),UpdateBoundary.BEAT)
            until { session.status()["revision"]==2L }
            assertEquals(120,session.status()["tempo"])
            session.pause();SystemClock.sleep(100)
            val frozen=session.status()["fraction"] as Double
            SystemClock.sleep(150)
            assertEquals(frozen,session.status()["fraction"] as Double,1.0/44100)
            assertEquals(false,session.status()["playing"])
            session.play()
            until { session.status()["playing"]==true && (session.status()["fraction"] as Double)!=frozen }
            session.queue(loop(3,120),UpdateBoundary.LOOP)
            until(6000) {session.status()["revision"]==3L}
            assertTrue((session.status()["fraction"] as Double)<.15)
        } finally {session.close()}
    }
    private fun fixture(): Pair<String,ByteArray> {
        val assets=InstrumentationRegistry.getInstrumentation().context.assets
        val document=assets.open("project.json").bufferedReader().use {it.readText()}
        val wav=assets.open("original-loop.wav").use {it.readBytes()}
        return document to wav.copyOfRange(44,wav.size)
    }
    @Test fun realMp4ContainsH264AndAacFromTheOriginalFixture() {
        val (document,pcm)=fixture()
        val output=File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"fixture-video.mp4")
        output.delete()
        val metadata=CanvasVideoEncoder().export(document,pcm,1080,output,AtomicBoolean(false)) {}
        assertEquals(1080,metadata["width"]);assertEquals(1350,metadata["height"])
        val extractor=MediaExtractor()
        try {
            extractor.setDataSource(output.path)
            val types=(0 until extractor.trackCount).map {extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME)}
            assertTrue(types.contains("video/avc"));assertTrue(types.contains("audio/mp4a-latm"))
            assertTrue(output.length()>10000)
        } finally {extractor.release()}
    }
    @Test(timeout=240000) fun compactSixtyFpsUsesRealCodecTimestampsAndReportsBoundedRendering() {
        profileSixtyFps(640,"fixture-video-60.mp4","video-60-profile.json")
    }
    @Test(timeout=360000) fun hdSixtyFpsUsesRealCodecTimestampsAndReportsBoundedRendering() {
        profileSixtyFps(1080,"fixture-video-hd-60.mp4","video-hd-60-profile.json")
    }
    private fun profileSixtyFps(width: Int, fixtureName: String, reportName: String) {
        val (document,pcm)=fixture()
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val output=File(context.cacheDir,fixtureName)
        val report=File(context.cacheDir,reportName)
        output.delete()
        val started=SystemClock.elapsedRealtime()
        val initialPss=android.os.Debug.getPss()
        var peakPss=initialPss
        var progressBucket=-1
        var count=0
        var minStep=Long.MAX_VALUE
        var maxStep=0L
        var firstPts=-1L
        var lastPts=-1L
        var videoDuration=0L
        var audioDuration=0L
        var passed=false
        try {
            val metadata=CanvasVideoEncoder().export(document,pcm,width,output,AtomicBoolean(false),60) { progress ->
                val bucket=(progress*10).toInt()
                if(bucket!=progressBucket) {
                    progressBucket=bucket
                    peakPss=maxOf(peakPss,android.os.Debug.getPss())
                }
            }
            assertEquals(60,metadata["fps"])
            assertEquals(width,metadata["width"])
            assertEquals(width*5/4,metadata["height"])
            val extractor=MediaExtractor()
            try {
                extractor.setDataSource(output.path)
                var videoTrack=-1
                for(track in 0 until extractor.trackCount) {
                    val format=extractor.getTrackFormat(track)
                    when(format.getString(MediaFormat.KEY_MIME)) {
                        "video/avc" -> {
                            videoTrack=track
                            assertEquals(60,format.getInteger(MediaFormat.KEY_FRAME_RATE))
                            assertEquals(width,format.getInteger(MediaFormat.KEY_WIDTH))
                            assertEquals(width*5/4,format.getInteger(MediaFormat.KEY_HEIGHT))
                            videoDuration=format.getLong(MediaFormat.KEY_DURATION)
                        }
                        "audio/mp4a-latm" -> audioDuration=format.getLong(MediaFormat.KEY_DURATION)
                    }
                }
                assertTrue(videoTrack>=0)
                assertTrue(audioDuration>0)
                extractor.selectTrack(videoTrack)
                while(extractor.sampleTime>=0) {
                    val pts=extractor.sampleTime
                    if(firstPts<0) firstPts=pts
                    if(lastPts>=0) {
                        val step=pts-lastPts
                        assertTrue("Encoded video timestamps must advance",step>0)
                        minStep=minOf(minStep,step);maxStep=maxOf(maxStep,step)
                    }
                    lastPts=pts;count++
                    if(!extractor.advance()) break
                }
            } finally {extractor.release()}
            assertEquals(0L,firstPts)
            assertTrue("60 FPS must have real 16.667 ms samples",minStep in 16665L..16668L)
            assertTrue("60 FPS cannot be just relabeled 30 FPS",maxStep in 16665L..16668L)
            assertTrue(count>200)
            assertTrue(kotlin.math.abs(videoDuration-audioDuration)<=18667L)
            assertTrue(kotlin.math.abs(lastPts+16667L-videoDuration)<=2000L)
            assertTrue(output.length()>10000)
            assertFalse(File(output.parentFile,".video-${output.name}").exists())
            passed=true
        } finally {
            report.writeText(org.json.JSONObject().put("passed",passed)
                .put("width",width).put("height",width*5/4).put("requestedFps",60)
                .put("encodedVideoSamples",count).put("firstPtsUs",firstPts).put("lastPtsUs",lastPts)
                .put("minVideoStepUs",if(count>1) minStep else 0).put("maxVideoStepUs",maxStep)
                .put("videoDurationUs",videoDuration).put("audioDurationUs",audioDuration)
                .put("elapsedMs",SystemClock.elapsedRealtime()-started)
                .put("initialPssKb",initialPss).put("peakSampledPssKb",peakPss)
                .put("finalPssKb",android.os.Debug.getPss())
                .put("rendererBitmapAndPixelArrayBytes",width*(width*5/4)*8)
                .put("scope","API 35 emulator codec/export profile. Reuses one bitmap and pixel array plus bounded codec buffers; sampled whole-process PSS is not a physical-device FPS/memory guarantee. No frames accumulate for the whole video.")
                .toString(2))
        }
    }

    @Test fun unsupportedVideoFrameRateFailsBeforeCreatingFiles() {
        val (document,pcm)=fixture()
        val output=File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"unsupported-fps.mp4")
        output.delete()
        assertThrows(IllegalArgumentException::class.java) {
            CanvasVideoEncoder().export(document,pcm,640,output,AtomicBoolean(false),24) {}
        }
        assertFalse(output.exists())
        assertFalse(File(output.parentFile,".video-${output.name}").exists())
    }

    @Test fun cancelDuringVideoEncodingRemovesEveryPartialFile() {
        val (document,pcm)=fixture()
        val output=File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"canceled-video.mp4")
        for(fps in listOf(30,60)) {
            val cancel=AtomicBoolean(false)
            assertThrows(CancellationException::class.java) {
                CanvasVideoEncoder().export(document,pcm,640,output,cancel,fps) {if(it>.25) cancel.set(true)}
            }
            assertFalse(output.exists())
            assertFalse(File(output.parentFile,".video-${output.name}").exists())
        }
    }
    @Test(timeout=240000) fun cancelHdSixtyFpsRemovesEveryPartialFileAndKeepsRetryUsable() {
        val (document,pcm)=fixture()
        val output=File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"canceled-hd-sixty.mp4")
        val cancel=AtomicBoolean(false)
        assertThrows(CancellationException::class.java) {
            CanvasVideoEncoder().export(document,pcm,1080,output,cancel,60) {if(it>.25) cancel.set(true)}
        }
        assertFalse(output.exists())
        assertFalse(File(output.parentFile,".video-${output.name}").exists())
        // A canceled HD job must not poison the encoder used by the next job.
        CanvasVideoEncoder().export(document,pcm,640,output,AtomicBoolean(false),30) {}
        assertTrue(output.length()>10000)
        output.delete()
    }
    @SdkSuppress(minSdkVersion=29)
    @Test fun explicitDownloadsCopyContainsTheOriginalBytes() {
        org.junit.Assume.assumeTrue(android.os.Build.VERSION.SDK_INT>=29)
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val bytes=InstrumentationRegistry.getInstrumentation().context.assets.open("original-loop.wav").use {it.readBytes()}
        val source=File(context.cacheDir,"public-copy-source.wav")
        source.writeBytes(bytes)
        var uri:android.net.Uri?=null
        try {
            val result=PublicExportSaver.downloads(context,source,"DrawMusic-runtime-${System.nanoTime()}.wav","audio/wav")
            uri=result.first
            assertEquals(bytes.size.toLong(),result.second)
            val actual=context.contentResolver.openInputStream(result.first)!!.use {it.readBytes()}
            assertArrayEquals(bytes,actual)
        } finally {
            uri?.let {context.contentResolver.delete(it,null,null)}
            source.delete()
        }
    }

    @Test fun pixelStyleUsesBlockCellsAndLegacyDocumentsKeepSmoothMarks() {
        val source="""{"background":4294967295,"style":"pixel","strokes":[{"instrument":"keys","width":0.009,"points":[[0.5,0.5,0]]}]}"""
        val document=org.json.JSONObject(source)
        val pixel=DocumentFrames(document,400,500)
        try {assertEquals(0xff7961c6.toInt(),pixel.render(.05)[255*400+205])} finally {pixel.close()}
        document.remove("style")
        val smooth=DocumentFrames(document,400,500)
        try {assertEquals(0xffffffff.toInt(),smooth.render(.05)[255*400+205])} finally {smooth.close()}
    }

    @Test fun translucentPaperRendersOverWhiteWithoutAccumulationOrFadedInk() {
        for (paper in listOf(0x00112233L,0x80112233L,0xff112233L)) {
            val document=org.json.JSONObject("""{"background":$paper,"strokes":[{"instrument":"keys","width":0.1,"points":[[0.2,0.5,0],[0.8,0.5,1]]}]}""")
            val frames=DocumentFrames(document,64,80)
            try {
                repeat(2) {
                    val pixels=frames.render(.05)
                    assertEquals(opaquePaperColor(paper.toInt()),pixels[79*64+63])
                    assertEquals(0xff7961c6.toInt(),pixels[40*64+32])
                }
            } finally {frames.close()}
        }
    }

    @Test fun fadedPauseCanBeReversedWithoutAStalePauseOrClockReset() {
        val attributes=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA).setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        val session=StreamingAudioSession(loop(1,120),attributes)
        try {
            session.play();until {(session.status()["fraction"] as Double)>.01}
            session.pause(smooth=true);SystemClock.sleep(4);session.play()
            SystemClock.sleep(80)
            assertEquals(true,session.status()["playing"])
            repeat(5) {
                session.pause(smooth=true);until {session.status()["playing"]==false}
                assertEquals(false,session.status()["playing"])
                val frozen=session.status()["fraction"] as Double
                repeat(5) {
                    SystemClock.sleep(10)
                    assertEquals(frozen,session.status()["fraction"] as Double,1.0/44100)
                }
                session.setVolume(0f);session.play()
                until {(session.status()["fraction"] as Double)!=frozen}
            }
            session.pause()
            val immediate=session.status()["fraction"] as Double
            SystemClock.sleep(50)
            assertEquals(immediate,session.status()["fraction"] as Double,1.0/44100)
        } finally {session.close();session.close()}
    }

    @Test(timeout=660000) fun tenMinuteStreamingSoakKeepsClockMovingAndReportsMemory() {
        val attributes=AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
        val session=StreamingAudioSession(loop(901,120),attributes)
        val output=File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"audio-soak.json")
        val started=SystemClock.elapsedRealtime()
        var sampledAt=started
        var progressedAt=started
        var maxStallMs=0L
        var maxGapMs=0L
        var maxPssKb=0L
        val initialPssKb=android.os.Debug.getPss()
        var previous=0.0
        var cycles=0
        var samples=0
        var passed=false
        try {
            session.play()
            while(SystemClock.elapsedRealtime()-started<600000) {
                SystemClock.sleep(250)
                val now=SystemClock.elapsedRealtime()
                val status=session.status()
                assertEquals(true,status["playing"])
                assertEquals(901L,status["revision"])
                assertEquals(120,status["tempo"])
                val fraction=status["fraction"] as Double
                assertTrue(fraction>=0.0 && fraction<1.0)
                maxGapMs=maxOf(maxGapMs,now-sampledAt)
                if(fraction<previous-.5) cycles++
                if(kotlin.math.abs(fraction-previous)>1.0/44100) progressedAt=now
                maxStallMs=maxOf(maxStallMs,now-progressedAt)
                assertTrue("Hardware clock stopped progressing for ten seconds",now-progressedAt<10000)
                previous=fraction;sampledAt=now;samples++
                if(samples%20==0) maxPssKb=maxOf(maxPssKb,android.os.Debug.getPss())
            }
            assertTrue("Ten-minute test did not observe enough clock samples",samples>=1000)
            assertTrue("Ten-minute output did not complete 120 four-second loops",cycles>=120)
            passed=true
        } finally {
            session.close()
            val elapsed=SystemClock.elapsedRealtime()-started
            output.writeText(org.json.JSONObject().put("passed",passed)
                .put("durationMs",elapsed).put("samples",samples).put("observedLoops",cycles)
                .put("maxSampleGapMs",maxGapMs).put("maxObservedNoProgressMs",maxStallMs)
                .put("initialPssKb",initialPssKb).put("peakSampledPssKb",maxPssKb)
                .put("finalPssKb",android.os.Debug.getPss())
                .put("scope","Ten-minute API 35 emulator native AudioTrack clock/output soak. PSS is sampled whole-process memory; not physical audibility, latency, drawing FPS or a history RSS budget guarantee.")
                .toString(2))
        }
    }

}
