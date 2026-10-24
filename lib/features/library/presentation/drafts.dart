import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../editor/presentation/canvas.dart';

class DraftsPage extends ConsumerWidget {
  const DraftsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Your drawings'),
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
                    if (listing.failures.isNotEmpty)
                      Text(
                        '${listing.failures.length} drawing(s) could not be recovered. Their files are preserved.',
                        style: const TextStyle(color: Colors.red),
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
                            '${doc.strokes.length} marks · ${doc.tempo} BPM · C ${doc.scale.name}',
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/editor/${doc.id}'),
                        ),
                      ),
                  ],
                ),
        ),
  );
}
