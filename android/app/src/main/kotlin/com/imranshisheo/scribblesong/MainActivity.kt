package com.imranshisheo.scribblesong

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var exportFiles: ExportFilesChannel? = null
    private var videoExports: VideoExportChannel? = null
    private var session: StreamingAudioSession? = null
    private var focusRequest: AudioFocusRequest? = null
    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change != AudioManager.AUDIOFOCUS_GAIN) session?.pause()
    }
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { session?.pause() }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        videoExports=VideoExportChannel(applicationContext,flutterEngine.dartExecutor.binaryMessenger)
        if (Build.VERSION.SDK_INT >= 33) {
            registerReceiver(noisyReceiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY), Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(noisyReceiver, IntentFilter(AudioManager.ACTION_AUDIO_BECOMING_NOISY))
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "scribblesong/audio").setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "prepare" -> {
                        releaseTrack()
                        val pcm = call.argument<ByteArray>("pcm") ?: error("Missing PCM")
                        require(pcm.isNotEmpty() && pcm.size <= 2_000_000 && pcm.size % 2 == 0)
                        session = StreamingAudioSession(PcmLoop(pcm, call.argument<Number>("revision")?.toLong() ?: 0,
                            call.argument<Int>("tempo") ?: 120), attributes)
                        result.success(null)
                    }
                    "play" -> {
                        val active = session ?: error("Prepare audio first")
                        abandonFocus()
                        val granted = if (Build.VERSION.SDK_INT >= 26) {
                            val request = AudioFocusRequest.Builder(AudioManager.AUDIOFOCUS_GAIN)
                                .setAudioAttributes(attributes).setOnAudioFocusChangeListener(focusListener).build()
                            focusRequest = request
                            audioManager.requestAudioFocus(request)
                        } else {
                            @Suppress("DEPRECATION")
                            audioManager.requestAudioFocus(focusListener, AudioManager.STREAM_MUSIC, AudioManager.AUDIOFOCUS_GAIN)
                        }
                        check(granted == AudioManager.AUDIOFOCUS_REQUEST_GRANTED) { "Another app has audio focus" }
                        active.play(); result.success(null)
                    }
                    "pause" -> { session?.pause(smooth=true); abandonFocus(); result.success(null) }
                    "stop" -> { releaseTrack(); result.success(null) }
                    "volume" -> { session?.setVolume((call.arguments as Number).toFloat().coerceIn(0f, 1f)); result.success(null) }
                    "queue" -> {
                        val active = session ?: error("Prepare audio first")
                        val pcm = call.argument<ByteArray>("pcm") ?: error("Missing PCM")
                        val boundary = if (call.argument<String>("boundary") == "beat") UpdateBoundary.BEAT else UpdateBoundary.LOOP
                        active.queue(PcmLoop(pcm, call.argument<Number>("revision")!!.toLong(), call.argument<Int>("tempo")!!), boundary)
                        result.success(null)
                    }
                    "status" -> result.success(session?.status() ?: mapOf("playing" to false, "revision" to -1L,
                        "targetRevision" to -1L, "fraction" to 0.0, "tempo" to 120))
                    "position" -> { val state = session?.status(); result.success(if (state == null) 0.0 else (state["fraction"] as Double) * 480.0 / (state["tempo"] as Int)) }
                    "playing" -> result.success(session?.status()?.get("playing") ?: false)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("audio_unavailable", e.message, null) }
        }
    }
    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) { focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }; focusRequest = null }
        else { @Suppress("DEPRECATION") audioManager.abandonAudioFocus(focusListener) }
    }
    private fun releaseTrack() { session?.close(); session = null; abandonFocus() }
    override fun onPause() { session?.pause(); abandonFocus(); super.onPause() }
    @Deprecated("Required for Android 24–28 document picker compatibility")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if(exportFiles?.activityResult(requestCode,resultCode,data)==true) return
        super.onActivityResult(requestCode,resultCode,data)
    }
    override fun onDestroy() { exportFiles?.close(); videoExports?.close(); releaseTrack(); unregisterReceiver(noisyReceiver); super.onDestroy() }
}
