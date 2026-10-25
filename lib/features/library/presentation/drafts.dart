import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import 'library_tabs.dart';
import '../../../creative_document/document.dart';
import '../../editor/presentation/canvas.dart';
import '../../export/presentation/export_sheet.dart';
import '../../../design_system/name_dialog.dart';

enum _Action { rename, duplicate, export, delete }

class DraftsPage extends ConsumerStatefulWidget {
  const DraftsPage({super.key});
  @override
  ConsumerState<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends ConsumerState<DraftsPage> {
  bool _busy = false;
  Future<void> _delete(String id, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.deleteNamedItem(title)),
        content: Text(context.strings.youCanUndoThisFromTheConfirmationMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.keepDrawing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final repository = await ref.read(repositoryProvider.future);
    await repository.softDelete(id);
    if (mounted) ref.invalidate(libraryProvider);
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.strings.drawingDeleted),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.strings.undo,
          onPressed: () async {
            try {
              await repository.restore(id);
              if (mounted) ref.invalidate(libraryProvider);
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context
                          .strings
                          .couldNotRestoreTheDrawingItsFilesArePreserved,
                    ),
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  Future<void> _act(ProjectDocument doc, _Action action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = await ref.read(repositoryProvider.future);
      if (!mounted) return;
      switch (action) {
        case _Action.rename:
          final name = await askDrawingName(context, doc.title);
          if (name != null) await repository.rename(doc.id, name);
        case _Action.duplicate:
          await repository.duplicate(doc.id);
        case _Action.export:
          await showExportSheet(context, doc);
        case _Action.delete:
          await _delete(doc.id, doc.title);
      }
      if (mounted) ref.invalidate(libraryProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.strings.couldNotChangeThisDrawingPleaseRetry),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(context.strings.yourDrawings),
      bottom: const LibraryTabs(exports: false),
      actions: [
        IconButton(
          tooltip: context.strings.refreshDrafts,
          onPressed: () => ref.invalidate(libraryProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ref
        .watch(libraryProvider)
        .when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(context.strings.couldNotLoadYourDrawings),
                TextButton(
                  onPressed: () => ref.invalidate(libraryProvider),
                  child: Text(context.strings.retry),
                ),
              ],
            ),
          ),
          data: (listing) =>
              listing.projects.isEmpty && listing.failures.isEmpty
              ? Center(
                  child: Text(
                    context
                        .strings
                        .yourDrawingsWillLiveHereCreateANewDrawingToBegin,
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    for (final id in listing.failures)
                      ListTile(
                        leading: const Icon(Icons.warning_amber),
                        title: Text(
                          context.strings.aDrawingCouldNotBeRecovered,
                        ),
                        subtitle: Text(
                          context.strings.theOriginalFilesArePreserved,
                        ),
                        trailing: IconButton(
                          tooltip: context.strings.deleteDamagedDrawing,
                          onPressed: _busy
                              ? null
                              : () =>
                                    _delete(id, context.strings.damagedDrawing),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ),
                    for (final doc in listing.projects)
                      Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: SizedBox(
                            width: 56,
                            height: 70,
                            child: ColoredBox(
                              color: Color(opaquePaperColor(doc.background)),
                              child: CustomPaint(painter: DrawingPainter(doc)),
                            ),
                          ),
                          title: Text(doc.title),
                          subtitle: Text(
                            context.strings.drawingDetails(
                                  context.formatNumber(doc.strokes.length),
                                  context.formatNumber(doc.tempo),
                                  doc.scale == MusicalScale.major
                                      ? context.strings.major
                                      : context.strings.minor,
                                ) +
                                (listing.recoveredIds.contains(doc.id)
                                    ? '\n${context.strings.recoveredPreviousRevision}'
                                    : ''),
                          ),
                          onTap: () => context.push('/editor/${doc.id}'),
                          trailing: PopupMenuButton<_Action>(
                            tooltip: context.strings.manageDrawing(doc.title),
                            enabled: !_busy,
                            onSelected: (action) => _act(doc, action),
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: _Action.rename,
                                child: Text(context.strings.rename),
                              ),
                              PopupMenuItem(
                                value: _Action.duplicate,
                                child: Text(context.strings.duplicate),
                              ),
                              PopupMenuItem(
                                value: _Action.export,
                                child: Text(context.strings.exportShare),
                              ),
                              PopupMenuItem(
                                value: _Action.delete,
                                child: Text(context.strings.delete),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
