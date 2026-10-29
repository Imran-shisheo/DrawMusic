import '../../../app/artwork_navigation.dart';

import 'package:scribblesong/l10n/strings.dart';

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../design_system/name_dialog.dart';
import '../../../design_system/creative_panel.dart';
import '../../library/presentation/library_state_panel.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/immersive_surface.dart';
import '../../editor/presentation/canvas.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../../library/presentation/library_gallery_layout.dart';
import '../../library/presentation/library_document_card.dart';
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
      ScaffoldMessenger.of(context).clearSnackBars();
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
          await openEditorWithArtworkFlight(
            context,
            entry.artifact.projectId,
            null,
          );
        case _Action.delete:
          final confirmed = await showCreativePanel<bool>(
            context: context,
            builder: (context) => CreativePanel(
              title: strings.deleteNamedItem(entry.artifact.name),
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
              child: Text(
                context
                    .strings
                    .thisRemovesTheAppPrivateExportAfterTheUndoWindowCopiesSave,
              ),
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
    backgroundColor: LibraryChromeScope.of(context) ? Colors.transparent : null,
    body: LibraryGalleryLayout(
      exports: true,
      scrollKey: 'exports-scroll',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Tooltip(
                message: context.strings.libraryExportsSubtitle,
                child: Text(
                  context.strings.yourExports,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            IconButton(
              tooltip: context.strings.refreshExports,
              onPressed: () => ref.invalidate(exportListingProvider),
              icon: const DoodimoIcon(DoodimoGlyph.replay),
            ),
          ],
        ),
        const SizedBox(height: 20),
        ...ref
            .watch(exportListingProvider)
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
                  title: context.strings.couldNotLoadYourExports,
                  message: context.strings.theOriginalFilesArePreserved,
                  action: OutlinedButton(
                    onPressed: () => ref.invalidate(exportListingProvider),
                    child: Text(context.strings.retry),
                  ),
                ),
              ],
              data: (listing) => listing.entries.isEmpty
                  ? [
                      LibraryStatePanel(
                        glyph: DoodimoGlyph.export,
                        title: context.strings.yourExports,
                        message: listing.detailFailures > 0
                            ? context.strings.exportsUnreadable
                            : context.strings.exportsEmpty,
                      ),
                    ]
                  : <Widget>[
                      if (listing.detailFailures > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            context
                                .strings
                                .someExportDetailsCouldNotBeReadTheOriginalFilesArePreserve,
                          ),
                        ),
                      _featured(context, listing.entries.first),
                      const SizedBox(height: 16),
                      for (final entry in listing.entries)
                        _card(context, entry),
                    ],
            ),
      ],
    ),
  );
  Widget _preview(LibraryExport entry, {required bool large}) {
    final format = entry.id.split('.').last.toUpperCase();
    if (format == 'PNG' && entry.available) {
      return Image.file(
        File(entry.artifact.path),
        cacheWidth: large ? 420 : 112,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
        errorBuilder: (_, _, _) =>
            const Center(child: DoodimoIcon(DoodimoGlyph.image, size: 40)),
      );
    }
    if (entry.preview != null) {
      return Center(
        child: AspectRatio(
          aspectRatio: .8,
          child: BackgroundSurface(
            key: ValueKey(
              '${large ? 'export-feature-preview' : 'export-preview'}-${entry.id}',
            ),
            // This immutable export revision owns its paper and geometry.
            paper: entry.preview!.effectiveBackground,
            maxWidth: large ? 420 : 112,
            maxHeight: large ? 525 : 140,
            child: CustomPaint(painter: DrawingPainter(entry.preview!)),
          ),
        ),
      );
    }
    return Center(
      child: DoodimoIcon(switch (format) {
        'MP4' => DoodimoGlyph.video,
        'PNG' => DoodimoGlyph.image,
        'MID' => DoodimoGlyph.notes,
        _ => DoodimoGlyph.sound,
      }, size: large ? 64 : 32),
    );
  }

  Widget _featured(BuildContext context, LibraryExport entry) {
    final colors = Theme.of(context).colorScheme;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
    return ImmersiveSurface(
      key: const ValueKey('export-featured-artwork'),
      padding: const EdgeInsets.all(12),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 360,
                maxHeight: largeText ? 220 : 280,
              ),
              child: AspectRatio(
                aspectRatio: .8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colors.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: _preview(entry, large: true),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          RichText(
            key: const ValueKey('export-feature-caption'),
            textAlign: TextAlign.center,
            textScaler: MediaQuery.textScalerOf(context),
            text: TextSpan(
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colors.onSurface,
                fontWeight: FontWeight.w700,
              ),
              children: [
                TextSpan(
                  text: entry.artifact.name.replaceFirst(
                    RegExp(r'\.[^.]+$'),
                    '',
                  ),
                ),
                TextSpan(
                  text:
                      RegExp(r'\.[^.]+$')
                          .firstMatch(entry.artifact.name)
                          ?.group(0) ??
                      '',
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, bounds) {
              final share = FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                key: ValueKey('export-feature-share-${entry.id}'),
                onPressed: _busy || !entry.available
                    ? null
                    : () => _act(entry, _Action.share),
                icon: const DoodimoIcon(DoodimoGlyph.export),
                label: Text(context.strings.shareExportedFile),
              );
              final save = OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(48, 64),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                key: ValueKey('export-feature-save-${entry.id}'),
                onPressed: _busy || !entry.available
                    ? null
                    : () => _act(entry, _Action.save),
                icon: const DoodimoIcon(DoodimoGlyph.save),
                label: Text(context.strings.saveAPublicCopy),
              );
              if (!largeText && bounds.maxWidth >= 320) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: share),
                    const SizedBox(width: 8),
                    Expanded(child: save),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [share, const SizedBox(height: 8), save],
              );
            },
          ),
        ],
      ),
    );
  }

  String _exportDetails(BuildContext context, LibraryExport entry) {
    final format = entry.id.split('.').last.toUpperCase();
    final date = context.formatLocalDate(entry.createdAt);
    return '${context.strings.exportDetails(format, date, context.formatNumber((entry.bytes / 1024).ceil()))}\n${!entry.available
        ? context.strings.fileUnavailableExportAgain
        : entry.legacy
        ? context.strings.olderExportSourceDetailsUnavailable
        : context.strings.drawingMayHaveChangedSinceExport}';
  }

  Widget _card(BuildContext context, LibraryExport entry) {
    final format = entry.id.split('.').last.toUpperCase();
    return LibraryDocumentCard(
      leading: SizedBox(
        key: ValueKey('export-thumbnail-${entry.id}'),
        width: 72,
        height: 90,
        child: _preview(entry, large: false),
      ),
      title: Tooltip(
        message: _exportDetails(context, entry),
        child: Text(entry.artifact.name, softWrap: true),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$format · ${switch (format) {
              'MP4' => context.strings.exportIntentVideo,
              'PNG' => context.strings.exportIntentImage,
              'MID' => context.strings.exportIntentNotes,
              _ => context.strings.exportIntentSound,
            }}',
          ),
          if (!entry.available || entry.legacy) ...[
            const SizedBox(height: 6),
            Text(
              !entry.available
                  ? context.strings.fileUnavailableExportAgain
                  : context.strings.olderExportSourceDetailsUnavailable,
            ),
          ],
        ],
      ),
      onTap: _busy || !entry.available ? null : () => _act(entry, _Action.open),
      primaryAction: IconButton.outlined(
        tooltip: context.strings.saveAPublicCopy,
        onPressed: _busy || !entry.available
            ? null
            : () => _act(entry, _Action.save),
        icon: const DoodimoIcon(DoodimoGlyph.save),
      ),
      trailing: PopupMenuButton<_Action>(
        onOpened: () => ScaffoldMessenger.of(context).clearSnackBars(),
        tooltip: context.strings.exportActions(entry.artifact.name),
        enabled: !_busy,
        icon: const DoodimoIcon(DoodimoGlyph.more),
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
          const PopupMenuDivider(),
          PopupMenuItem<_Action>(
            enabled: false,
            child: Text(
              _exportDetails(context, entry),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
