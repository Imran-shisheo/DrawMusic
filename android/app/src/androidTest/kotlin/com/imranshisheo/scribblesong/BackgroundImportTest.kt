package com.imranshisheo.scribblesong

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Color
import androidx.exifinterface.media.ExifInterface
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import java.io.File
import java.security.MessageDigest

class BackgroundImportTest {
    @Test fun jpegOrientationNormalizesAndSharedAssetsRemainImmutable() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val fixture=File.createTempFile("background-native-",".jpg",context.cacheDir)
        var asset:File?=null
        try {
            val bitmap=Bitmap.createBitmap(80,40,Bitmap.Config.ARGB_8888)
            try {bitmap.eraseColor(Color.rgb(160,80,20));fixture.outputStream().use{assertTrue(bitmap.compress(Bitmap.CompressFormat.JPEG,95,it))}}finally{bitmap.recycle()}
            ExifInterface(fixture.path).apply {setAttribute(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_ROTATE_90.toString());saveAttributes()}
            val first=BackgroundImageImporter.normalize(context,fixture)
            assertEquals(40,first["width"]);assertEquals(80,first["height"])
            val id=first["id"] as String
            assertTrue(id.matches(Regex("[a-f0-9]{64}")))
            asset=File(context.filesDir,"backgrounds/$id.png")
            val bytes=asset.readBytes()
            assertEquals(id,MessageDigest.getInstance("SHA-256").digest(bytes).joinToString(""){"%02x".format(it)})
            val reopened=BitmapFactory.decodeFile(asset.path)
            try {assertEquals(40,reopened.width);assertEquals(80,reopened.height)}finally{reopened.recycle()}
            val second=BackgroundImageImporter.normalize(context,fixture)
            assertEquals(first,second);assertArrayEquals(bytes,asset.readBytes())
        } finally {fixture.delete();asset?.delete()}
    }
    @Test fun corruptSourceNeverPublishesAReadyAsset() {
        val context=InstrumentationRegistry.getInstrumentation().targetContext
        val fixture=File.createTempFile("background-bad-",".jpg",context.cacheDir)
        val root=File(context.filesDir,"backgrounds")
        val before=root.list()?.toSet()?:emptySet<String>()
        try {
            fixture.writeBytes(byteArrayOf(1,2,3,4))
            try {BackgroundImageImporter.normalize(context,fixture);fail("Corrupt input unexpectedly imported")}catch(_:IllegalArgumentException){}
            assertEquals(before,root.list()?.toSet()?:emptySet<String>())
        }finally{fixture.delete()}
    }
}
