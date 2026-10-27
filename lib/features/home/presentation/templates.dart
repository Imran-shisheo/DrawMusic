import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../domain/template_catalog.dart';
import '../../../l10n/template_descriptions.dart';
import '../../editor/presentation/canvas.dart';
import '../../backgrounds/presentation/background_surface.dart';

class TemplateGallery extends StatelessWidget {
  const TemplateGallery({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.strings.tryAStartingPoint,
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final two = constraints.maxWidth >= 288;
          final width = two
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final template in originalTemplates)
                SizedBox(
                  width: width,
                  child: Semantics(
                    label:
                        '${template.title}. ${localizedTemplateDescription(context, template.kind)}',
                    button: true,
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => context.push('/editor/${template.id}'),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            children: [
                              ExcludeSemantics(
                                child: SizedBox(
                                  height: 120,
                                  width: 96,
                                  child: BackgroundSurface(
                                    paper: template
                                        .create()
                                        .effectiveBackground,
                                    maxWidth: 320,
                                    maxHeight: 400,
                                    child: CustomPaint(
                                      painter: DrawingPainter(
                                        template.create(),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(template.title),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );
}
