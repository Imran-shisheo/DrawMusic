import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/strings.dart';
import '../domain/background.dart';
import '../data/background_assets.dart';
import 'background_painter.dart';

/// Expanded background transaction. Imported assets are immutable; Cancel never
/// changes the document and never deletes a file another revision may reference.
Future<BackgroundDefinition?> showBackgroundPanel(
  BuildContext context,
  BackgroundDefinition initial, {
  BackgroundAssets? assets,
}) => showDialog<BackgroundDefinition>(
  context: context,
  builder: (context) => _BackgroundPanel(initial: initial, assets: assets),
);

class _BackgroundPanel extends StatefulWidget {
  const _BackgroundPanel({required this.initial, this.assets});
  final BackgroundDefinition initial;
  final BackgroundAssets? assets;
  @override
  State<_BackgroundPanel> createState() => _BackgroundPanelState();
}

class _BackgroundPanelState extends State<_BackgroundPanel> {
  late BackgroundDefinition pending = widget.initial;
  ui.Image? image;
  bool busy = false;
  late final firstColor = TextEditingController(
    text: _hex(pending.colors.first),
  );
  late final secondColor = TextEditingController(
    text: _hex(pending.colors[math.min(1, pending.colors.length - 1)]),
  );
  int kindSelection = 0;
  bool get gradient =>
      pending.kind == BackgroundKind.linear ||
      pending.kind == BackgroundKind.radial;
  bool get validColor => _parseColor(firstColor.text) != null;
  bool get validSecond => _parseColor(secondColor.text) != null;
  bool get validVisibleColors =>
      pending.kind == BackgroundKind.photo ||
      (validColor && (!gradient || validSecond));
  String? error;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _load(pending);
    _recover();
  }

  Future<void> _recover() async {
    try {
      final asset = await const BackgroundPicker().recover();
      if (asset == null || !mounted) return;
      final next = BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: asset.id,
      );
      setState(() {
        _selectPaper(next);
        error = null;
      });
      await _load(next);
    } on MissingPluginException {
      /* Linux widgets do not provide pickers. */
    } on PlatformException {
      /* An interrupted picker can be retried explicitly. */
    }
  }

  Future<void> _load(BackgroundDefinition paper) async {
    final token = ++generation;
    ui.Image? next;
    try {
      next = await loadBackgroundImage(
        paper,
        maxWidth: 512,
        maxHeight: 640,
        assets: widget.assets,
      );
      if (!mounted || token != generation) {
        next?.dispose();
        return;
      }
      final previous = image;
      setState(() => image = next);
      previous?.dispose();
    } catch (_) {
      next?.dispose();
      if (mounted && token == generation) {
        setState(() {
          image?.dispose();
          image = null;
        });
      }
    }
  }

  Future<void> _pick(bool camera) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final asset = await const BackgroundPicker().pick(camera: camera);
      if (!mounted || asset == null) return;
      final next = BackgroundDefinition(
        kind: BackgroundKind.photo,
        assetId: asset.id,
        opacity: pending.opacity,
      );
      setState(() => _selectPaper(next));
      await _load(next);
    } on PlatformException catch (e) {
      if (mounted) setState(() => error = e.code);
    } on MissingPluginException {
      if (mounted) setState(() => error = 'camera_unavailable');
    } catch (_) {
      if (mounted) setState(() => error = 'image_invalid');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    generation++;
    image?.dispose();
    firstColor.dispose();
    secondColor.dispose();
    super.dispose();
  }

  static String _hex(int color) =>
      (color & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase();
  static int? _parseColor(String text) =>
      RegExp(r'^[a-fA-F0-9]{6}$').hasMatch(text)
      ? int.tryParse(text, radix: 16)
      : null;

  // Type changes and presets deliberately restore fields from the last valid
  // model, so stale manual text cannot disagree with the displayed background.
  void _selectPaper(BackgroundDefinition next) {
    pending = next;
    firstColor.value = TextEditingValue(text: _hex(next.colors.first));
    secondColor.value = TextEditingValue(
      text: _hex(next.colors[math.min(1, next.colors.length - 1)]),
    );
    kindSelection++;
  }

  void _color(String text, bool second) {
    final parsed = _parseColor(text);
    setState(() {
      if (parsed != null) {
        final colors = pending.colors.toList();
        if (second && colors.length == 1) colors.add(colors.first);
        colors[second ? 1 : 0] = 0xff000000 | parsed;
        pending = pending.copyWith(colors: colors);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    final colorNames = [
      (0xf7f5eb, strings.warmPaper),
      (0xeef5f1, strings.mintPaper),
      (0xf3eef9, strings.lilacPaper),
      (0xffeeee, strings.rosePaper),
    ];
    String kindName(BackgroundKind kind) => switch (kind) {
      BackgroundKind.solid => strings.solidBackground,
      BackgroundKind.linear => strings.linearBackground,
      BackgroundKind.radial => strings.radialBackground,
      BackgroundKind.photo => strings.photoBackground,
    };
    final crop = pending.crop;
    Widget cropSlider(
      String label,
      double value,
      double minimum,
      double maximum,
      ValueChanged<double> change,
    ) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        Slider(
          value: value.clamp(minimum, maximum),
          min: minimum,
          max: maximum,
          label: context.strings.percentValue(
            context.formatNumber((value * 100).round()),
          ),
          onChanged: busy ? null : change,
          semanticFormatterCallback: (n) =>
              '$label ${context.strings.percentValue(context.formatNumber((n * 100).round()))}',
        ),
      ],
    );
    return AlertDialog(
      title: Text(strings.paperColor),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<BackgroundKind>(
              initialValue: pending.kind,
              key: ValueKey(('background-kind', pending.kind, kindSelection)),
              isExpanded: true,
              decoration: InputDecoration(labelText: strings.backgroundType),
              items: [
                for (final kind in BackgroundKind.values)
                  DropdownMenuItem(
                    value: kind,
                    child: Text(kindName(kind), maxLines: 2),
                  ),
              ],
              onChanged: busy
                  ? null
                  : (kind) {
                      if (kind == null) return;
                      if (kind == BackgroundKind.photo) {
                        setState(() => kindSelection++);
                        _pick(false);
                        return;
                      }
                      setState(
                        () => _selectPaper(
                          BackgroundDefinition(
                            kind: kind,
                            colors: pending.colors.length > 1
                                ? pending.colors
                                : [pending.colors.first, 0xffd8e9f3],
                            opacity: pending.opacity,
                          ),
                        ),
                      );
                    },
            ),
            Text(
              strings.paperOpacity(
                context.formatNumber((pending.opacity * 100).round()),
              ),
            ),
            Slider(
              value: pending.opacity,
              divisions: 100,
              label: strings.percentValue(
                context.formatNumber((pending.opacity * 100).round()),
              ),
              semanticFormatterCallback: (n) => strings.paperOpacitySemantics(
                context.formatNumber((n * 100).round()),
              ),
              onChanged: busy
                  ? null
                  : (n) =>
                        setState(() => pending = pending.copyWith(opacity: n)),
            ),
            const SizedBox(height: 12),
            Semantics(
              label: strings.paperPreview,
              child: Align(
                child: SizedBox(
                  width: 240,
                  child: AspectRatio(
                    aspectRatio: 4 / 5,
                    child: RepaintBoundary(
                      key: const ValueKey('paper-preview-boundary'),
                      child: CustomPaint(
                        key: const ValueKey('paper-preview'),
                        painter: _BackgroundPreview(pending, image),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (pending.kind != BackgroundKind.photo) ...[
              Wrap(
                spacing: 8,
                children: [
                  for (final (color, name) in colorNames)
                    IconButton(
                      tooltip: name,
                      isSelected: pending.colors.first & 0xffffff == color,
                      style: IconButton.styleFrom(
                        backgroundColor: Color(0xff000000 | color),
                      ),
                      onPressed: busy
                          ? null
                          : () => setState(() {
                              _selectPaper(
                                pending.copyWith(
                                  colors: [
                                    0xff000000 | color,
                                    ...pending.colors.skip(1),
                                  ],
                                ),
                              );
                            }),
                      icon: Icon(
                        pending.colors.first & 0xffffff == color
                            ? Icons.check
                            : Icons.circle_outlined,
                      ),
                    ),
                ],
              ),
              TextFormField(
                key: const ValueKey('background-first-color'),
                enabled: !busy,
                controller: firstColor,
                maxLength: 6,
                decoration: InputDecoration(
                  labelText: strings.customColor,
                  errorText: validColor ? null : strings.customColor,
                ),
                onChanged: (text) => _color(text, false),
              ),
              if (pending.kind == BackgroundKind.linear ||
                  pending.kind == BackgroundKind.radial)
                TextFormField(
                  key: const ValueKey('background-second-color'),
                  enabled: !busy,
                  controller: secondColor,
                  maxLength: 6,
                  decoration: InputDecoration(
                    labelText: strings.secondColor,
                    errorText: validSecond ? null : strings.secondColor,
                  ),
                  onChanged: (text) => _color(text, true),
                ),
              if (pending.kind == BackgroundKind.linear ||
                  pending.kind == BackgroundKind.radial)
                Wrap(
                  spacing: 8,
                  children: [
                    for (final (colors, name) in [
                      ([0xfff5d8b0, 0xffa4c9ce], strings.gradientDawn),
                      ([0xffcbb7ed, 0xfff4d7cb], strings.gradientTwilight),
                      ([0xffa7d8bb, 0xffefe3ae], strings.gradientOrchard),
                    ])
                      IconButton(
                        tooltip: name,
                        isSelected:
                            pending.colors.length == colors.length &&
                            colors.asMap().entries.every(
                              (entry) =>
                                  pending.colors[entry.key] == entry.value,
                            ),
                        onPressed: busy
                            ? null
                            : () => setState(
                                () => _selectPaper(
                                  pending.copyWith(colors: colors),
                                ),
                              ),
                        icon: Icon(
                          pending.colors.length == colors.length &&
                                  colors.asMap().entries.every(
                                    (entry) =>
                                        pending.colors[entry.key] ==
                                        entry.value,
                                  )
                              ? Icons.check
                              : Icons.gradient,
                        ),
                      ),
                  ],
                ),
            ],
            if (pending.kind == BackgroundKind.photo) ...[
              if (image == null) Text(strings.imageUnavailable),
              Wrap(
                children: [
                  IconButton(
                    tooltip: strings.rotatePhoto,
                    onPressed: busy
                        ? null
                        : () => setState(
                            () => pending = pending.copyWith(
                              quarterTurns: (pending.quarterTurns + 1) % 4,
                            ),
                          ),
                    icon: const Icon(Icons.rotate_right),
                  ),
                  IconButton(
                    tooltip: strings.mirrorPhoto,
                    isSelected: pending.mirror,
                    onPressed: busy
                        ? null
                        : () => setState(
                            () => pending = pending.copyWith(
                              mirror: !pending.mirror,
                            ),
                          ),
                    icon: const Icon(Icons.flip),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(
                            () => pending = pending.copyWith(
                              crop: const CropWindow(),
                              quarterTurns: 0,
                              mirror: false,
                            ),
                          ),
                    child: Text(strings.resetCrop),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => setState(
                            () => _selectPaper(
                              BackgroundDefinition.solid(0xfff7f5eb),
                            ),
                          ),
                    child: Text(strings.removePhoto),
                  ),
                ],
              ),
              cropSlider(
                strings.cropLeft,
                crop.left,
                0,
                .95,
                (n) => setState(
                  () => pending = pending.copyWith(
                    crop: CropWindow(
                      left: n,
                      top: crop.top,
                      width: math.min(crop.width, 1 - n),
                      height: crop.height,
                    ),
                  ),
                ),
              ),
              cropSlider(
                strings.cropTop,
                crop.top,
                0,
                .95,
                (n) => setState(
                  () => pending = pending.copyWith(
                    crop: CropWindow(
                      left: crop.left,
                      top: n,
                      width: crop.width,
                      height: math.min(crop.height, 1 - n),
                    ),
                  ),
                ),
              ),
              cropSlider(
                strings.cropWidth,
                crop.width,
                .05,
                1 - crop.left,
                (n) => setState(
                  () => pending = pending.copyWith(
                    crop: CropWindow(
                      left: crop.left,
                      top: crop.top,
                      width: n,
                      height: crop.height,
                    ),
                  ),
                ),
              ),
              cropSlider(
                strings.cropHeight,
                crop.height,
                .05,
                1 - crop.top,
                (n) => setState(
                  () => pending = pending.copyWith(
                    crop: CropWindow(
                      left: crop.left,
                      top: crop.top,
                      width: crop.width,
                      height: n,
                    ),
                  ),
                ),
              ),
            ],
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(false),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(
                    pending.kind == BackgroundKind.photo
                        ? strings.replacePhoto
                        : strings.choosePhoto,
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _pick(true),
                  icon: const Icon(Icons.camera_alt_outlined),
                  label: Text(strings.takePhoto),
                ),
              ],
            ),
            if (busy) ...[
              const LinearProgressIndicator(),
              Text(strings.backgroundImportBusy),
            ],
            if (error != null)
              Text(switch (error) {
                'camera_unavailable' => strings.cameraUnavailable,
                'permission_denied' => strings.photoPermissionDenied,
                _ => strings.imageImportFailed,
              }),
            Text(strings.backgroundGradientTip),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed:
              busy ||
                  !validVisibleColors ||
                  pending.kind == BackgroundKind.photo && image == null
              ? null
              : () => Navigator.pop(context, pending),
          child: Text(strings.apply),
        ),
      ],
    );
  }
}

class _BackgroundPreview extends CustomPainter {
  _BackgroundPreview(this.paper, this.image);
  final BackgroundDefinition paper;
  final ui.Image? image;
  @override
  void paint(Canvas canvas, Size size) =>
      paintBackground(canvas, Offset.zero & size, paper, image: image);
  @override
  bool shouldRepaint(_BackgroundPreview oldDelegate) =>
      oldDelegate.paper != paper || oldDelegate.image != image;
}
