import 'package:scribblesong/l10n/strings.dart';

import '../../../creative_document/document.dart';

import 'dart:async';
import 'dart:io';

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
    final strings = context.strings;
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
                ? strings.librarySaveCancelled
                : strings.savedNamedPublicCopy(
                    entry.artifact.name,
                    result.destination,
                  ),
          );
        case _Action.share:
          final box = context.findRenderObject() as RenderBox?;
          final result = await ref.read(shareExportProvider)(
            entry.artifact,
            box == null ? null : box.localToGlobal(Offset.zero) & box.size,
          );
          _message(switch (result) {
            ShareResultStatus.dismissed => strings.shareDismissed,
            ShareResultStatus.unavailable => strings.libraryShareUnavailable,
            ShareResultStatus.success => strings.shareClosed,
          });
        case _Action.rename:
          final name = await askDrawingName(
            context,
            entry.artifact.name.replaceFirst(
              RegExp(r'\.(mid|wav|mp4|png)$'),
              '',
            ),
            heading: strings.nameYourExport,
          );
          if (name != null) await repository.rename(entry.id, name);
        case _Action.source:
          context.push('/editor/${entry.artifact.projectId}');
        case _Action.delete:
          final confirmed = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(strings.deleteNamedItem(entry.artifact.name)),
              content: Text(
                context
                    .strings
                    .thisRemovesTheAppPrivateExportAfterTheUndoWindowCopiesSave,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(strings.keepExport),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(strings.delete),
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
              content: Text(strings.exportRemovedFromTheLibrary),
              duration: const Duration(seconds: 6),
              action: SnackBarAction(
                label: strings.undo,
                onPressed: () async {
                  try {
                    await repository.restore(entry.id);
                    if (mounted) ref.invalidate(exportListingProvider);
                  } catch (_) {
                    _message(strings.exportRestoreFailed);
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
        _Action.open => strings.exportOpenFailed,
        _Action.save => strings.libraryPublicSaveFailed,
        _Action.share => strings.libraryShareUnavailable,
        _ => strings.exportChangeFailed,
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.strings.yourExports),
      bottom: const LibraryTabs(exports: true),
      actions: [
        IconButton(
          tooltip: context.strings.refreshExports,
          onPressed: () => ref.invalidate(exportListingProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ref
        .watch(exportListingProvider)
        .when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.strings.couldNotLoadYourExports),
                TextButton(
                  onPressed: () => ref.invalidate(exportListingProvider),
                  child: Text(context.strings.retry),
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
                          ? context.strings.exportsUnreadable
                          : context.strings.exportsEmpty,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
                  children: [
                    if (listing.detailFailures > 0)
                      Text(
                        context
                            .strings
                            .someExportDetailsCouldNotBeReadTheOriginalFilesArePreserve,
                      ),
                    for (final entry in listing.entries) _card(context, entry),
                  ],
                ),
        ),
  );
  Widget _card(BuildContext context, LibraryExport entry) {
    final format = entry.id.split('.').last.toUpperCase();
    final date = context.formatLocalDate(entry.createdAt);
    return Card(
      child: ListTile(
        isThreeLine: true,
        leading: format == 'PNG' && entry.available
            ? SizedBox(
                width: 56,
                height: 70,
                child: Image.file(
                  File(entry.artifact.path),
                  cacheWidth: 112,
                  fit: BoxFit.contain,
                  excludeFromSemantics: true,
                  errorBuilder: (_, _, _) =>
                      const Icon(Icons.broken_image_outlined),
                ),
              )
            : entry.preview == null
            ? Icon(
                format == 'MP4'
                    ? Icons.movie_outlined
                    : Icons.audio_file_outlined,
              )
            : SizedBox(
                width: 56,
                height: 70,
                child: ColoredBox(
                  color: Color(opaquePaperColor(entry.preview!.background)),
                  child: CustomPaint(painter: DrawingPainter(entry.preview!)),
                ),
              ),
        title: Text(
          entry.artifact.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${context.strings.exportDetails(format, date, context.formatNumber((entry.bytes / 1024).ceil()))}\n${!entry.available
              ? context.strings.fileUnavailableExportAgain
              : entry.legacy
              ? context.strings.olderExportSourceDetailsUnavailable
              : context.strings.drawingMayHaveChangedSinceExport}',
        ),
        onTap: _busy || !entry.available
            ? null
            : () => _act(entry, _Action.open),
        trailing: PopupMenuButton<_Action>(
          tooltip: context.strings.exportActions(entry.artifact.name),
          enabled: !_busy,
          onSelected: (action) => _act(entry, action),
          itemBuilder: (_) => [
            PopupMenuItem(
              value: _Action.open,
              enabled: entry.available,
              child: Text(context.strings.openWithAnotherApp),
            ),
            PopupMenuItem(
              value: _Action.save,
              enabled: entry.available,
              child: Text(context.strings.saveACopy),
            ),
            PopupMenuItem(
              value: _Action.share,
              enabled: entry.available,
              child: Text(context.strings.share),
            ),
            PopupMenuItem(
              value: _Action.rename,
              child: Text(context.strings.rename),
            ),
            PopupMenuItem(
              value: _Action.source,
              enabled: entry.artifact.projectId.isNotEmpty,
              child: Text(context.strings.openSourceDrawing),
            ),
            PopupMenuItem(
              value: _Action.delete,
              child: Text(context.strings.delete),
            ),
          ],
        ),
      ),
    );
  }
}
