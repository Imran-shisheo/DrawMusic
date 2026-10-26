import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../domain/audio_engine.dart';

// iOS native implementation: ios/Runner/DrawMusicAudio.swift.
// Source contract only until compiled and exercised on a Mac/device.
class IosAudioEngine implements AudioEngine {
  static const channel = MethodChannel('scribblesong/audio');
  @override
  Future<void> prepare(
    Int16List pcm, {
    int revision = 0,
    int tempo = 120,
  }) async {
    await channel.invokeMethod<void>('prepare', {
      'pcm': pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
      'revision': revision,
      'tempo': tempo,
    });
  }

  @override
  Future<void> queue(
    Int16List pcm, {
    required int revision,
    required int tempo,
    required UpdateBoundary boundary,
  }) => channel.invokeMethod<void>('queue', {
    'pcm': pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
    'revision': revision,
    'tempo': tempo,
    'boundary': boundary.name,
  });
  @override
  Future<TransportStatus> status() async {
    final value = await channel.invokeMapMethod<String, dynamic>('status');
    if (value == null) {
      throw PlatformException(
        code: 'audio_unavailable',
        message: 'Audio status unavailable. Please retry.',
      );
    }
    return TransportStatus(
      playing: value['playing'] as bool,
      revision: (value['revision'] as num).toInt(),
      targetRevision: (value['targetRevision'] as num).toInt(),
      fraction: (value['fraction'] as num).toDouble(),
      tempo: (value['tempo'] as num).toInt(),
    );
  }

  @override
  Future<void> play() => channel.invokeMethod<void>('play');
  @override
  Future<void> pause() => channel.invokeMethod<void>('pause');
  @override
  Future<void> stop() => channel.invokeMethod<void>('stop');
  @override
  Future<double> positionSeconds() async =>
      (await channel.invokeMethod<num>('position'))?.toDouble() ?? 0;
  @override
  Future<bool> isPlaying() async =>
      await channel.invokeMethod<bool>('playing') ?? false;
  @override
  Future<void> setVolume(double value) =>
      channel.invokeMethod<void>('volume', value);
}
