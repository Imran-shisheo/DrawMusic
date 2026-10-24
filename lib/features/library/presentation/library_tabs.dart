import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class LibraryTabs extends StatelessWidget implements PreferredSizeWidget {
  const LibraryTabs({super.key, required this.exports});
  final bool exports;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: SegmentedButton<bool>(
      segments: const [
        ButtonSegment(
          value: false,
          icon: Icon(Icons.draw_outlined),
          label: Text('Drafts'),
        ),
        ButtonSegment(
          value: true,
          icon: Icon(Icons.file_copy_outlined),
          label: Text('Exports'),
        ),
      ],
      selected: {exports},
      onSelectionChanged: (selection) =>
          context.go(selection.single ? '/exports' : '/drafts'),
    ),
  );
}
