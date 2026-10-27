import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_controller.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/language_page.dart';
import '../features/onboarding/presentation/tutorial.dart';

import '../design_system/theme.dart';
import '../features/editor/presentation/editor.dart';
import '../features/library/presentation/drafts.dart';
import '../features/export_library/presentation/exports_page.dart';
import '../features/home/presentation/templates.dart';

GoRouter buildRouter({bool offerEditorTips = false}) => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => _RootTabs(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/home', builder: (_, _) => const HomePage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/drafts', builder: (_, _) => const DraftsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/exports', builder: (_, _) => const ExportsPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/settings', builder: (_, _) => const SettingsPage()),
          ],
        ),
      ],
    ),
    GoRoute(path: '/language', builder: (_, _) => const LanguagePage()),
    GoRoute(path: '/help', builder: (_, _) => const TutorialPage()),
    GoRoute(
      path: '/editor/:id',
      builder: (_, state) => EditorPage(
        projectId: state.pathParameters['id']!,
        offerTips: offerEditorTips,
        replayTips: state.uri.queryParameters['tips'] == '1',
      ),
    ),
  ],
  errorBuilder: (context, _) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => context.go('/home'),
        child: Text(context.strings.pageUnavailableReturnHome),
      ),
    ),
  ),
);

// Each library section retains its own navigator and scroll state. The bottom
// Library destination returns to the last section rather than always Drafts.
class _RootTabs extends StatefulWidget {
  const _RootTabs({required this.shell});
  final StatefulNavigationShell shell;
  @override
  State<_RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<_RootTabs> {
  int _libraryIndex = 1;
  @override
  Widget build(BuildContext context) {
    final index = widget.shell.currentIndex;
    if (index == 1 || index == 2) _libraryIndex = index;
    return Scaffold(
      body: widget.shell,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/editor/new'),
        icon: const Icon(Icons.add),
        label: Text(context.strings.newDrawing),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: NavigationBar(
            selectedIndex: index == 0
                ? 0
                : index == 3
                ? 2
                : 1,
            onDestinationSelected: (destination) =>
                widget.shell.goBranch(switch (destination) {
                  0 => 0,
                  1 => _libraryIndex,
                  _ => 3,
                }),
            destinations: [
              NavigationDestination(
                icon: Icon(Icons.grid_view_rounded),
                label: context.strings.home,
              ),
              NavigationDestination(
                icon: Icon(Icons.folder_outlined),
                label: context.strings.library,
              ),
              NavigationDestination(
                icon: Icon(Icons.tune),
                label: context.strings.settings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ScribbleSongApp extends ConsumerStatefulWidget {
  const ScribbleSongApp({super.key, this.showWelcome = false});
  final bool showWelcome;
  @override
  ConsumerState<ScribbleSongApp> createState() => _ScribbleSongAppState();
}

class _ScribbleSongAppState extends ConsumerState<ScribbleSongApp> {
  late final router = buildRouter(offerEditorTips: widget.showWelcome);
  @override
  void dispose() {
    router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'ScribbleSong',
    locale: Locale(
      ref.watch(
        settingsProvider.select((state) => state.preferences.languageCode),
      ),
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    theme: buildTheme(),
    darkTheme: buildTheme(brightness: Brightness.dark),
    themeMode:
        ref.watch(settingsProvider.select((s) => s.preferences.darkTheme))
        ? ThemeMode.dark
        : ThemeMode.light,
    routerConfig: router,
    builder: (context, child) {
      final reduce =
          ref.watch(
            settingsProvider.select((state) => state.preferences.reduceMotion),
          ) ||
          MediaQuery.disableAnimationsOf(context);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: TutorialGate(
          enabled: widget.showWelcome,
          child: child ?? const SizedBox(),
        ),
      );
    },
  );
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(context.strings.scribblesong)),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      children: [
        Text(
          context.strings.aLittleLineALittleMusic,
          style: Theme.of(context).textTheme.headlineLarge
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 16),
        Text(
          context
              .strings
              .turnYourMarksIntoAMelodyStartWithABlankPageAndSeeWhereItTa,
        ),
        const SizedBox(height: 32),
        const TemplateGallery(),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.gesture, size: 64, color: accent),
                const SizedBox(height: 20),
                Text(context.strings.makeYourFirstLoop),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => context.push('/editor/new'),
                  child: Text(context.strings.startDrawing),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
