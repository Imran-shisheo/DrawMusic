import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../../l10n/strings.dart';
import '../../../design_system/creative_panel.dart';
import '../../../design_system/motion.dart';
import '../../../design_system/brand_colors.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/immersive_surface.dart';
import 'photo_crop_workspace.dart';
import '../domain/background.dart';
import '../data/background_assets.dart';
import 'background_painter.dart';

/// Expanded background transaction. Imported assets are immutable; Cancel never
/// changes the document and never deletes a file another revision may reference.
Future<BackgroundDefinition?> showBackgroundPanel(
  BuildContext context,
  BackgroundDefinition initial, {
  BackgroundAssets? assets,
}) => showCreativePanel<BackgroundDefinition>(
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
  final previewTarget = GlobalKey();
  double? previewWidthLimit;
  Object? previewLayout;
  bool busy = false;
  late final firstColor = TextEditingController(
    text: _hex(pending.colors.first),
  );
  late final secondColor = TextEditingController(
    text: _hex(pending.colors[math.min(1, pending.colors.length - 1)]),
  );
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
      if (next != null) _schedulePreview(token);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final layout = (
      MediaQuery.sizeOf(context),
      MediaQuery.textScalerOf(context).scale(1),
      MediaQuery.viewInsetsOf(context).bottom,
      Localizations.localeOf(context),
    );
    if (layout != previewLayout) {
      previewWidthLimit = null;
      previewLayout = layout;
    }
    if (image != null) _schedulePreview(generation);
  }

  void _schedulePreview(int token) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || token != generation) return;
      final compact =
          MediaQuery.sizeOf(context).height < 500 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.5;
      final target = previewTarget.currentContext;
      if (!compact || target == null) return;
      final viewport = Scrollable.maybeOf(target)?.position.viewportDimension;
      final frame = target.size;
      if (viewport != null && frame != null) {
        final limit = math.max(48.0, math.max(60.0, viewport - 12) * .8);
        if (frame.width > limit + .1) {
          setState(() => previewWidthLimit = limit);
          _schedulePreview(token);
          return;
        }
      }
      unawaited(
        Scrollable.ensureVisible(
          target,
          alignment: .2,
          duration: CreativeMotion.duration(context, CreativeMotion.selection),
          curve: CreativeMotion.curve,
        ),
      );
    });
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

  void _changeKind(BackgroundKind kind) {
    if (busy) return;
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
  }

  Future<void> _photoSource() async {
    final camera = await showCreativePanel<bool>(
      context: context,
      builder: (sheetContext) => CreativePanel(
        title: sheetContext.strings.photoBackground,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(sheetContext),
            child: Text(sheetContext.strings.cancel),
          ),
        ],
        child: Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(sheetContext, false),
                icon: const DoodimoIcon(DoodimoGlyph.image),
                label: Text(sheetContext.strings.choosePhoto),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const DoodimoIcon(DoodimoGlyph.camera),
                label: Text(sheetContext.strings.takePhoto),
              ),
            ],
          ),
        ),
      ),
    );
    if (camera != null && mounted) await _pick(camera);
  }

  Widget _preview(double width) {
    Widget picture = RepaintBoundary(
      key: const ValueKey('paper-preview-boundary'),
      child: CustomPaint(
        key: const ValueKey('paper-preview'),
        painter: _BackgroundPreview(pending, image),
        child: const SizedBox.expand(),
      ),
    );
    if (pending.kind == BackgroundKind.photo && image != null) {
      picture = IgnorePointer(
        ignoring: busy,
        child: ExcludeFocus(
          excluding: busy,
          child: PhotoCropWorkspace(
            key: const ValueKey('background-crop-workspace'),
            paper: pending,
            image: image!,
            onChanged: (crop) =>
                setState(() => pending = pending.copyWith(crop: crop)),
            child: picture,
          ),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: context.strings.paperPreview,
          child: SizedBox(
            key: previewTarget,
            width: width,
            child: AspectRatio(
              aspectRatio: 4 / 5,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: DoodimoColors.violet.withValues(
                        alpha: Theme.of(context).brightness == Brightness.dark
                            ? .24
                            : .12,
                      ),
                      blurRadius: 28,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: scheme.secondary.withValues(alpha: .65),
                    width: 1.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: picture,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          pending.kind == BackgroundKind.photo
              ? MediaQuery.textScalerOf(context).scale(1) > 1.5
                    ? context.strings.cropWorkspace
                    : context.strings.cropMoveHint
              : context.strings.paperPreview,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _presets() {
    final strings = context.strings;
    final palettes = gradient
        ? [
            ([0xfff5d8b0, 0xffa4c9ce], strings.gradientDawn),
            ([0xffcbb7ed, 0xfff4d7cb], strings.gradientTwilight),
            ([0xffa7d8bb, 0xffefe3ae], strings.gradientOrchard),
          ]
        : [
            ([0xfff7f5eb], strings.warmPaper),
            ([0xffeef5f1], strings.mintPaper),
            ([0xfff3eef9], strings.lilacPaper),
            ([0xffffeeee], strings.rosePaper),
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.backgroundPresets,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns =
                constraints.maxWidth > 440 &&
                    MediaQuery.textScalerOf(context).scale(1) < 1.5
                ? 4
                : 2;
            final width = (constraints.maxWidth - 10 * (columns - 1)) / columns;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final (colors, name) in palettes)
                  SizedBox(
                    width: width,
                    child: _PaperPaletteTile(
                      name: name,
                      colors: colors,
                      selected: gradient
                          ? listEquals(pending.colors, colors)
                          : pending.colors.first == colors.first,
                      onTap: busy
                          ? null
                          : () => setState(
                              () => _selectPaper(
                                pending.copyWith(
                                  colors: gradient
                                      ? colors
                                      : [
                                          colors.first,
                                          ...pending.colors.skip(1),
                                        ],
                                ),
                              ),
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _colorControls() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (gradient) ...[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _BackgroundChoice(
                key: const ValueKey('background-gradient-linear'),
                label: context.strings.linearBackground,
                glyph: DoodimoGlyph.sun,
                selected: pending.kind == BackgroundKind.linear,
                compact: true,
                onTap: busy ? null : () => _changeKind(BackgroundKind.linear),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _BackgroundChoice(
                key: const ValueKey('background-gradient-radial'),
                label: context.strings.radialBackground,
                glyph: DoodimoGlyph.sun,
                selected: pending.kind == BackgroundKind.radial,
                compact: true,
                onTap: busy ? null : () => _changeKind(BackgroundKind.radial),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
      ],
      _presets(),
      const SizedBox(height: 24),
      Text(
        context.strings.backgroundCustomColors,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      const SizedBox(height: 12),
      TextFormField(
        key: const ValueKey('background-first-color'),
        enabled: !busy,
        controller: firstColor,
        maxLength: 6,
        textCapitalization: TextCapitalization.characters,
        textDirection: TextDirection.ltr,
        autocorrect: false,
        enableSuggestions: false,
        decoration: InputDecoration(
          labelText: context.strings.customColor,
          prefixText: '# ',
          counterText: '',
          errorText: validColor ? null : context.strings.customColor,
        ),
        onChanged: (text) => _color(text, false),
      ),
      if (gradient) ...[
        const SizedBox(height: 12),
        TextFormField(
          key: const ValueKey('background-second-color'),
          enabled: !busy,
          controller: secondColor,
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          textDirection: TextDirection.ltr,
          autocorrect: false,
          enableSuggestions: false,
          decoration: InputDecoration(
            labelText: context.strings.secondColor,
            prefixText: '# ',
            counterText: '',
            errorText: validSecond ? null : context.strings.secondColor,
          ),
          onChanged: (text) => _color(text, true),
        ),
      ],
    ],
  );

  Widget _cropSlider(
    String label,
    double value,
    double minimum,
    double maximum,
    ValueChanged<double> change,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.labelLarge),
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

  Widget _photoControls() {
    final strings = context.strings, crop = pending.crop;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (image == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(strings.imageUnavailable),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconButton.filledTonal(
              tooltip: strings.rotatePhoto,
              onPressed: busy
                  ? null
                  : () => setState(
                      () => pending = pending.copyWith(
                        quarterTurns: (pending.quarterTurns + 1) % 4,
                      ),
                    ),
              icon: const DoodimoIcon(DoodimoGlyph.rotate),
            ),
            IconButton.filledTonal(
              tooltip: strings.mirrorPhoto,
              isSelected: pending.mirror,
              onPressed: busy
                  ? null
                  : () => setState(
                      () => pending = pending.copyWith(mirror: !pending.mirror),
                    ),
              icon: const DoodimoIcon(DoodimoGlyph.mirror),
            ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => setState(
                      () => pending = pending.copyWith(
                        crop: const CropWindow(),
                        quarterTurns: 0,
                        mirror: false,
                      ),
                    ),
              icon: const DoodimoIcon(DoodimoGlyph.replay),
              label: Text(strings.resetCrop),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _cropSlider(
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
        _cropSlider(
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
        _cropSlider(
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
        _cropSlider(
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: busy ? null : () => _pick(false),
              icon: const DoodimoIcon(DoodimoGlyph.image),
              label: Text(strings.replacePhoto),
            ),
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () => setState(
                      () =>
                          _selectPaper(BackgroundDefinition.solid(0xfff7f5eb)),
                    ),
              icon: const DoodimoIcon(DoodimoGlyph.erase),
              label: Text(strings.removePhoto),
            ),
          ],
        ),
      ],
    );
  }

  Widget _opacity() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.strings.paperOpacity(
          context.formatNumber((pending.opacity * 100).round()),
        ),
        style: Theme.of(context).textTheme.labelLarge,
      ),
      Slider(
        value: pending.opacity,
        divisions: 100,
        label: context.strings.percentValue(
          context.formatNumber((pending.opacity * 100).round()),
        ),
        semanticFormatterCallback: (n) => context.strings.paperOpacitySemantics(
          context.formatNumber((n * 100).round()),
        ),
        onChanged: busy
            ? null
            : (n) => setState(() => pending = pending.copyWith(opacity: n)),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final strings = context.strings;
    return CreativePanel(
      title: strings.backgroundPanelTitle,
      actions: [
        TextButton(
          onPressed: busy ? null : () => Navigator.pop(context),
          child: Text(strings.cancel),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors:
                  busy ||
                      !validVisibleColors ||
                      pending.kind == BackgroundKind.photo && image == null
                  ? [
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                      Theme.of(context).colorScheme.surfaceContainerHigh,
                    ]
                  : const [Color(0xffbda4ff), Color(0xff86e8f7)],
            ),
            boxShadow: [
              BoxShadow(
                color: DoodimoColors.violet.withValues(alpha: .18),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: DoodimoColors.ink,
              shadowColor: Colors.transparent,
            ),
            onPressed:
                busy ||
                    !validVisibleColors ||
                    pending.kind == BackgroundKind.photo && image == null
                ? null
                : () => Navigator.pop(context, pending),
            child: Text(strings.apply),
          ),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.5,
              wide = constraints.maxWidth >= 520 && !largeText;
          final preferredWidth = MediaQuery.sizeOf(context).height < 500
              ? 160.0
              : wide
              ? 196.0
              : 220.0;
          final previewWidth = math.min(
            preferredWidth,
            previewWidthLimit ?? preferredWidth,
          );
          final controls = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (pending.kind == BackgroundKind.photo)
                _photoControls()
              else
                _colorControls(),
              const SizedBox(height: 20),
              _opacity(),
              if (busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 8),
                Text(strings.backgroundImportBusy),
              ],
              if (error != null)
                Text(
                  switch (error) {
                    'camera_unavailable' => strings.cameraUnavailable,
                    'permission_denied' => strings.photoPermissionDenied,
                    _ => strings.imageImportFailed,
                  },
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 12),
              Text(
                strings.backgroundGradientTip,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 24),
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LayoutBuilder(
                builder: (context, choiceConstraints) {
                  final scheme = Theme.of(context).colorScheme;
                  final columns = largeText && choiceConstraints.maxWidth < 400
                          ? 2
                          : 3,
                      width =
                          (choiceConstraints.maxWidth - 8 * (columns - 1)) /
                          columns;
                  return ImmersiveSurface(
                    padding: EdgeInsets.zero,
                    radius: 22,
                    accent: scheme.secondary,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SizedBox(
                          width: width,
                          child: _BackgroundChoice(
                            key: const ValueKey('background-mode-color'),
                            label: strings.backgroundColorTab,
                            glyph: DoodimoGlyph.paper,
                            selected: pending.kind == BackgroundKind.solid,
                            onTap: busy
                                ? null
                                : () => _changeKind(BackgroundKind.solid),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _BackgroundChoice(
                            key: const ValueKey('background-mode-gradient'),
                            label: strings.backgroundGradientTab,
                            glyph: DoodimoGlyph.sun,
                            selected: gradient,
                            onTap: busy
                                ? null
                                : () => _changeKind(
                                    gradient
                                        ? pending.kind
                                        : BackgroundKind.linear,
                                  ),
                          ),
                        ),
                        SizedBox(
                          width: width,
                          child: _BackgroundChoice(
                            key: const ValueKey('background-mode-photo'),
                            label: strings.photoBackground,
                            glyph: DoodimoGlyph.image,
                            selected: pending.kind == BackgroundKind.photo,
                            onTap: busy ? null : _photoSource,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: previewWidth,
                      child: _preview(previewWidth),
                    ),
                    const SizedBox(width: 24),
                    Expanded(child: controls),
                  ],
                )
              else ...[
                Align(
                  child: SizedBox(
                    width: previewWidth,
                    child: _preview(previewWidth),
                  ),
                ),
                const SizedBox(height: 24),
                controls,
              ],
            ],
          );
        },
      ),
    );
  }
}

class _BackgroundChoice extends StatelessWidget {
  const _BackgroundChoice({
    super.key,
    required this.label,
    required this.glyph,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });
  final String label;
  final DoodimoGlyph glyph;
  final bool selected, compact;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: onTap != null,
      selected: selected,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: CreativeMotion.duration(
                context,
                CreativeMotion.selection,
              ),
              curve: CreativeMotion.curve,
              constraints: BoxConstraints(minHeight: compact ? 76 : 96),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.primaryContainer,
                          scheme.secondaryContainer,
                        ],
                      )
                    : null,
                color: selected ? null : Colors.transparent,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: selected ? scheme.secondary : Colors.transparent,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      DoodimoIcon(
                        glyph,
                        size: compact ? 24 : 32,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurfaceVariant,
                      ),
                      const Spacer(),
                      if (selected)
                        DoodimoIcon(
                          DoodimoGlyph.check,
                          size: 18,
                          color: scheme.primary,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      label,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaperPaletteTile extends StatelessWidget {
  const _PaperPaletteTile({
    required this.name,
    required this.colors,
    required this.selected,
    required this.onTap,
  });
  final String name;
  final List<int> colors;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: name,
      child: Semantics(
        label: name,
        button: true,
        selected: selected,
        onTap: onTap,
        child: ExcludeSemantics(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            child: AnimatedContainer(
              duration: CreativeMotion.duration(
                context,
                CreativeMotion.selection,
              ),
              curve: CreativeMotion.curve,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.surfaceContainerHigh,
                    scheme.surfaceContainerLow,
                  ],
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: DoodimoColors.violet.withValues(alpha: .18),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : const [],
                border: Border.all(
                  color: selected ? scheme.secondary : scheme.outlineVariant,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 48,
                    alignment: AlignmentDirectional.topEnd,
                    decoration: BoxDecoration(
                      color: Color(colors.first),
                      gradient: colors.length > 1
                          ? LinearGradient(
                              colors: [
                                for (final color in colors) Color(color),
                              ],
                            )
                          : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.all(6),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                shape: BoxShape.circle,
                              ),
                              child: DoodimoIcon(
                                DoodimoGlyph.check,
                                size: 22,
                                color: scheme.primary,
                              ),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(name, style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ),
        ),
      ),
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
