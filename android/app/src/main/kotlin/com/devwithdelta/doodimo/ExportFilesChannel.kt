package com.devwithdelta.doodimo

import android.app.Activity
import android.content.ClipData
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.annotation.RequiresApi
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/** Public copies require an explicit app action; no broad storage permission. */
internal object PublicExportSaver {
    fun copy(context: Context, source: File, uri: Uri): Long {
        val count=source.inputStream().use {input ->
            (context.contentResolver.openOutputStream(uri,"w") ?: error("Destination unavailable")).use {output -> input.copyTo(output)}
        }
        check(count>0 && count==source.length()) {"Incomplete public copy"}
        context.contentResolver.openFileDescriptor(uri,"r")?.use {descriptor ->
            if(descriptor.statSize>=0) check(descriptor.statSize==count) {"Public copy length mismatch"}
        } ?: error("Could not verify public copy")
        return count
    }
    @RequiresApi(Build.VERSION_CODES.Q)
    fun downloads(context: Context, source: File, name: String, mime: String): Pair<Uri,Long> {
        check(Build.VERSION.SDK_INT>=29)
        val resolver=context.contentResolver
        val values=ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME,name)
            put(MediaStore.MediaColumns.MIME_TYPE,mime)
            put(MediaStore.MediaColumns.RELATIVE_PATH,"${Environment.DIRECTORY_DOWNLOADS}/DrawMusic")
            put(MediaStore.MediaColumns.IS_PENDING,1)
        }
        val uri=resolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI,values) ?: error("Downloads unavailable")
        var complete=false
        try {
            val bytes=copy(context,source,uri)
            check(resolver.update(uri,ContentValues().apply {put(MediaStore.MediaColumns.IS_PENDING,0)},null,null)==1)
            complete=true
            return uri to bytes
        } finally {if(!complete) resolver.delete(uri,null,null)}
    }
}

internal class ExportFilesChannel(private val activity: Activity, messenger: BinaryMessenger) {
    private data class Request(val source: File,val name: String,val mime: String,val result: MethodChannel.Result)
    private val channel=MethodChannel(messenger,"scribblesong/export-files")
    private val worker=Executors.newSingleThreadExecutor()
    private val main=Handler(Looper.getMainLooper())
    private var pending:Request?=null
    private var busy=false
    private var closed=false
    companion object {const val CREATE_DOCUMENT=2047}
    init {
        channel.setMethodCallHandler {call,result ->
            if(busy || closed) {result.error("export_busy","Another file action is in progress",null);return@setMethodCallHandler}
            try {
                val path=call.argument<String>("path") ?: error("Missing export")
                val root=File(activity.getDir("flutter",Context.MODE_PRIVATE),"exports").canonicalFile
                val source=File(path).canonicalFile
                require(source.path.startsWith(root.path+File.separator) && source.isFile && source.length()>0) {"Export unavailable"}
                val extension=source.extension.lowercase()
                val mime=when(extension) {"mid" -> "audio/midi";"wav" -> "audio/wav";"mp4" -> "video/mp4";"png" -> "image/png";else -> error("Unsupported export")}
                require(call.argument<String>("mime")==mime)
                val name=call.argument<String>("name") ?: error("Missing file name")
                require(name.length in 1..180 && !name.contains('/') && !name.contains('\\') && name.none {it<' ' || it=='\u007f'} && name.endsWith(".$extension")) {"Invalid file name"}
                val request=Request(source,name,mime,result)
                when(call.method) {
                    "open" -> {
                        busy=true
                        perform(request) {
                            val cache=File(activity.cacheDir,"open-exports").apply {mkdirs()}
                            cache.listFiles()?.filter {System.currentTimeMillis()-it.lastModified()>24*60*60*1000L}?.forEach {it.delete()}
                            val copy=File(cache,"${System.nanoTime()}-$name")
                            val temporary=File(cache,".${copy.name}.tmp")
                            try {source.copyTo(temporary);check(temporary.renameTo(copy)) {"Could not publish open-file copy"}}
                            finally {temporary.delete()}
                            val uri=FileProvider.getUriForFile(activity,"${activity.packageName}.exports",copy)
                            main.post {
                                try {
                                    val intent=Intent(Intent.ACTION_VIEW).apply {
                                        setDataAndType(uri,mime)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                        clipData=ClipData.newRawUri(name,uri)
                                    }
                                    val chooserTitle=call.argument<String>("chooserTitle")?.takeIf {it.length in 1..160 && it.none {c->c<' ' || c=='\u007f'}} ?: activity.getString(R.string.export_open_chooser_title)
                                    activity.startActivity(Intent.createChooser(intent,chooserTitle))
                                    result.success(null)
                                } catch(e:Exception) {copy.delete();result.error("open_unavailable",e.message,null)}
                                finally {busy=false}
                            }
                        }
                    }
                    "save" -> {
                        busy=true
                        if(Build.VERSION.SDK_INT>=29) perform(request) {
                            val (uri,bytes)=PublicExportSaver.downloads(activity,source,name,mime)
                            main.post {busy=false;result.success(mapOf("uri" to uri.toString(),"bytes" to bytes,"destination" to "Downloads/DrawMusic"))}
                        } else {
                            pending=request
                            @Suppress("DEPRECATION")
                            activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE);type=mime;putExtra(Intent.EXTRA_TITLE,name)
                            },CREATE_DOCUMENT)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch(e:Exception) {busy=false;pending=null;result.error("export_file_unavailable",e.message,null)}
        }
    }
    private fun perform(request:Request, action:()->Unit) {
        worker.execute {
            try {action()}
            catch(e:Exception) {main.post {busy=false;request.result.error("export_file_failed",e.message,null)}}
        }
    }
    fun activityResult(requestCode:Int,resultCode:Int,data:Intent?):Boolean {
        if(requestCode!=CREATE_DOCUMENT) return false
        val request=pending ?: return true
        pending=null
        val uri=data?.data
        if(resultCode!=Activity.RESULT_OK || uri==null) {
            busy=false;request.result.success(mapOf("cancelled" to true));return true
        }
        perform(request) {
            try {
                val bytes=PublicExportSaver.copy(activity,request.source,uri)
                main.post {busy=false;request.result.success(mapOf("uri" to uri.toString(),"bytes" to bytes,"destination" to "the selected location"))}
            } catch(e:Exception) {
                try {activity.contentResolver.delete(uri,null,null)} catch(_:Exception){}
                throw e
            }
        }
        return true
    }
    fun close() {
        closed=true;channel.setMethodCallHandler(null)
        pending?.result?.error("export_file_closed","File picker closed with the app",null);pending=null
        worker.shutdown()
    }
}
