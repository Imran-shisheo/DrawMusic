import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../domain/audio_engine.dart';

class AndroidAudioEngine implements AudioEngine {
  static const channel = MethodChannel('scribblesong/audio');
  @override
  Future<void> prepare(Int16List pcm) async {
    await channel.invokeMethod<void>('prepare', {
      'pcm': pcm.buffer.asUint8List(pcm.offsetInBytes, pcm.lengthInBytes),
    });
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
