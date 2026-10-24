import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../editor/presentation/canvas.dart';

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
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final id in ['template-hills', 'template-rain'])
            SizedBox(
              width: 160,
              child: Card(
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.push('/editor/$id'),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 120,
                          child: CustomPaint(
                            size: const Size(136, 120),
                            painter: DrawingPainter(makeTemplate(id)),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(makeTemplate(id).title),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}
