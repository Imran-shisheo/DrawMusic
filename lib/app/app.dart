import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design_system/theme.dart';
import '../features/editor/presentation/editor.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    ShellRoute(
      builder: (context, state, child) => Scaffold(
        body: child,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/editor/new'),
          icon: const Icon(Icons.add),
          label: const Text('New drawing'),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: state.uri.path == '/drafts'
              ? 1
              : state.uri.path == '/settings'
              ? 2
              : 0,
          onDestinationSelected: (i) =>
              context.go(['/home', '/drafts', '/settings'][i]),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.grid_view_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.folder_outlined),
              label: 'Drafts',
            ),
            NavigationDestination(icon: Icon(Icons.tune), label: 'Settings'),
          ],
        ),
      ),
      routes: [
        GoRoute(path: '/home', builder: (_, _) => const HomePage()),
        GoRoute(
          path: '/drafts',
          builder: (_, _) => const Scaffold(
            body: SafeArea(
              child: Center(
                child: Text(
                  'Your drawings will live here.\nCreate a new drawing to begin.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (_, _) => Scaffold(
            appBar: AppBar(title: const Text('Settings & help')),
            body: const ListTile(
              leading: Icon(Icons.music_note),
              title: Text('ScribbleSong'),
              subtitle: Text(
                'Draw left to right for time. Draw higher for higher notes.\nYour creations stay on this device.',
              ),
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/editor/:id',
      builder: (_, state) => EditorPage(projectId: state.pathParameters['id']!),
    ),
  ],
  errorBuilder: (context, _) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/home'),
        child: const Text('Page unavailable. Return home'),
      ),
    ),
  ),
);

class ScribbleSongApp extends StatefulWidget {
  const ScribbleSongApp({super.key});
  @override
  State<ScribbleSongApp> createState() => _ScribbleSongAppState();
}

class _ScribbleSongAppState extends State<ScribbleSongApp> {
  late final router = buildRouter();
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'ScribbleSong',
    theme: buildTheme(),
    routerConfig: router,
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('ScribbleSong')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        Text(
          'A little line.\nA little music.',
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        const Text(
          'Turn your marks into a melody. Start with a blank page and see where it takes you.',
        ),
        const SizedBox(height: 32),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gesture, size: 64, color: accent),
                const SizedBox(height: 20),
                const Text('Make your first loop'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/editor/new'),
                  child: const Text('Start drawing'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
