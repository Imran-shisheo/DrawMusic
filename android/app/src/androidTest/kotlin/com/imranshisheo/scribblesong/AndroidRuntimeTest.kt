package com.imranshisheo.scribblesong

import android.media.AudioAttributes
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.SystemClock
import androidx.test.ext.junit.runners.AndroidJUnit4
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
    @Test fun cancelDuringVideoEncodingRemovesEveryPartialFile() {
        val (document,pcm)=fixture()
        val output=File(InstrumentationRegistry.getInstrumentation().targetContext.cacheDir,"canceled-video.mp4")
        val cancel=AtomicBoolean(false)
        assertThrows(CancellationException::class.java) {
            CanvasVideoEncoder().export(document,pcm,640,output,cancel) {if(it>.25) cancel.set(true)}
        }
        assertFalse(output.exists())
        assertFalse(File(output.parentFile,".video-${output.name}").exists())
    }
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

}
