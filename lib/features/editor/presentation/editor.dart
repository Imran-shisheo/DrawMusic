import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../design_system/theme.dart';

class EditorPage extends StatelessWidget {
  const EditorPage({super.key, required this.projectId});
  final String projectId;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: IconButton(
        tooltip: 'Back to gallery',
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        },
      ),
      title: const Text('Untitled drawing'),
    ),
    body: const Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text('120 BPM · C major pentatonic'),
          SizedBox(height: 16),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paper,
                borderRadius: BorderRadius.all(Radius.circular(20)),
              ),
              child: Center(child: Text('Your canvas is ready.')),
            ),
          ),
          SizedBox(height: 16),
          Text('Draw something to hear it.'),
          IconButton(
            onPressed: null,
            tooltip: 'Play — draw something first',
            icon: Icon(Icons.play_circle, size: 64),
          ),
        ],
      ),
    ),
  );
}
