import 'package:scribblesong/l10n/strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/settings/application/settings_controller.dart';
import '../features/settings/presentation/settings_page.dart';
import '../features/settings/presentation/language_page.dart';
import '../features/onboarding/presentation/tutorial.dart';

import '../design_system/theme.dart';
import '../design_system/system_chrome.dart';
import '../design_system/brand.dart';
import '../design_system/brand_colors.dart';
import '../design_system/creative_dock.dart';
import '../design_system/doodimo_icon.dart';
import '../design_system/immersive_surface.dart';
import '../design_system/artwork_flight.dart';
import '../design_system/graphite_launch.dart';
import '../creative_document/document.dart';

import 'dart:math' as math;

import '../features/home/domain/template_catalog.dart';
import '../design_system/creative_components.dart';
import '../features/editor/presentation/canvas.dart';
import '../features/backgrounds/presentation/background_surface.dart';
import 'providers.dart';
import 'artwork_navigation.dart';
import '../features/editor/presentation/editor.dart';
import '../features/library/presentation/drafts.dart';
import '../features/library/presentation/library_branch_frame.dart';
import '../design_system/retained_transition.dart';

export '../design_system/retained_transition.dart';
import '../features/export_library/presentation/exports_page.dart';
import '../features/home/presentation/templates.dart';

GoRouter buildRouter({bool offerEditorTips = false}) => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute(
      navigatorContainerBuilder: (context, shell, children) =>
          RetainedBranchContainer(
            index: switch (shell.currentIndex) {
              0 => 0,
              3 => 2,
              _ => 1,
            },
            children: [
              children[0],
              LibraryBranchFrame(
                section: switch (shell.currentIndex) {
                  1 => 0,
                  2 => 1,
                  _ => null,
                },
                children: [children[1], children[2]],
              ),
              children[3],
            ],
          ),
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
        loadSessionId:
            state.uri.queryParameters['session'] ?? state.pageKey.value,
        flightIntent: state.extra is ArtworkFlightIntent
            ? state.extra as ArtworkFlightIntent
            : null,
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
    final sideRail =
        MediaQuery.sizeOf(context).height < 440 &&
        MediaQuery.sizeOf(context).width >= 520 &&
        prefersExpandedTextLayout(context);
    var railWidth = 178.0;
    if (sideRail) {
      final style = Theme.of(context).textTheme.labelMedium
          ?.copyWith(fontWeight: FontWeight.w700, height: 1.2);
      for (final label in [
        context.strings.home,
        context.strings.library,
        context.strings.settings,
        context.strings.draw,
      ]) {
        for (final word in label.split(RegExp(r'\s+'))) {
          final painter = TextPainter(
            text: TextSpan(text: word, style: style),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();
          if (painter.width + 78 > railWidth) {
            railWidth = painter.width + 78;
          }
          painter.dispose();
        }
      }
      railWidth = railWidth
          .clamp(178.0, MediaQuery.sizeOf(context).width * .42)
          .toDouble();
    }
    final dock = CreativeDock(
      rail: sideRail,
      compactCreateLabel: context.strings.draw,
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
      onCreate: () => openEditorWithArtworkFlight(context, 'new', null),
      labels: [
        context.strings.home,
        context.strings.library,
        context.strings.settings,
      ],
      createLabel: context.strings.newDrawing,
    );
    return SceneBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: !sideRail,
        body: sideRail
            ? SafeArea(
                minimum: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: railWidth, child: dock),
                    const SizedBox(width: 12),
                    Expanded(child: widget.shell),
                  ],
                ),
              )
            : widget.shell,
        bottomNavigationBar: sideRail
            ? null
            : SafeArea(
                top: false,
                minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: dock,
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
    title: AppBrand.displayName,
    debugShowCheckedModeBanner: false,
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
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: systemChromeFor(Theme.of(context).brightness),
        child: MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
          child: GraphiteLaunch(
            enabled: widget.showWelcome,
            preferencesReady: !ref.watch(
              settingsProvider.select(
                (s) => s.loading || s.error == SettingsFailure.load,
              ),
            ),
            reduceMotion: reduce,
            child: TutorialGate(
              enabled: widget.showWelcome,
              child: child ?? const SizedBox(),
            ),
          ),
        ),
      );
    },
  );
}

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> {
  // Preview identity is retained across theme/visibility/root rebuilds. Editor
  // creation still uses its own independent template document and storage ID.
  late final ProjectDocument _fallbackArtwork = originalTemplates[2].create();
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final large = prefersExpandedTextLayout(context);
    final recent = ref.watch(libraryProvider).asData?.value.projects;
    final saved = recent != null && recent.isNotEmpty;
    final artwork = saved ? recent.first : _fallbackArtwork;
    final destination = saved ? artwork.id : originalTemplates[2].id;
    final create = PrismAction(
      key: const ValueKey('home-start'),
      label: context.strings.startDrawing,
      icon: const DoodimoIcon(DoodimoGlyph.add, color: DoodimoColors.ink),
      onPressed: () => openEditorWithArtworkFlight(context, 'new', null),
    );
    final scene = ArtworkFlightSource(
      routeId: destination,
      document: artwork,
      onOpen: (intent) async {
        await openEditorWithArtworkFlight(context, destination, intent);
      },
      artwork: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: RepaintBoundary(
            key: const ValueKey('home-artwork-paint'),
            child: BackgroundSurface(
              paper: artwork.effectiveBackground,
              maxWidth: 440,
              maxHeight: 550,
              child: CustomPaint(painter: DrawingPainter(artwork)),
            ),
          ),
        ),
      ),
      builder: (context, anchor, open) => LayoutBuilder(
        builder: (context, bounds) {
          final artHeight = math
              .min(
                (bounds.maxWidth - 28) * 1.25,
                MediaQuery.sizeOf(context).height * .45,
              )
              .clamp(180.0, 430.0);
          final caption = Semantics(
            key: const ValueKey('home-continue'),
            button: true,
            label: artwork.title,
            onTap: open,
            child: ImmersiveSurface(
              padding: EdgeInsets.zero,
              radius: 16,
              child: InkWell(
                onTap: open,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              saved
                                  ? context.strings.keepDrawing
                                  : context.strings.tryAStartingPoint,
                              style: type.bodySmall?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              artwork.title,
                              style: type.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      const SizedBox.square(
                        dimension: 48,
                        child: Center(
                          child: DoodimoIcon(DoodimoGlyph.arrowUpRight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          return ImmersiveSurface(
            padding: const EdgeInsets.all(12),
            radius: 26,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (large) ...[create, const SizedBox(height: 16)],
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(4, 0, 4, 12),
                  child: Text(
                    context.strings.drawYourMelody,
                    key: const ValueKey('home-headline'),
                    style: type.titleMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
                Center(
                  child: SizedBox(
                    width: math.min(bounds.maxWidth - 14, artHeight * .8 + 14),
                    child: Semantics(
                      key: const ValueKey('home-artwork'),
                      button: true,
                      label: artwork.title,
                      onTap: open,
                      child: Material(
                        type: MaterialType.transparency,
                        child: InkWell(
                          onTap: open,
                          borderRadius: BorderRadius.circular(18),
                          child: ImmersiveSurface(
                            padding: const EdgeInsets.all(7),
                            radius: 18,
                            child: anchor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                caption,
              ],
            ),
          );
        },
      ),
    );
    return SceneBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: CustomScrollView(
            key: const PageStorageKey('home-scroll'),
            slivers: [
              const SliverPadding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
                sliver: SliverToBoxAdapter(child: StudioHeader()),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: scene,
                      ),
                    ),
                    const TemplateGallery(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
