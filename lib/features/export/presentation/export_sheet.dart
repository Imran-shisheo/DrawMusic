import '../../rating/application/rating_provider.dart';

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
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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
    if (_busy || _fileActionBusy) return;
    if (format == ExportFormat.png && widget.snapshot.strokes.isEmpty) {
      final confirmed = await showDialog<bool>(
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
        setState(() => _message = context.strings.exportCancelled);
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is ScoreComplexityException
              ? context.strings.scoreTooComplex
              : format == ExportFormat.mp4
              ? context.strings.videoExportFailed
              : context.strings.exportFailed,
        );
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

  @override
  Widget build(BuildContext context) {
    final duration = 480 / widget.snapshot.tempo;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.strings.exportThisLoop,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              context.strings.oneLoopExportSummary(
                context.formatDecimal(duration),
              ),
            ),
            const SizedBox(height: 16),
            Text(context.strings.pngExportDescription),
            Semantics(
              label: context.strings.pngOutputSize,
              child: DropdownButton<int>(
                key: const ValueKey('png-output-width'),
                value: _imageWidth,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: 1080,
                    child: Text(context.strings.pngHd),
                  ),
                  DropdownMenuItem(
                    value: 640,
                    child: Text(context.strings.pngCompact),
                  ),
                ],
                onChanged: (_busy || _fileActionBusy)
                    ? null
                    : (width) {
                        if (width != null) setState(() => _imageWidth = width);
                      },
              ),
            ),
            SwitchListTile.adaptive(
              title: Text(context.strings.transparentBackground),
              value: _transparentBackground,
              onChanged: (_busy || _fileActionBusy)
                  ? null
                  : (value) => setState(() => _transparentBackground = value),
            ),
            FilledButton.tonal(
              onPressed: (_busy || _fileActionBusy)
                  ? null
                  : () => _export(ExportFormat.png),
              child: Text(context.strings.exportPng),
            ),
            const SizedBox(height: 16),
            Text(
              context
                  .strings
                  .midiContainsNotesAndInstrumentInstructionsItMaySoundDiffer,
            ),
            const SizedBox(height: 8),
            if (!_hasMusic) Text(context.strings.drawSomethingToHearIt),
            FilledButton.tonal(
              onPressed: (_busy || _fileActionBusy || !_hasMusic)
                  ? null
                  : () => _export(ExportFormat.midi),
              child: Text(context.strings.exportMidi),
            ),
            Text(
              context.strings.wavExportSummary(
                context.formatNumber(((duration + 1.25) * 88.2).round()),
              ),
            ),
            FilledButton.tonal(
              onPressed: (_busy || _fileActionBusy || !_hasMusic)
                  ? null
                  : () => _export(ExportFormat.wav),
              child: Text(context.strings.exportWav),
            ),
            const SizedBox(height: 12),
            Text(
              context
                  .strings
                  .mp4AnimatesThisDrawingWithItsMusicVideoExportCancelsIfYouL,
            ),
            DropdownButton<int>(
              key: const ValueKey('video-output-width'),
              value: _width,
              isExpanded: true,
              items: [
                DropdownMenuItem(
                  value: 1080,
                  child: Text(context.strings.hd1080135030Fps),
                ),
                DropdownMenuItem(
                  value: 640,
                  child: Text(context.strings.compact64080030Fps),
                ),
              ],
              onChanged: (_busy || _fileActionBusy)
                  ? null
                  : (width) {
                      if (width != null) {
                        setState(() => _width = width);
                      }
                    },
            ),
            Semantics(
              label: context.strings.videoFrameRate,
              child: DropdownButton<int>(
                key: const ValueKey('video-output-fps'),
                itemHeight: null,
                value: _fps,
                isExpanded: true,
                items: [
                  DropdownMenuItem(
                    value: 30,
                    child: Text(context.strings.videoFps30),
                  ),
                  DropdownMenuItem(
                    value: 60,
                    child: Text(context.strings.videoFps60),
                  ),
                ],
                onChanged: (_busy || _fileActionBusy)
                    ? null
                    : (fps) {
                        if (fps != null) setState(() => _fps = fps);
                      },
              ),
            ),
            FilledButton.tonal(
              onPressed: (_busy || _fileActionBusy || !_hasMusic)
                  ? null
                  : () => _export(ExportFormat.mp4),
              child: Text(context.strings.exportMp4),
            ),
            if (_busy) ...[
              LinearProgressIndicator(value: _progress),
              TextButton(
                onPressed: _finalizing
                    ? null
                    : () {
                        if (!_finalizing) _cancellation?.cancelled = true;
                      },
                child: Text(
                  _finalizing
                      ? context.strings.finishingLibraryEntry
                      : context.strings.cancelExport,
                ),
              ),
            ],
            if (_message != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_message!, semanticsLabel: _message),
              ),
            if (_artifact != null) ...[
              Text(_artifact!.name),
              FilledButton.icon(
                onPressed: _fileActionBusy ? null : _share,
                icon: const Icon(Icons.ios_share),
                label: Text(context.strings.shareExportedFile),
              ),
              FilledButton.tonalIcon(
                onPressed: _fileActionBusy ? null : _savePublic,
                icon: const Icon(Icons.save_alt),
                label: Text(context.strings.saveAPublicCopy),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strings.close),
            ),
          ],
        ),
      ),
    );
  }
}
