import '../../rating/application/rating_provider.dart';
import '../../../design_system/creative_panel.dart';
import '../../../design_system/motion.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../../editor/presentation/canvas.dart';
import 'export_format_art.dart';

import 'package:scribblesong/l10n/strings.dart';

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../export_library/data/export_actions.dart';

import '../../../creative_document/document.dart';
import '../data/file_export_adapter.dart';
import '../data/file_image_export_adapter.dart';
import '../data/android_video_export_adapter.dart';
import '../data/ios_video_export_adapter.dart';
import '../domain/export_port.dart';
import '../../composition/domain/score.dart';

Future<void> showExportSheet(BuildContext context, ProjectDocument snapshot) =>
    showCreativePanel<void>(
      context: context,
      // Explicit Close/Back owns cancellation; a sheet drag must not bypass the
      // atomic library-finalization guard while the dismissal animation runs.
      isDismissible: false,
      builder: (_) => ExportSheet(snapshot: snapshot),
    );

class ExportSheet extends ConsumerStatefulWidget {
  const ExportSheet({super.key, required this.snapshot});
  final ProjectDocument snapshot;
  @override
  ConsumerState<ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends ConsumerState<ExportSheet>
    with WidgetsBindingObserver {
  ExportCancellation? _cancellation;
  ExportArtifact? _artifact;
  bool _busy = false;
  bool _finalizing = false;
  bool _fileActionBusy = false;
  double? _progress;
  int _width = 1080;
  int _fps = 30;
  int _imageWidth = 1080;
  bool _transparentBackground = false;
  ExportFormat? _format;
  ExportFormat _selectedFormat = ExportFormat.png;
  bool _failed = false;
  bool _confirmingEmpty = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        _busy &&
        !_finalizing &&
        _format == ExportFormat.mp4) {
      _cancellation?.cancelled = true;
    }
  }

  String? _message;
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!_finalizing) _cancellation?.cancelled = true;
    super.dispose();
  }

  bool get _hasMusic =>
      widget.snapshot.strokes.isNotEmpty || widget.snapshot.mix.isActive;
  Future<void> _export(ExportFormat format) async {
    if (format != ExportFormat.png && !_hasMusic) return;
    if (_busy || _fileActionBusy || _confirmingEmpty) return;
    if (format == ExportFormat.png && widget.snapshot.strokes.isEmpty) {
      _confirmingEmpty = true;
      bool? confirmed;
      try {
        confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            scrollable: true,
            title: Text(context.strings.pngEmptyTitle),
            content: Text(context.strings.pngEmptyDescription),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.strings.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.strings.exportPng),
              ),
            ],
          ),
        );
      } finally {
        _confirmingEmpty = false;
      }
      if (!mounted || confirmed != true || _busy || _fileActionBusy) return;
    }
    final cancellation = ExportCancellation();
    _cancellation = cancellation;
    setState(() {
      _busy = true;
      _message = null;
      _artifact = null;
      _progress = null;
      _format = format;
      _failed = false;
    });
    try {
      final root = await getApplicationDocumentsDirectory();
      final directory = Directory('${root.path}/exports');
      void progress(double progress) {
        if (mounted && !cancellation.cancelled) {
          setState(() => _progress = progress);
        }
      }

      final artifact = format == ExportFormat.png
          ? await FileImageExportAdapter(directory).exportImage(
              widget.snapshot,
              cancellation,
              width: _imageWidth,
              transparentBackground: _transparentBackground,
              onProgress: progress,
            )
          : format == ExportFormat.mp4
          ? await (Platform.isIOS
                    ? IosVideoExportAdapter(directory)
                    : AndroidVideoExportAdapter(directory))
                .exportVideo(
                  widget.snapshot,
                  cancellation,
                  width: _width,
                  fps: _fps,
                  onProgress: progress,
                )
          : await FileExportAdapter(directory)
                .export(widget.snapshot, format, cancellation);
      if (mounted) setState(() => _finalizing = true);
      var detailsSaved = true;
      try {
        await (await ref.read(exportLibraryProvider.future))
            .record(artifact, widget.snapshot);
      } catch (_) {
        detailsSaved = false;
      }
      if (mounted && !cancellation.cancelled) {
        try {
          await (await ref.read(ratingCoordinatorProvider.future))
              .recordSuccessfulTask();
        } catch (_) {
          /* Optional review counters never affect artifact success. */
        }
      }
      if (mounted) ref.invalidate(exportListingProvider);
      if (mounted && !cancellation.cancelled) {
        setState(() {
          _artifact = artifact;
          _message = detailsSaved
              ? context.strings.exportReady
              : context.strings.exportDetailsSaveFailed;
        });
      }
    } on ExportCancelled {
      if (mounted) {
        setState(() {
          _message = context.strings.exportCancelled;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _failed = true;
          _message = error is ScoreComplexityException
              ? context.strings.scoreTooComplex
              : format == ExportFormat.mp4
              ? context.strings.videoExportFailed
              : context.strings.exportFailed;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _finalizing = false;
        });
      }
    }
  }

  Future<void> _share() async {
    final artifact = _artifact;
    if (artifact == null || _fileActionBusy) return;
    setState(() => _fileActionBusy = true);
    try {
      final box = context.findRenderObject() as RenderBox?;
      final result = await ref.read(shareExportProvider)(
        artifact,
        box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
      if (mounted) {
        setState(
          () => _message = switch (result) {
            ShareResultStatus.dismissed => context.strings.shareDismissed,
            ShareResultStatus.unavailable => context.strings.shareUnavailable,
            ShareResultStatus.success => context.strings.shareClosed,
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = context.strings.shareUnavailable);
      }
    } finally {
      if (mounted) setState(() => _fileActionBusy = false);
    }
  }

  Future<void> _savePublic() async {
    final artifact = _artifact;
    if (artifact == null || _fileActionBusy) return;
    setState(() => _fileActionBusy = true);
    try {
      final result = await ref.read(exportFileActionsProvider).save(artifact);
      if (mounted) {
        setState(
          () => _message = result == null
              ? context.strings.publicSaveCancelled
              : context.strings.savedPublicCopy(result.destination),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = context.strings.publicSaveFailed);
      }
    } finally {
      if (mounted) setState(() => _fileActionBusy = false);
    }
  }

  Future<void> _open() async {
    final artifact = _artifact;
    if (artifact == null || _fileActionBusy) return;
    setState(() => _fileActionBusy = true);
    try {
      await ref.read(exportFileActionsProvider).open(artifact);
    } catch (_) {
      if (mounted) setState(() => _message = context.strings.exportOpenFailed);
    } finally {
      if (mounted) setState(() => _fileActionBusy = false);
    }
  }

  void _close() {
    if (_finalizing) return;
    if (_busy) _cancellation?.cancelled = true;
    Navigator.of(context).pop();
  }

  void _choose(ExportFormat format) {
    if (_busy || _fileActionBusy) return;
    setState(() {
      _selectedFormat = format;
      _artifact = null;
      _message = null;
      _failed = false;
    });
  }

  String _label(ExportFormat format) => switch (format) {
    ExportFormat.png => context.strings.exportIntentImage,
    ExportFormat.wav => context.strings.exportIntentSound,
    ExportFormat.mp4 => context.strings.exportIntentVideo,
    ExportFormat.midi => context.strings.exportIntentNotes,
  };
  String _description(ExportFormat format) => switch (format) {
    ExportFormat.png => context.strings.exportIntentImageDescription,
    ExportFormat.wav => context.strings.exportIntentSoundDescription,
    ExportFormat.mp4 => context.strings.exportIntentVideoDescription,
    ExportFormat.midi => context.strings.exportIntentNotesDescription,
  };
  String _actionLabel() => _failed
      ? context.strings.exportTryAgain
      : switch (_selectedFormat) {
          ExportFormat.png => context.strings.exportPng,
          ExportFormat.wav => context.strings.exportWav,
          ExportFormat.mp4 => context.strings.exportMp4,
          ExportFormat.midi => context.strings.exportMidi,
        };
  String _extension(ExportFormat format) => switch (format) {
    ExportFormat.png => 'PNG',
    ExportFormat.wav => 'WAV',
    ExportFormat.mp4 => 'MP4',
    ExportFormat.midi => 'MIDI',
  };
  Color _formatTint(ExportFormat format) => switch (format) {
    ExportFormat.png => const Color(0xffdceaab),
    ExportFormat.wav => const Color(0xffd8d0ed),
    ExportFormat.mp4 => const Color(0xffefc3b0),
    ExportFormat.midi => const Color(0xffdfd9ba),
  };
  Widget _medallion(
    ExportFormat format, {
    double size = 56,
    bool selected = false,
    bool illustrated = false,
  }) {
    final colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: CreativeMotion.duration(context, CreativeMotion.selection),
      curve: CreativeMotion.curve,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: selected ? colors.primary : _formatTint(format),
        borderRadius: BorderRadius.circular(size * .34),
      ),
      child: Center(
        child: illustrated
            ? ExportFormatArt(
                format: format,
                size: size * .68,
                ink: selected ? colors.onPrimary : const Color(0xff243c32),
                accent: selected
                    ? _formatTint(format)
                    : Colors.white.withValues(alpha: .62),
              )
            : DoodimoIcon(
                switch (format) {
                  ExportFormat.png => DoodimoGlyph.image,
                  ExportFormat.wav => DoodimoGlyph.sound,
                  ExportFormat.mp4 => DoodimoGlyph.video,
                  ExportFormat.midi => DoodimoGlyph.notes,
                },
                size: size * .5,
                color: selected ? colors.onPrimary : const Color(0xff243c32),
              ),
      ),
    );
  }

  Widget _intent(ExportFormat format, double width) {
    final selected = _selectedFormat == format;
    final colors = Theme.of(context).colorScheme;
    final short = MediaQuery.sizeOf(context).height < 480;
    final disc = Stack(
      clipBehavior: Clip.none,
      children: [
        _medallion(format, size: short ? 32 : 56, selected: selected),
        if (selected)
          PositionedDirectional(
            end: -4,
            bottom: -4,
            child: Container(
              width: short ? 18 : 22,
              height: short ? 18 : 22,
              decoration: BoxDecoration(
                color: colors.onSurface,
                shape: BoxShape.circle,
                border: Border.all(color: colors.surface, width: 2),
              ),
              child: DoodimoIcon(
                DoodimoGlyph.check,
                size: short ? 11 : 13,
                color: colors.surface,
              ),
            ),
          ),
      ],
    );
    final label = Text(
      _label(format),
      textAlign: short ? TextAlign.start : TextAlign.center,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
        fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        color: colors.onSurface,
      ),
    );
    return SizedBox(
      width: width,
      child: Semantics(
        selected: selected,
        button: true,
        label: _description(format),
        child: Tooltip(
          message: _description(format),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('export-intent-${format.name}'),
              borderRadius: BorderRadius.circular(20),
              onTap: () => _choose(format),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  vertical: short ? 4 : 8,
                  horizontal: 4,
                ),
                child: short
                    ? ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 48),
                        child: Row(
                          children: [
                            disc,
                            const SizedBox(width: 8),
                            Expanded(child: label),
                          ],
                        ),
                      )
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          disc,
                          const SizedBox(height: 10),
                          label,
                          const SizedBox(height: 3),
                          Text(
                            _extension(format),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: colors.onSurfaceVariant,
                                  letterSpacing: 1,
                                ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _detail() {
    final colors = Theme.of(context).colorScheme;
    final preview =
        MediaQuery.textScalerOf(context).scale(14) <= 21 &&
        MediaQuery.sizeOf(context).height >= 480;
    return Container(
      key: ValueKey('export-settings-${_selectedFormat.name}'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _formatTint(_selectedFormat),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: Text(
                          _extension(_selectedFormat),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: const Color(0xff243c32),
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _label(_selectedFormat),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -.6,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _description(_selectedFormat),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                if (preview) ...[
                  const SizedBox(width: 20),
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 76,
                      height: 95,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: BackgroundSurface(
                          paper: widget.snapshot.effectiveBackground,
                          maxWidth: 112,
                          maxHeight: 140,
                          child: CustomPaint(
                            painter: DrawingPainter(widget.snapshot),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),
            _settings(),
          ],
        ),
      ),
    );
  }

  Widget _choices(
    String group,
    String prefix,
    int selected,
    List<(int, String)> values,
    ValueChanged<int> changed,
  ) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      key: ValueKey(group),
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (value, label) in values)
          Semantics(
            key: ValueKey('$prefix-$value'),
            selected: value == selected,
            button: true,
            child: TextButton(
              onPressed: () => changed(value),
              style: TextButton.styleFrom(
                backgroundColor: value == selected
                    ? colors.primary
                    : colors.surface,
                foregroundColor: value == selected
                    ? colors.onPrimary
                    : colors.onSurface,
                minimumSize: const Size(48, 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: const StadiumBorder(),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (value == selected) ...[
                    const DoodimoIcon(DoodimoGlyph.check, size: 16),
                    const SizedBox(width: 7),
                  ],
                  Flexible(child: Text(label, textAlign: TextAlign.center)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _settings() {
    final duration = 480 / widget.snapshot.tempo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_selectedFormat == ExportFormat.png) ...[
          Semantics(
            label: context.strings.pngOutputSize,
            child: _choices('png-output-width', 'png-width', _imageWidth, [
              (1080, context.strings.pngHd),
              (640, context.strings.pngCompact),
            ], (value) => setState(() => _imageWidth = value)),
          ),
          const SizedBox(height: 14),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text(context.strings.transparentBackground),
            value: _transparentBackground,
            onChanged: (value) =>
                setState(() => _transparentBackground = value),
          ),
        ],
        if (_selectedFormat == ExportFormat.wav)
          Text(
            context.strings.wavExportSummary(
              context.formatNumber(((duration + 1.25) * 88.2).round()),
            ),
          ),
        if (_selectedFormat == ExportFormat.midi)
          Text(
            context
                .strings
                .midiContainsNotesAndInstrumentInstructionsItMaySoundDiffer,
          ),
        if (_selectedFormat == ExportFormat.mp4) ...[
          _choices('video-output-width', 'video-width', _width, [
            (1080, context.strings.hd1080135030Fps),
            (640, context.strings.compact64080030Fps),
          ], (value) => setState(() => _width = value)),
          const SizedBox(height: 12),
          Semantics(
            label: context.strings.videoFrameRate,
            child: _choices('video-output-fps', 'video-fps', _fps, [
              (30, context.strings.exportFpsChoice(context.formatNumber(30))),
              (60, context.strings.exportFpsChoice(context.formatNumber(60))),
            ], (value) => setState(() => _fps = value)),
          ),
          if (_fps == 60) ...[
            const SizedBox(height: 10),
            Text(
              context.strings.videoFps60,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 12),
          Text(
            context
                .strings
                .mp4AnimatesThisDrawingWithItsMusicVideoExportCancelsIfYouL,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
        if (_selectedFormat != ExportFormat.png) ...[
          const SizedBox(height: 12),
          Text(
            context.strings.oneLoopExportSummary(
              context.formatDecimal(duration),
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!_hasMusic)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(context.strings.drawSomethingToHearIt),
            ),
        ],
      ],
    );
  }

  Widget _selection() => Column(
    key: const ValueKey('export-selection'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.strings.exportChooseFormat,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          final columns = largeText && constraints.maxWidth < 440 ? 2 : 4;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final format in [
                ExportFormat.png,
                ExportFormat.wav,
                ExportFormat.mp4,
                ExportFormat.midi,
              ])
                _intent(format, width),
            ],
          );
        },
      ),
      const SizedBox(height: 20),
      if (MediaQuery.disableAnimationsOf(context))
        _detail()
      else
        AnimatedSize(
          duration: CreativeMotion.selection,
          curve: CreativeMotion.curve,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: CreativeMotion.selection,
            layoutBuilder: (current, previous) => current ?? const SizedBox(),
            child: _detail(),
          ),
        ),
      if (_message != null)
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Semantics(
            liveRegion: true,
            child: Text(
              _message!,
              style: TextStyle(
                color: _failed ? Theme.of(context).colorScheme.error : null,
              ),
            ),
          ),
        ),
    ],
  );

  Widget _working() => Padding(
    key: ValueKey(_finalizing ? 'export-finalizing' : 'export-working'),
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(
      children: [
        _medallion(_format!, size: 80, selected: true, illustrated: true),
        const SizedBox(height: 24),
        Text(
          _finalizing
              ? context.strings.exportFinalizing
              : context.strings.exportPreparing,
          style: Theme.of(context).textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          widget.snapshot.title,
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _finalizing ? null : _progress,
            minHeight: 7,
          ),
        ),
        const SizedBox(height: 12),
        if (!_finalizing && _progress != null)
          Text(
            context.strings.percentValue(
              context.formatNumber((_progress! * 100).round()),
            ),
            style: Theme.of(context).textTheme.labelLarge,
          ),
      ],
    ),
  );
  Widget _ready() {
    final artifact = _artifact!;
    final colors = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('export-ready'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipPath(
          clipper: const ExportTicketClipper(),
          child: ColoredBox(
            color: colors.surfaceContainerLow,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      _medallion(
                        _format!,
                        size: 76,
                        selected: true,
                        illustrated: true,
                      ),
                      PositionedDirectional(
                        end: -5,
                        bottom: -5,
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xffdceaab),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: colors.surfaceContainerLow,
                              width: 3,
                            ),
                          ),
                          child: const DoodimoIcon(
                            DoodimoGlyph.check,
                            size: 18,
                            color: Color(0xff243c32),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text(
                    context.strings.exportReadyTitle,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    artifact.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  ExportTicketRule(color: colors.outlineVariant),
                  const SizedBox(height: 18),
                  if (artifact.width != null && artifact.height != null)
                    Text(
                      '${context.formatNumber(artifact.width!)} × ${context.formatNumber(artifact.height!)}',
                      style: Theme.of(context).textTheme.labelLarge,
                      textAlign: TextAlign.center,
                    ),
                  if (_message != null) ...[
                    const SizedBox(height: 10),
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        _message!,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: _fileActionBusy ? null : _share,
          icon: const DoodimoIcon(DoodimoGlyph.export),
          label: Text(context.strings.shareExportedFile),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _fileActionBusy ? null : _savePublic,
          icon: const DoodimoIcon(DoodimoGlyph.save),
          label: Text(context.strings.saveAPublicCopy),
        ),
        TextButton.icon(
          onPressed: _fileActionBusy ? null : _open,
          icon: const DoodimoIcon(DoodimoGlyph.arrowUpRight),
          label: Text(context.strings.openWithAnotherApp),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _fileActionBusy ? null : () => _choose(_selectedFormat),
          child: Text(context.strings.exportAnotherFormat),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope<void>(
    canPop: !_finalizing,
    onPopInvokedWithResult: (didPop, result) {
      if (didPop && !_finalizing) _cancellation?.cancelled = true;
    },
    child: CreativePanel(
      title: context.strings.exportThisLoop,
      canClose: !_finalizing,
      onClose: _close,
      actions: _artifact != null
          ? const []
          : [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('export-start'),
                  onPressed: _busy
                      ? _finalizing
                            ? null
                            : () => _cancellation?.cancelled = true
                      : _fileActionBusy ||
                            (_selectedFormat != ExportFormat.png && !_hasMusic)
                      ? null
                      : () => _export(_selectedFormat),
                  icon: DoodimoIcon(
                    _busy ? DoodimoGlyph.close : DoodimoGlyph.arrowUpRight,
                  ),
                  label: Text(
                    _busy
                        ? (_finalizing
                              ? context.strings.finishingLibraryEntry
                              : context.strings.cancelExport)
                        : _actionLabel(),
                  ),
                ),
              ),
            ],
      child: AnimatedSwitcher(
        duration: CreativeMotion.duration(context, CreativeMotion.selection),
        switchInCurve: CreativeMotion.curve,
        layoutBuilder: (current, previous) => current ?? const SizedBox(),
        child: _busy
            ? _working()
            : _artifact != null
            ? _ready()
            : _selection(),
      ),
    ),
  );
}
