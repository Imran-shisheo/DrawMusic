import 'package:flutter/material.dart';

import '../../../creative_document/document.dart';
import '../../../app/artwork_navigation.dart';
import '../../../design_system/artwork_flight.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/motion.dart';
import '../../../l10n/strings.dart';
import '../../../l10n/template_descriptions.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../../editor/presentation/canvas.dart';
import '../domain/template_catalog.dart';

class TemplateGallery extends StatefulWidget {
  const TemplateGallery({super.key});
  @override
  State<TemplateGallery> createState() => _TemplateGalleryState();
}

class _TemplateGalleryState extends State<TemplateGallery> {
  int? _columns;
  Widget? _rows;

  Widget _rowsFor(int columns) {
    if (_columns == columns) return _rows!;
    _columns = columns;
    // Sliver constraints also change on every scroll pixel. Only a column-count
    // change needs a new delegate; retained rows still react to inherited theme,
    // text-scale and locale changes through their own element dependencies.
    return _rows = SliverList.builder(
      itemCount: (originalTemplates.length / columns).ceil(),
      itemBuilder: (context, row) => Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var column = 0; column < columns; column++) ...[
              if (column > 0) const SizedBox(width: 16),
              Expanded(
                child: row * columns + column < originalTemplates.length
                    ? _TemplateSleeve(
                        key: ValueKey(
                          originalTemplates[row * columns + column].id,
                        ),
                        index: row * columns + column,
                      )
                    : const SizedBox(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SliverMainAxisGroup(
    slivers: [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  context.strings.tryAStartingPoint,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const DoodimoIcon(DoodimoGlyph.music),
            ],
          ),
        ),
      ),
      SliverLayoutBuilder(
        builder: (context, constraints) =>
            _rowsFor((constraints.crossAxisExtent / 170).floor().clamp(1, 4)),
      ),
    ],
  );
}

class _TemplateSleeve extends StatefulWidget {
  const _TemplateSleeve({super.key, required this.index});
  final int index;
  @override
  State<_TemplateSleeve> createState() => _TemplateSleeveState();
}

class _TemplateSleeveState extends State<_TemplateSleeve> {
  bool _pressed = false;
  late ProjectDocument _document;

  @override
  void initState() {
    super.initState();
    _document = originalTemplates[widget.index].create();
  }

  @override
  void didUpdateWidget(_TemplateSleeve oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _document = originalTemplates[widget.index].create();
      _pressed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final template = originalTemplates[widget.index];
    final colors = Theme.of(context).colorScheme;
    final document = _document;
    return ArtworkFlightSource(
      routeId: template.id,
      document: document,
      onOpen: (intent) async {
        await openEditorWithArtworkFlight(context, template.id, intent);
      },
      artwork: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: BackgroundSurface(
            paper: document.effectiveBackground,
            maxWidth: 320,
            maxHeight: 400,
            child: CustomPaint(painter: DrawingPainter(document)),
          ),
        ),
      ),
      builder: (context, anchor, open) => Semantics(
        button: true,
        label:
            '${template.title}. ${localizedTemplateDescription(context, template.kind)}',
        onTap: open,
        child: ExcludeSemantics(
          child: AnimatedScale(
            scale: _pressed ? .98 : 1,
            duration: CreativeMotion.duration(context, CreativeMotion.press),
            curve: CreativeMotion.curve,
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: open,
                onTapDown: (_) => setState(() => _pressed = true),
                onTapCancel: () => setState(() => _pressed = false),
                onTapUp: (_) => setState(() => _pressed = false),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ImmersiveSurface(
                      padding: const EdgeInsets.all(8),
                      radius: 18,
                      child: anchor,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            template.title,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(color: colors.onSurface),
                          ),
                        ),
                        const SizedBox(width: 6),
                        const DoodimoIcon(DoodimoGlyph.arrowUpRight, size: 18),
                      ],
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
}
