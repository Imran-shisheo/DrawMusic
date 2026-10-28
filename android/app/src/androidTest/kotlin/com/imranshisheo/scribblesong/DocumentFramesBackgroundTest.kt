package com.imranshisheo.scribblesong

import android.graphics.Bitmap
import androidx.test.platform.app.InstrumentationRegistry
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.security.MessageDigest
import kotlin.math.abs

/** Real Android raster parity for catalog ink, gradients and private photos. */
class DocumentFramesBackgroundTest {
    private fun document():JSONObject=JSONObject().put("background",0xffffffffL).put("strokes",JSONArray())
    private fun paper(kind:String,opacity:Double=1.0):JSONObject=JSONObject().put("kind",kind)
        .put("colors",JSONArray().put(0xffff0000L).put(0xff0000ffL)).put("opacity",opacity)
    private fun assertRgb(expected:Int,actual:Int,tolerance:Int=0) {
        assertEquals(255,actual ushr 24)
        for(shift in intArrayOf(16,8,0)) assertTrue("Expected ${expected.toUInt().toString(16)}; got ${actual.toUInt().toString(16)}",
            abs(((expected ushr shift)and 255)-((actual ushr shift)and 255))<=tolerance)
    }
    @Test fun everyCatalogInstrumentHasTheDeclaredOpaqueInkColor() {
        val names=listOf("keys","mallet","bell","warmSynth","pluck","flute","strings","chime","bass","chip","electronicBass","guitar","saxophone")
        val colors=longArrayOf(0xff7961c6L,0xffa46b16L,0xff287e61L,0xffa64d34L,0xff456990L,0xff536d35L,0xff9b4273L,0xff53648cL,0xff795548L,0xff6c54a2L,0xff925328L,0xff846029L,0xff986b17L)
        val doc=document();val strokes=doc.getJSONArray("strokes")
        for((index,name) in names.withIndex()) {
            val y=(index+.5)/names.size
            strokes.put(JSONObject().put("instrument",name).put("width",.02)
                .put("points",JSONArray().put(JSONArray().put(.1).put(y).put(0)).put(JSONArray().put(.9).put(y).put(1))))
        }
        val renderer=DocumentFrames(doc,400,520)
        try {
            val pixels=renderer.render(0.0)
            for(index in names.indices) assertEquals(names[index],colors[index].toInt(),pixels[(index*40+20)*400+200])
        } finally {renderer.close()}
    }
    @Test fun linearRadialAndTransparentGradientsCompositeOverWhiteWithoutAccumulation() {
        val doc=document().put("paper",paper("linear",.5))
        val renderer=DocumentFrames(doc,100,100)
        try {
            repeat(2) {
                val pixels=renderer.render(0.0)
                assertRgb(0xffbf7fbf.toInt(),pixels[50*100+50],2)
                assertTrue(((pixels[10*100+10] ushr 16)and 255)>((pixels[10*100+10])and 255))
                assertTrue(((pixels[90*100+90])and 255)>((pixels[90*100+90] ushr 16)and 255))
            }
        } finally {renderer.close()}
        val radial=DocumentFrames(document().put("paper",paper("radial",.5)),100,100)
        try {assertRgb(0xffff7f7f.toInt(),radial.render(0.0)[50*100+50],4)}finally{radial.close()}
        val transparent=DocumentFrames(document().put("paper",paper("radial",0.0)),100,100)
        try {assertRgb(0xffffffff.toInt(),transparent.render(0.0)[80*100+80])}finally{transparent.close()}
    }
    @Test fun photoCropQuarterTurnMirrorAndOpacityRenderFromTheVerifiedPrivateAsset() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val root=File(context.cacheDir,"background-raster-${System.nanoTime()}").apply{mkdirs()}
        val bitmap=Bitmap.createBitmap(40,40,Bitmap.Config.ARGB_8888)
        try {
            for(y in 0 until 40) for(x in 0 until 40) bitmap.setPixel(x,y,when {y<20&&x<20->0xffff0000.toInt();y<20->0xff00ff00.toInt();x<20->0xff0000ff.toInt();else->0xffffff00.toInt()})
            val temporary=File(root,"source.png")
            temporary.outputStream().use{check(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))}
            val id=MessageDigest.getInstance("SHA-256").digest(temporary.readBytes()).joinToString(""){"%02x".format(it)}
            val asset=File(root,"$id.png");check(temporary.renameTo(asset))
            fun sample(crop:JSONArray,turns:Int=0,mirror:Boolean=false,opacity:Double=1.0):IntArray {
                val definition=paper("photo",opacity).put("assetId",id).put("crop",crop).put("quarterTurns",turns).put("mirror",mirror)
                val renderer=DocumentFrames(document().put("paper",definition),80,100,root)
                return try {renderer.render(0.0).copyOf()}finally{renderer.close()}
            }
            val whole=JSONArray().put(0).put(0).put(1).put(1)
            val normal=sample(whole)
            assertRgb(0xffff0000.toInt(),normal[20*80+20]);assertRgb(0xff00ff00.toInt(),normal[20*80+60])
            assertRgb(0xff0000ff.toInt(),normal[80*80+20]);assertRgb(0xffffff00.toInt(),normal[80*80+60])
            val cropped=sample(JSONArray().put(0).put(0).put(.5).put(.5))
            assertRgb(0xffff0000.toInt(),cropped[80*80+60])
            val rotated=sample(whole,1)
            assertRgb(0xff0000ff.toInt(),rotated[20*80+20]);assertRgb(0xffff0000.toInt(),rotated[20*80+60])
            val mirrored=sample(whole,1,true)
            assertRgb(0xffffff00.toInt(),mirrored[20*80+20]);assertRgb(0xff00ff00.toInt(),mirrored[20*80+60])
            val faded=sample(whole,opacity=.5)
            assertRgb(0xffff7f7f.toInt(),faded[20*80+20],1)
            asset.writeBytes(byteArrayOf(1,2,3))
            try {DocumentFrames(document().put("paper",paper("photo").put("assetId",id)),80,100,root);fail("Tampered photo unexpectedly rendered")}catch(_:IllegalArgumentException){}
        } finally {bitmap.recycle();root.deleteRecursively()}
    }
    @Test fun missingPhotoIsAnExplicitFailureBeforeEncoding() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val root=File(context.cacheDir,"missing-background-${System.nanoTime()}").apply{mkdirs()}
        try {
            val doc=document().put("paper",paper("photo").put("assetId","a".repeat(64)))
            try {DocumentFrames(doc,80,100,root);fail("Missing photo unexpectedly rendered")}catch(_:IllegalArgumentException){}
        }finally{root.deleteRecursively()}
    }
    @Test fun stagedOnlyPhotoRemainsReadableForTransformedFramesWithoutMovingCleanupFiles() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val root=File(context.cacheDir,"staged-background-raster-${System.nanoTime()}").apply{mkdirs()}
        val stage=File(root,".cleanup-staging").apply{mkdirs()}
        val bitmap=Bitmap.createBitmap(40,40,Bitmap.Config.ARGB_8888)
        try {
            for(y in 0 until 40) for(x in 0 until 40) bitmap.setPixel(x,y,when {
                y<20&&x<20->0xffff0000.toInt();y<20->0xff00ff00.toInt()
                x<20->0xff0000ff.toInt();else->0xffffff00.toInt()
            })
            val temporary=File(stage,"source.png")
            temporary.outputStream().use{check(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))}
            val original=temporary.readBytes()
            val id=MessageDigest.getInstance("SHA-256").digest(original).joinToString(""){"%02x".format(it)}
            val staged=File(stage,"$id.png");check(temporary.renameTo(staged))
            val active=File(root,"$id.png")
            assertFalse("Fixture must exist only in recoverable cleanup staging",active.exists())
            fun sample(crop:JSONArray):IntArray {
                val definition=paper("photo",.5).put("assetId",id).put("crop",crop)
                    .put("quarterTurns",1).put("mirror",true)
                val renderer=DocumentFrames(document().put("paper",definition),80,100,root)
                return try {renderer.render(0.0).copyOf()} finally {renderer.close()}
            }
            // Mirror plus clockwise quarter-turn maps source bottom-right to
            // output top-left; opacity composites each exact quadrant on white.
            val whole=sample(JSONArray().put(0).put(0).put(1).put(1))
            assertRgb(0xffffff7f.toInt(),whole[20*80+20],1)
            assertRgb(0xff7fff7f.toInt(),whole[20*80+60],1)
            assertRgb(0xff7f7fff.toInt(),whole[80*80+20],1)
            assertRgb(0xffff7f7f.toInt(),whole[80*80+60],1)
            // Cropping before the same transforms isolates source top-left red.
            val cropped=sample(JSONArray().put(0).put(0).put(.5).put(.5))
            for(index in intArrayOf(20*80+20,20*80+60,80*80+20,80*80+60)) {
                assertRgb(0xffff7f7f.toInt(),cropped[index],1)
            }
            assertFalse("Rendering must not restore/move a staged asset",active.exists())
            assertTrue(staged.isFile)
            assertArrayEquals("Rendering must leave original staging bytes intact",original,staged.readBytes())
            val files=root.walkTopDown().filter{it.isFile}.map{it.relativeTo(root).invariantSeparatorsPath}.toList()
            assertEquals(listOf(".cleanup-staging/$id.png"),files)
        } finally {bitmap.recycle();root.deleteRecursively()}
    }
}
