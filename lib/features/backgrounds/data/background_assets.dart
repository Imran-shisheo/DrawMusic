import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../domain/background.dart';

class BackgroundAsset {
  const BackgroundAsset(this.id, this.width, this.height, this.bytes);
  final String id;
  final int width, height, bytes;
}

/// Committed imports are immutable content-addressed PNGs. There is deliberately
/// no destructive GC: an old revision, Undo or another project's duplicate may
/// still reference an asset. Native imports never overwrite another asset.
class BackgroundAssets {
  BackgroundAssets(this.root);
  final Directory root;
  static Future<BackgroundAssets> application() async => BackgroundAssets(
    Directory('${(await getApplicationSupportDirectory()).path}/backgrounds'),
  );
  File file(String id) {
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const FormatException('Invalid background asset');
    }
    return File('${root.path}/$id.png');
  }

  Future<ui.Image?> decode(
    BackgroundDefinition paper, {
    int maxWidth = 1080,
    int maxHeight = 1350,
  }) async {
    if (paper.kind != BackgroundKind.photo) return null;
    final source = file(paper.assetId!);
    if (!await source.exists()) return null;
    final size = await source.length();
    if (size == 0 || size > 32 * 1024 * 1024) {
      throw const FormatException('Invalid background image size');
    }
    final bytes = await source.readAsBytes();
    if (sha256.convert(bytes).toString() != paper.assetId) {
      throw const FormatException('Background checksum mismatch');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width <= 0 ||
          descriptor.height <= 0 ||
          descriptor.width > 2048 ||
          descriptor.height > 2048 ||
          maxWidth < 1 ||
          maxHeight < 1 ||
          maxWidth > 4096 ||
          maxHeight > 4096) {
        throw const FormatException('Invalid background image dimensions');
      }
      final ratio = math.min(
        1.0,
        math.min(maxWidth / descriptor.width, maxHeight / descriptor.height),
      );
      codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * ratio).round()),
        targetHeight: math.max(1, (descriptor.height * ratio).round()),
      );
      return (await codec.getNextFrame()).image;
    } finally {
      codec?.dispose();
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}

class BackgroundPicker {
  const BackgroundPicker();
  static const _channel = MethodChannel('scribblesong/backgrounds');
  Future<BackgroundAsset?> pick({bool camera = false}) =>
      _request(camera ? 'capture' : 'pickPhoto');
  Future<BackgroundAsset?> recover() => _request('recover');
  Future<BackgroundAsset?> _request(String method) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(method);
    if (result == null || result['cancelled'] == true) return null;
    final id = result['id'] as String;
    if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(id)) {
      throw const FormatException('Invalid imported asset');
    }
    final width = result['width'] as int,
        height = result['height'] as int,
        bytes = result['bytes'] as int;
    if (width < 1 ||
        height < 1 ||
        width > 2048 ||
        height > 2048 ||
        bytes < 1 ||
        bytes > 32 * 1024 * 1024) {
      throw const FormatException('Invalid imported image metadata');
    }
    try {
      await _channel.invokeMethod<void>('acknowledge');
    } on MissingPluginException {
      /* Older hosts need no acknowledgement. */
    } on PlatformException {
      /* Acknowledgement never invalidates a valid asset. */
    }
    return BackgroundAsset(id, width, height, bytes);
  }
}

Future<ui.Image?> loadBackgroundImage(
  BackgroundDefinition paper, {
  int maxWidth = 1080,
  int maxHeight = 1350,
  BackgroundAssets? assets,
}) async => (assets ?? await BackgroundAssets.application()).decode(
  paper,
  maxWidth: maxWidth,
  maxHeight: maxHeight,
);
