import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../domain/recovery_export_port.dart';

import '../../../app/providers.dart';
import 'library_gallery_layout.dart';
import 'library_document_card.dart';
import '../../../creative_document/document.dart';
import '../../editor/presentation/canvas.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../../export/presentation/export_sheet.dart';
import '../../../design_system/name_dialog.dart';
import '../../../design_system/creative_panel.dart';
import 'library_state_panel.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../design_system/doodimo_icon.dart';

typedef ShareRecoveryData = Future<ShareResultStatus> Function(
  String path,
  Rect? origin,
);
final shareRecoveryDataProvider = Provider<ShareRecoveryData>(
  (ref) =>
      (path, origin) async => (await SharePlus.instance.share(
        ShareParams(
          files: [XFile(path, mimeType: 'application/json')],
          sharePositionOrigin: origin,
        ),
      )).status,
);

enum _Action { rename, duplicate, export, delete }

class DraftsPage extends ConsumerStatefulWidget {
  const DraftsPage({super.key});
  @override
  ConsumerState<DraftsPage> createState() => _DraftsPageState();
}

class _DraftsPageState extends ConsumerState<DraftsPage> {
  bool _busy = false;
  Future<void> _delete(String id, String title) async {
    final confirmed = await showCreativePanel<bool>(
      context: context,
      builder: (context) => CreativePanel(
        title: context.strings.deleteNamedItem(title),
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
        child: Text(context.strings.youCanUndoThisFromTheConfirmationMessage),
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

  Future<void> _exportRecovery(String id) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = await ref.read(repositoryProvider.future);
      if (repository is! RecoveryExportPort) {
        throw UnsupportedError('Recovery export unavailable');
      }
      final path = await (repository as RecoveryExportPort).exportRecoveryData(
        id,
      );
      if (!mounted) return;
      final box = context.findRenderObject() as RenderBox?;
      final status = await ref.read(shareRecoveryDataProvider)(
        path,
        box == null ? null : box.localToGlobal(Offset.zero) & box.size,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (status) {
            ShareResultStatus.dismissed => context.strings.shareDismissed,
            ShareResultStatus.unavailable => context.strings.shareUnavailable,
            ShareResultStatus.success => context.strings.shareClosed,
          }),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.strings.recoveryExportFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    backgroundColor: LibraryChromeScope.of(context) ? Colors.transparent : null,
    body: LibraryGalleryLayout(
      exports: false,
      scrollKey: 'drafts-scroll',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.strings.yourDrawings,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    context.strings.libraryDrawingsSubtitle,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.strings.refreshDrafts,
              onPressed: () => ref.invalidate(libraryProvider),
              icon: const DoodimoIcon(DoodimoGlyph.replay),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...ref
            .watch(libraryProvider)
            .when(
              loading: () => [
                const Padding(
                  padding: EdgeInsets.all(48),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (_, _) => [
                LibraryStatePanel(
                  glyph: DoodimoGlyph.replay,
                  title: context.strings.couldNotLoadYourDrawings,
                  message: context.strings.theOriginalFilesArePreserved,
                  action: OutlinedButton(
                    onPressed: () => ref.invalidate(libraryProvider),
                    child: Text(context.strings.retry),
                  ),
                ),
              ],
              data: (listing) =>
                  listing.projects.isEmpty && listing.failures.isEmpty
                  ? [
                      LibraryStatePanel(
                        glyph: DoodimoGlyph.draw,
                        title: context.strings.yourDrawings,
                        message: context
                            .strings
                            .yourDrawingsWillLiveHereCreateANewDrawingToBegin,
                        action: PrismAction(
                          onPressed: () => context.push('/editor/new'),
                          icon: const DoodimoIcon(DoodimoGlyph.add),
                          label: context.strings.libraryNewDrawing,
                        ),
                      ),
                    ]
                  : <Widget>[
                      for (final id in listing.failures)
                        ImmersiveSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const DoodimoIcon(
                                    DoodimoGlyph.help,
                                    size: 32,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          context
                                              .strings
                                              .aDrawingCouldNotBeRecovered,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          context
                                              .strings
                                              .theOriginalFilesArePreserved,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip:
                                        context.strings.deleteDamagedDrawing,
                                    onPressed: _busy
                                        ? null
                                        : () => _delete(
                                            id,
                                            context.strings.damagedDrawing,
                                          ),
                                    icon: const Icon(Icons.delete_outline),
                                  ),
                                ],
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  0,
                                  12,
                                  8,
                                ),
                                child: Wrap(
                                  spacing: 8,
                                  children: [
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () {
                                              ref.invalidate(libraryProvider);
                                              context.push('/editor/$id');
                                            },
                                      child: Text(context.strings.retry),
                                    ),
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _exportRecovery(id),
                                      icon: const DoodimoIcon(
                                        DoodimoGlyph.save,
                                      ),
                                      label: Text(
                                        context.strings.recoveryExport,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      for (final doc in listing.projects)
                        LibraryDocumentCard(
                          leading: SizedBox(
                            width: 80,
                            height: 100,
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: .8,
                                child: BackgroundSurface(
                                  paper: doc.effectiveBackground,
                                  maxWidth: 112,
                                  maxHeight: 140,
                                  child: CustomPaint(
                                    painter: DrawingPainter(doc),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          title: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.strings.libraryEditable,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .primary,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(doc.title),
                            ],
                          ),
                          subtitle: Text(
                            '${context.formatLocalDate(doc.updatedAt)}\n'
                            '${context.strings.drawingDetails(doc.root.label, context.formatNumber(doc.strokes.length), context.formatNumber(doc.tempo), scaleName(context, doc.scale))}'
                            '${listing.recoveredIds.contains(doc.id) ? '\n${context.strings.recoveredPreviousRevision}' : ''}',
                          ),
                          onTap: () => context.push('/editor/${doc.id}'),
                          trailing: PopupMenuButton<_Action>(
                            onOpened: () =>
                                ScaffoldMessenger.of(context).clearSnackBars(),
                            tooltip: context.strings.manageDrawing(doc.title),
                            enabled: !_busy,
                            icon: const DoodimoIcon(DoodimoGlyph.more),
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
                    ],
            ),
      ],
    ),
  );
}
