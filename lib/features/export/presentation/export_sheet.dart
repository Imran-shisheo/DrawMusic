import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../export_library/data/export_actions.dart';

import '../../../creative_document/document.dart';
import '../data/file_export_adapter.dart';
import '../data/android_video_export_adapter.dart';
import '../domain/export_port.dart';

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

  Future<void> _export(ExportFormat format) async {
    if (_busy || _fileActionBusy) return;
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
      final artifact = format == ExportFormat.mp4
          ? await AndroidVideoExportAdapter(directory).exportVideo(
              widget.snapshot,
              cancellation,
              width: _width,
              onProgress: (progress) {
                if (mounted && !cancellation.cancelled) {
                  setState(() => _progress = progress);
                }
              },
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
      if (mounted) ref.invalidate(exportListingProvider);
      if (mounted && !cancellation.cancelled) {
        setState(() {
          _artifact = artifact;
          _message = detailsSaved ? 'Export ready on this device.' : 'Export created. Library details could not be saved; the file is preserved under Library → Exports.';
        });
      }
    } on ExportCancelled {
      if (mounted) {
        setState(() => _message = 'Export canceled. Your drawing is safe.');
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = format == ExportFormat.mp4
              ? 'Video export failed. Try compact resolution or check storage, then retry.'
              : 'Export failed. Check storage and retry.',
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
          () => _message = result == ShareResultStatus.dismissed
              ? 'Share sheet dismissed. Export is still saved.'
              : 'Share sheet closed. Delivery is handled by the selected app.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Sharing unavailable. The exported file is still saved.',
        );
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
              ? 'Save canceled. Your export is still saved on this device.'
              : 'Saved a copy to ${result.destination}.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not save a public copy. Check storage and retry. Your export is preserved.',
        );
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
              'Export this loop',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'One loop · ${duration.toStringAsFixed(2)} seconds. Exports use the drawing and settings shown when this panel opened.',
            ),
            const SizedBox(height: 16),
            const Text(
              'MIDI contains notes and instrument instructions. It may sound different in another player.',
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: (_busy || _fileActionBusy)
                  ? null
                  : () => _export(ExportFormat.midi),
              child: const Text('Export MIDI'),
            ),
            Text(
              'WAV uses the original preview voices. One loop + 1.25 s tail, 44.1 kHz mono PCM16 (~${((duration + 1.25) * 88.2).round()} KB).',
            ),
            FilledButton.tonal(
              onPressed: (_busy || _fileActionBusy)
                  ? null
                  : () => _export(ExportFormat.wav),
              child: const Text('Export WAV'),
            ),
            const SizedBox(height: 12),
            const Text(
              'MP4 animates this drawing with its music. Video export cancels if you leave the app.',
            ),
            DropdownButton<int>(
              value: _width,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: 1080,
                  child: Text('HD · 1080 × 1350 · 30 fps'),
                ),
                DropdownMenuItem(
                  value: 640,
                  child: Text('Compact · 640 × 800 · 30 fps'),
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
            FilledButton.tonal(
              onPressed: (_busy || _fileActionBusy)
                  ? null
                  : () => _export(ExportFormat.mp4),
              child: const Text('Export MP4'),
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
                  _finalizing ? 'Finishing library entry…' : 'Cancel export',
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
                label: const Text('Share exported file'),
              ),
              FilledButton.tonalIcon(
                onPressed: _fileActionBusy ? null : _savePublic,
                icon: const Icon(Icons.save_alt),
                label: const Text('Save a public copy'),
              ),
            ],
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
