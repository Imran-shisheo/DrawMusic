import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../design_system/name_dialog.dart';
import '../../editor/presentation/canvas.dart';
import '../../library/presentation/library_tabs.dart';
import '../data/export_actions.dart';
import '../domain/export_library.dart';

enum _Action { open, save, share, rename, source, delete }

class ExportsPage extends ConsumerStatefulWidget {
  const ExportsPage({super.key});
  @override
  ConsumerState<ExportsPage> createState() => _ExportsPageState();
}

class _ExportsPageState extends ConsumerState<ExportsPage> {
  bool _busy = false;
  final _purges = <Timer>[];
  @override
  void dispose() {
    for (final timer in _purges) {
      timer.cancel();
    }
    super.dispose();
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _act(LibraryExport entry, _Action action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = await ref.read(exportLibraryProvider.future);
      if (!mounted) return;
      switch (action) {
        case _Action.open:
          await ref.read(exportFileActionsProvider).open(entry.artifact);
        case _Action.save:
          final result = await ref
              .read(exportFileActionsProvider)
              .save(entry.artifact);
          _message(
            result == null
                ? 'Save canceled. Your export is still in the library.'
                : 'Saved ${entry.artifact.name} to ${result.destination}.',
          );
        case _Action.share:
          final box = context.findRenderObject() as RenderBox?;
          final result = await ref.read(shareExportProvider)(
            entry.artifact,
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
          );
          _message(
            result == ShareResultStatus.dismissed
                ? 'Share sheet dismissed. Export is still saved.'
                : 'Share sheet closed. Delivery is handled by the selected app.',
          );
        case _Action.rename:
          final name = await askDrawingName(
            context,
            entry.artifact.name.replaceFirst(RegExp(r'\.(mid|wav|mp4)$'), ''),
            heading: 'Name your export',
          );
          if (name != null) await repository.rename(entry.id, name);
        case _Action.source:
          context.push('/editor/${entry.artifact.projectId}');
        case _Action.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Delete ${entry.artifact.name}?'),
              content: const Text(
                'This removes the app-private export after the Undo window. Copies saved or shared elsewhere stay. Your editable drawing is preserved.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Keep export'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirmed != true) return;
          await repository.remove(entry.id);
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Export removed from the library'),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  try {
                    await repository.restore(entry.id);
                    if (mounted) ref.invalidate(exportListingProvider);
                  } catch (_) {
                    _message(
                      'Could not restore this export. Open the drawing to export again.',
                    );
                  }
                },
              ),
            ),
          );
          _purges.add(
            Timer(const Duration(seconds: 8), () {
              if (mounted) ref.invalidate(exportListingProvider);
            }),
          );
      }
      if (mounted && (action == _Action.rename || action == _Action.delete)) {
        ref.invalidate(exportListingProvider);
      }
    } catch (_) {
      _message(switch (action) {
        _Action.open => 'Could not open this export. A compatible app may be unavailable. Try sharing it.',
        _Action.save => 'Could not save a public copy. Check storage and retry. The library file is preserved.',
        _Action.share => 'Sharing unavailable. The library file is preserved.',
        _ => 'Could not change this export. Please retry.',
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your exports'),
      bottom: const LibraryTabs(exports: true),
      actions: [
        IconButton(
          tooltip: 'Refresh exports',
          onPressed: () => ref.invalidate(exportListingProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ref
        .watch(exportListingProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your exports.'),
                TextButton(
                  onPressed: () => ref.invalidate(exportListingProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (listing) => listing.entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      listing.detailFailures > 0
                          ? 'Some exports could not be read. Their files are preserved. Try Refresh exports.'
                          : 'Completed exports will appear here.\nOpen a drawing and choose Export to create MIDI, WAV or MP4.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  children: [
                    if (listing.detailFailures > 0)
                      const Text(
                        'Some export details could not be read. The original files are preserved.',
                      ),
                    for (final entry in listing.entries) _card(context, entry),
                  ],
                ),
        ),
  );
  Widget _card(BuildContext context, LibraryExport entry) {
    final format = entry.id.split('.').last.toUpperCase();
    final date = MaterialLocalizations.of(context)
        .formatShortDate(entry.createdAt.toLocal());
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: entry.preview == null
            ? Icon(
                format == 'MP4'
                    ? Icons.movie_outlined
                    : Icons.audio_file_outlined,
              )
            : SizedBox(
                width: 56,
                height: 70,
                child: ColoredBox(
                  color: Color(entry.preview!.background),
                  child: CustomPaint(painter: DrawingPainter(entry.preview!)),
                ),
              ),
        title: Text(
          entry.artifact.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$format · $date · ${(entry.bytes / 1024).ceil()} KB\n${!entry.available
              ? 'File unavailable — export again from the drawing'
              : entry.legacy
              ? 'Older export — source details unavailable'
              : 'Drawing may have changed since this export'}',
        ),
        onTap: _busy || !entry.available
            ? null
            : () => _act(entry, _Action.open),
        trailing: PopupMenuButton<_Action>(
          tooltip: 'Actions for ${entry.artifact.name}',
          enabled: !_busy,
          onSelected: (action) => _act(entry, action),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _Action.open,
              enabled: entry.available,
              child: const Text('Open with another app'),
            ),
            PopupMenuItem(
              value: _Action.save,
              enabled: entry.available,
              child: const Text('Save a copy'),
            ),
            PopupMenuItem(
              value: _Action.share,
              enabled: entry.available,
              child: const Text('Share'),
            ),
            const PopupMenuItem(value: _Action.rename, child: Text('Rename')),
            PopupMenuItem(
              value: _Action.source,
              enabled: entry.artifact.projectId.isNotEmpty,
              child: const Text('Open source drawing'),
            ),
            const PopupMenuItem(value: _Action.delete, child: Text('Delete')),
          ],
        ),
      ),
    );
  }
}
