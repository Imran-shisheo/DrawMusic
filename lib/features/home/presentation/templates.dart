import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/brand_colors.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/motion.dart';
import '../../../l10n/strings.dart';
import '../../../l10n/template_descriptions.dart';
import '../../backgrounds/presentation/background_surface.dart';
import '../../editor/presentation/canvas.dart';
import '../domain/template_catalog.dart';

class TemplateGallery extends StatelessWidget {
  const TemplateGallery({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
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
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 170).floor().clamp(1, 4);
          final width = (constraints.maxWidth - 16 * (columns - 1)) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 24,
            children: [
              for (var i = 0; i < originalTemplates.length; i++)
                SizedBox(
                  width: width,
                  child: _TemplateSleeve(index: i),
                ),
            ],
          );
        },
      ),
    ],
  );
}

class _TemplateSleeve extends StatefulWidget {
  const _TemplateSleeve({required this.index});
  final int index;
  @override
  State<_TemplateSleeve> createState() => _TemplateSleeveState();
}

class _TemplateSleeveState extends State<_TemplateSleeve> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final template = originalTemplates[widget.index];
    final colors = Theme.of(context).colorScheme;
    final document = template.create();
    final sleeve = [
      DoodimoColors.lavender,
      DoodimoColors.lime,
      DoodimoColors.coral,
    ][widget.index % 3];
    final caption = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            template.title,
            style: Theme.of(context).textTheme.titleSmall
                ?.copyWith(color: colors.onSurface),
          ),
        ),
        const SizedBox(width: 8),
        DoodimoIcon(
          DoodimoGlyph.arrowUpRight,
          size: 18,
          color: colors.onSurfaceVariant,
        ),
      ],
    );
    void open() => context.push('/editor/${template.id}');
    return Semantics(
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
              borderRadius: BorderRadius.circular(12),
              onTap: open,
              onTapDown: (_) => setState(() => _pressed = true),
              onTapCancel: () => setState(() => _pressed = false),
              onTapUp: (_) => setState(() => _pressed = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  caption,
                  const SizedBox(height: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.surfaceContainerHigh,
                          colors.surfaceContainerLow,
                        ],
                      ),
                      border: Border.all(color: sleeve.withValues(alpha: .45)),
                      boxShadow: [
                        BoxShadow(
                          color: sleeve.withValues(alpha: .08),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: AspectRatio(
                        aspectRatio: 4 / 5,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .08),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: BackgroundSurface(
                            paper: document.effectiveBackground,
                            maxWidth: 320,
                            maxHeight: 400,
                            child: CustomPaint(
                              painter: DrawingPainter(document),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
