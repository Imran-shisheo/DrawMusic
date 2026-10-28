package com.imranshisheo.scribblesong

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import androidx.exifinterface.media.ExifInterface
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors
import kotlin.math.max

/** System-owned pickers, immutable normalized assets, no broad media permission. */
internal class BackgroundFilesChannel(private val activity: Activity, messenger: BinaryMessenger,
    private val restoredActivity: Boolean = false, private val canCleanup: () -> Boolean = { true }) {
    companion object { const val PHOTO = 2050; const val CAMERA = 2051; private const val LIMIT = 32L*1024*1024 }
    private val channel = MethodChannel(messenger,"scribblesong/backgrounds")
    private val preferences = activity.getSharedPreferences("background-picker",Context.MODE_PRIVATE)
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val cleanup = BackgroundCleanupGuard()
    private var deferredResult: Triple<Int,Int,Intent?>? = null
    private var pending: MethodChannel.Result? = null
    private var busy = false
    private var closed = false
    init {
        channel.setMethodCallHandler { call,result ->
            if(call.method == "beginCleanup") {
                val token=call.argument<String>("token")
                if(token==null || !token.matches(Regex("[a-zA-Z0-9_-]{1,80}"))) {
                    result.success(mapOf("allowed" to false));return@setMethodCallHandler
                }
                try {
                    val ready=preferences.getString("ready",null)?.let { JSONObject(it) }
                    val pins=if(ready==null) emptyList() else listOf(ready.getString("id"))
                    val unknownReady=ready!=null && (ready.keys().asSequence().toSet()!=setOf("id","width","height","bytes") ||
                        !ready.getString("id").matches(Regex("[a-f0-9]{64}")) ||
                        ready.getInt("width") !in 1..2048 || ready.getInt("height") !in 1..2048 || ready.getLong("bytes") !in 1..LIMIT)
                    val unknownPreferences=preferences.all.keys.any { it !in setOf("ready","source","capture","launch") }
                    val unsafe=unknownPreferences || closed || busy || pending!=null || restoredActivity || !canCleanup() || unknownReady ||
                        preferences.contains("source") || preferences.contains("capture") || preferences.getBoolean("launch",false)
                    val allowed=cleanup.acquire(token,unsafe)
                    result.success(mapOf("allowed" to allowed,"pins" to if(allowed) pins else emptyList<String>()))
                } catch(_:Exception) { result.success(mapOf("allowed" to false)) }
                return@setMethodCallHandler
            }
            if(call.method == "endCleanup") {
                call.argument<String>("token")?.let { cleanup.release(it) }
                result.success(null)
                if(!cleanup.isLocked()) deferredResult?.let { value ->
                    deferredResult=null;activityResult(value.first,value.second,value.third)
                }
                return@setMethodCallHandler
            }
            if(closed || busy || cleanup.isLocked()) { result.error("image_busy","An image action is in progress",null);return@setMethodCallHandler }
            when(call.method) {
                "acknowledge" -> {preferences.edit().remove("ready").apply();result.success(null)}
                "recover" -> {
                    val ready=preferences.getString("ready",null)
                    if(ready!=null) {
                        // A successful delivery is not acknowledged until Dart validates it.
                        val j=JSONObject(ready)
                        result.success(mapOf("id" to j.getString("id"),"width" to j.getInt("width"),"height" to j.getInt("height"),"bytes" to j.getLong("bytes")))
                    } else {
                        val uri=preferences.getString("source",null)
                        if(uri!=null) { pending=result; importUri(Uri.parse(uri)) } else result.success(null)
                    }
                }
                "pickPhoto" -> launch(false,result)
                "capture" -> launch(true,result)
                else -> result.notImplemented()
            }
        }
    }
    private fun launch(camera: Boolean,result: MethodChannel.Result) {
        try {
            pending=result;busy=true
            check(preferences.edit().putBoolean("launch",true).commit()) {"Could not retain picker state"}
            val intent=if(camera) {
                val directory=File(activity.cacheDir,"background-import").apply {mkdirs()}
                val target=File.createTempFile("capture-",".jpg",directory)
                preferences.edit().putString("capture",target.path).apply()
                val uri=FileProvider.getUriForFile(activity,"${activity.packageName}.exports",target)
                Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT,uri)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                    .apply {clipData=android.content.ClipData.newRawUri("Camera image",uri)}
            } else if(Build.VERSION.SDK_INT>=33) Intent(MediaStore.ACTION_PICK_IMAGES).setType("image/*")
            else Intent(Intent.ACTION_OPEN_DOCUMENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent,if(camera) CAMERA else PHOTO)
        } catch(e:android.content.ActivityNotFoundException) {
            cleanupCapture();busy=false;pending=null;result.error(if(camera) "camera_unavailable" else "picker_unavailable","No compatible image activity",null)
        } catch(e:SecurityException) {
            cleanupCapture();busy=false;pending=null;result.error("permission_denied","Image access denied",null)
        } catch(e:Exception) {
            cleanupCapture();busy=false;pending=null;result.error("image_invalid","Could not open image action",null)
        }
    }
    fun activityResult(requestCode:Int,resultCode:Int,data:Intent?):Boolean {
        if(requestCode!=PHOTO && requestCode!=CAMERA) return false
        if(cleanup.isLocked()) { deferredResult=Triple(requestCode,resultCode,data);return true }
        if(resultCode!=Activity.RESULT_OK) {
            cleanupCapture();busy=false;pending?.success(mapOf("cancelled" to true));pending=null;return true
        }
        val uri=if(requestCode==CAMERA) preferences.getString("capture",null)?.let {Uri.fromFile(File(it))} else data?.data
        if(uri==null) {finishError("image_invalid");return true}
        if(requestCode==PHOTO) {
            try {activity.contentResolver.takePersistableUriPermission(uri,Intent.FLAG_GRANT_READ_URI_PERMISSION)} catch(_:Exception) { /* Photo picker grant may be transient; recovery reports failure honestly. */ }
        }
        preferences.edit().putString("source",uri.toString()).apply()
        importUri(uri)
        return true
    }
    private fun importUri(uri:Uri) {
        busy=true
        worker.execute {
            var input:File?=null
            try {
                val imports=File(activity.cacheDir,"background-import").apply{mkdirs()}
                val sourceCopy=File.createTempFile("import-",".tmp",imports)
                input=sourceCopy
                val stream=if(uri.scheme=="file") {
                    val source=File(uri.path ?: error("Missing source")).canonicalFile
                    require(source.path.startsWith(imports.canonicalPath+File.separator))
                    source.inputStream()
                } else activity.contentResolver.openInputStream(uri) ?: error("Image unavailable")
                stream.use {source -> sourceCopy.outputStream().use {out ->
                    val buffer=ByteArray(64*1024);var total=0L
                    while(true) {val read=source.read(buffer);if(read<0) break;total+=read;require(total<=LIMIT);out.write(buffer,0,read)}
                    require(total>0)
                }}
                val ready=BackgroundImageImporter.normalize(activity,sourceCopy)
                // Persist synchronously on the worker before exposing completion.
                // Only Dart's explicit acknowledge removes this recovery record.
                check(preferences.edit().putString("ready",JSONObject(ready).toString()).remove("source").remove("launch").commit()) {
                    "Could not retain completed image metadata"
                }
                main.post {
                    busy=false
                    if(!closed && pending!=null) {
                        pending?.success(ready)
                        pending=null
                    }
                }
            } catch(e:SecurityException) {main.post {finishError("permission_denied")}}
              catch(e:Exception) {main.post {finishError("image_invalid")}}
              finally {input?.delete();cleanupCapture()}
        }
    }
    private fun finishError(code:String) {
        busy=false;preferences.edit().remove("source").remove("launch").apply()
        if(!closed) pending?.error(code,"Image import could not complete",null)
        pending=null
    }
    private fun cleanupCapture() {preferences.getString("capture",null)?.let {path ->
        val file=File(path);if(file.parentFile?.canonicalPath==File(activity.cacheDir,"background-import").canonicalPath) file.delete()
    };preferences.edit().remove("capture").remove("launch").apply()}
    fun close() {closed=true;pending?.error("activity_closed","Image activity was recreated; recover selection",null);pending=null;worker.shutdown();channel.setMethodCallHandler(null)}
}

