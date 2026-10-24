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
        title: Text('Delete $title?'),
        content: const Text('You can undo this from the confirmation message.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep drawing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
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
        content: const Text('Drawing deleted'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await repository.restore(id);
              if (mounted) ref.invalidate(libraryProvider);
            } catch (_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not restore the drawing. Its files are preserved.',
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
          const SnackBar(
            content: Text('Could not change this drawing. Please retry.'),
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
      title: const Text('Your drawings'),
      bottom: const LibraryTabs(exports: false),
      actions: [
        IconButton(
          tooltip: 'Refresh drafts',
          onPressed: () => ref.invalidate(libraryProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ref
        .watch(libraryProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load your drawings.'),
                TextButton(
                  onPressed: () => ref.invalidate(libraryProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (listing) =>
              listing.projects.isEmpty && listing.failures.isEmpty
              ? const Center(
                  child: Text(
                    'Your drawings will live here.\nCreate a new drawing to begin.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  children: [
                    for (final id in listing.failures)
                      ListTile(
                        leading: const Icon(Icons.warning_amber),
                        title: const Text('A drawing could not be recovered'),
                        subtitle: const Text(
                          'The original files are preserved.',
                        ),
                        trailing: IconButton(
                          tooltip: 'Delete damaged drawing',
                          onPressed: _busy
                              ? null
                              : () => _delete(id, 'damaged drawing'),
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
                              color: Color(doc.background),
                              child: CustomPaint(painter: DrawingPainter(doc)),
                            ),
                          ),
                          title: Text(doc.title),
                          subtitle: Text(
                            '${doc.strokes.length} marks · ${doc.tempo} BPM · C ${doc.scale.name}${listing.recoveredIds.contains(doc.id) ? '\nRecovered previous revision' : ''}',
                          ),
                          onTap: () => context.push('/editor/${doc.id}'),
                          trailing: PopupMenuButton<_Action>(
                            tooltip: 'Manage ${doc.title}',
                            enabled: !_busy,
                            onSelected: (action) => _act(doc, action),
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: _Action.rename,
                                child: Text('Rename'),
                              ),
                              PopupMenuItem(
                                value: _Action.duplicate,
                                child: Text('Duplicate'),
                              ),
                              PopupMenuItem(
                                value: _Action.export,
                                child: Text('Export / share'),
                              ),
                              PopupMenuItem(
                                value: _Action.delete,
                                child: Text('Delete'),
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
