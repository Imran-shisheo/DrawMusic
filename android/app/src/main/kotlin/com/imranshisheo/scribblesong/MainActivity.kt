package com.imranshisheo.scribblesong

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioAttributes
import android.media.AudioFocusRequest
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var track: AudioTrack? = null
    private var frames = 0
    private var focusRequest: AudioFocusRequest? = null
    private val audioManager by lazy { getSystemService(Context.AUDIO_SERVICE) as AudioManager }
    private val attributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_MEDIA)
        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC).build()
    private val focusListener = AudioManager.OnAudioFocusChangeListener { change ->
        if (change != AudioManager.AUDIOFOCUS_GAIN) track?.pause()
    }
    private val noisyReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) { track?.pause() }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                        frames = pcm.size / 2
                        val next = AudioTrack.Builder().setAudioAttributes(attributes)
                            .setAudioFormat(AudioFormat.Builder().setSampleRate(44100)
                                .setEncoding(AudioFormat.ENCODING_PCM_16BIT).setChannelMask(AudioFormat.CHANNEL_OUT_MONO).build())
                            .setTransferMode(AudioTrack.MODE_STATIC).setBufferSizeInBytes(pcm.size).build()
                        loadStaticPcm(AndroidStaticPcmBuffer(next), pcm)
                        track = next
                        result.success(null)
                    }
                    "play" -> {
                        val active = track ?: error("Prepare audio first")
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
                    "pause" -> { track?.pause(); abandonFocus(); result.success(null) }
                    "stop" -> { releaseTrack(); result.success(null) }
                    "volume" -> { track?.setVolume((call.arguments as Number).toFloat().coerceIn(0f, 1f)); result.success(null) }
                    "position" -> {
                        val position = track?.playbackHeadPosition?.toLong()?.and(0xffffffffL) ?: 0L
                        result.success(if (frames > 0) (position % frames) / 44100.0 else 0.0)
                    }
                    "playing" -> result.success(track?.playState == AudioTrack.PLAYSTATE_PLAYING)
                    else -> result.notImplemented()
                }
            } catch (e: Exception) { result.error("audio_unavailable", e.message, null) }
        }
    }
    private fun abandonFocus() {
        if (Build.VERSION.SDK_INT >= 26) { focusRequest?.let { audioManager.abandonAudioFocusRequest(it) }; focusRequest = null }
        else { @Suppress("DEPRECATION") audioManager.abandonAudioFocus(focusListener) }
    }
    private fun releaseTrack() { track?.let { if(it.playState == AudioTrack.PLAYSTATE_PLAYING) it.pause(); it.release() }; track=null; frames=0; abandonFocus() }
    override fun onPause() { track?.pause(); abandonFocus(); super.onPause() }
    override fun onDestroy() { releaseTrack(); unregisterReceiver(noisyReceiver); super.onDestroy() }
}
