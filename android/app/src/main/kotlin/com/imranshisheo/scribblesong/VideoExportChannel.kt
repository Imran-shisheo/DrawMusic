package com.imranshisheo.scribblesong

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.CancellationException
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

internal class VideoExportChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "scribblesong/video")
    private val main = Handler(Looper.getMainLooper())
    private val jobs = ConcurrentHashMap<String, AtomicBoolean>()
    private val executor = Executors.newSingleThreadExecutor { task -> Thread(task,"ScribbleSong-export").apply { isDaemon=true } }
    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "cancel" -> { jobs[call.arguments as? String]?.set(true); result.success(null) }
                "export" -> {
                    try {
                        val id=call.argument<String>("jobId")!!
                        require(id.matches(Regex("[a-zA-Z0-9_-]{1,80}")))
                        val document=call.argument<String>("document")!!
                        require(document.length<=20_000_000)
                        val pcm=call.argument<ByteArray>("pcm")!!
                        val width=call.argument<Int>("width")!!
                        val output=File(call.argument<String>("path")!!).canonicalFile
                        require(output.path.startsWith(File(context.applicationInfo.dataDir).canonicalPath + File.separator))
                        val cancel=AtomicBoolean(false)
                        check(jobs.putIfAbsent(id,cancel)==null) { "Export already exists" }
                        executor.execute {
                            try {
                                val metadata=CanvasVideoEncoder().export(document,pcm,width,output,cancel) { progress ->
                                    main.post { channel.invokeMethod("progress",mapOf("jobId" to id,"progress" to progress)) }
                                }
                                main.post { result.success(metadata) }
                            } catch (_: CancellationException) {
                                main.post { result.error("export_cancelled","Export canceled",null) }
                            } catch (error: Exception) {
                                output.delete()
                                main.post { result.error("video_unavailable",error.message ?: "Video export failed. Try compact resolution.",null) }
                            } finally { jobs.remove(id) }
                        }
                    } catch (error: Exception) { result.error("video_unavailable",error.message,null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    fun close() { jobs.values.forEach { it.set(true) }; executor.shutdown(); channel.setMethodCallHandler(null) }
}