internal object BackgroundImageImporter {
    fun normalize(context:Context,input:File):Map<String,Any> {
        require(input.length() in 1..(32L*1024*1024))
        val bounds=BitmapFactory.Options().apply{inJustDecodeBounds=true}
        BitmapFactory.decodeFile(input.path,bounds)
        require(bounds.outWidth>0 && bounds.outHeight>0 && bounds.outWidth.toLong()*bounds.outHeight<=80_000_000)
        var sample=1
        while(max(bounds.outWidth,bounds.outHeight)/sample>2048) sample*=2
        val bitmap=BitmapFactory.decodeFile(input.path,BitmapFactory.Options().apply{inSampleSize=sample;inPreferredConfig=Bitmap.Config.ARGB_8888}) ?: error("Unsupported image")
        val orientation=try{ExifInterface(input.path).getAttributeInt(ExifInterface.TAG_ORIENTATION,ExifInterface.ORIENTATION_NORMAL)}catch(_:Exception){ExifInterface.ORIENTATION_NORMAL}
        val matrix=Matrix().apply {
            when(orientation) {
                ExifInterface.ORIENTATION_FLIP_HORIZONTAL -> setScale(-1f,1f)
                ExifInterface.ORIENTATION_ROTATE_180 -> setRotate(180f)
                ExifInterface.ORIENTATION_FLIP_VERTICAL -> setScale(1f,-1f)
                ExifInterface.ORIENTATION_TRANSPOSE -> {setRotate(90f);postScale(-1f,1f)}
                ExifInterface.ORIENTATION_ROTATE_90 -> setRotate(90f)
                ExifInterface.ORIENTATION_TRANSVERSE -> {setRotate(270f);postScale(-1f,1f)}
                ExifInterface.ORIENTATION_ROTATE_270 -> setRotate(270f)
            }
        }
        val normalized=if(matrix.isIdentity) bitmap else Bitmap.createBitmap(bitmap,0,0,bitmap.width,bitmap.height,matrix,true)
        try {
            require(normalized.width<=2048 && normalized.height<=2048)
            val root=File(context.filesDir,"backgrounds").apply{mkdirs()}
            val temporary=File.createTempFile(".image-",".tmp",root)
            try {
                temporary.outputStream().use {output -> check(normalized.compress(Bitmap.CompressFormat.PNG,100,output));output.fd.sync()}
                val digest=MessageDigest.getInstance("SHA-256")
                temporary.inputStream().use {source ->val buffer=ByteArray(65536);while(true){val read=source.read(buffer);if(read<0)break;digest.update(buffer,0,read)}}
                val id=digest.digest().joinToString(""){"%02x".format(it)}
                val target=File(root,"$id.png")
                if(!target.exists()) check(temporary.renameTo(target)) else {
                    check(target.length()==temporary.length())
                    val existing=MessageDigest.getInstance("SHA-256")
                    target.inputStream().use {source -> val buffer=ByteArray(65536);while(true){val read=source.read(buffer);if(read<0)break;existing.update(buffer,0,read)}}
                    check(existing.digest().joinToString(""){"%02x".format(it)}==id) {"Stored background checksum mismatch"}
                }
                return mapOf("id" to id,"width" to normalized.width,"height" to normalized.height,"bytes" to target.length())
            } finally {temporary.delete()}
        } finally {if(normalized!==bitmap)normalized.recycle();bitmap.recycle()}
    }
}
