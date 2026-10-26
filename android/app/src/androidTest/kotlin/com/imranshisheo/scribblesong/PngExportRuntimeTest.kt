package com.imranshisheo.scribblesong

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.filters.SdkSuppress
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

/** Real Android image decode and public copy; no external receiving app claim. */
@RunWith(AndroidJUnit4::class)
class PngExportRuntimeTest {
    @SdkSuppress(minSdkVersion=29)
    @Test fun publicPngCopyPreservesPixelsDimensionsAndEveryByte() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val source=File(context.cacheDir,"public-image-source.png")
        val bitmap=Bitmap.createBitmap(64,80,Bitmap.Config.ARGB_8888)
        bitmap.eraseColor(0xff22aa44.toInt())
        bitmap.setPixel(32,40,0xff7961c6.toInt())
        var uri:Uri?=null
        try {
            source.outputStream().use {check(bitmap.compress(Bitmap.CompressFormat.PNG,100,it))}
            val bytes=source.readBytes()
            val result=PublicExportSaver.downloads(context,source,"DrawMusic-image-runtime-${System.nanoTime()}.png","image/png")
            uri=result.first
            assertEquals(bytes.size.toLong(),result.second)
            val actual=context.contentResolver.openInputStream(result.first)!!.use {it.readBytes()}
            assertArrayEquals(bytes,actual)
            val decoded=BitmapFactory.decodeByteArray(actual,0,actual.size)
            assertNotNull(decoded)
            try {
                assertEquals(64,decoded.width);assertEquals(80,decoded.height)
                assertEquals(0xff22aa44.toInt(),decoded.getPixel(0,0))
                assertEquals(0xff7961c6.toInt(),decoded.getPixel(32,40))
            } finally {decoded.recycle()}
        } finally {
            bitmap.recycle()
            uri?.let {context.contentResolver.delete(it,null,null)}
            source.delete()
        }
    }
}
