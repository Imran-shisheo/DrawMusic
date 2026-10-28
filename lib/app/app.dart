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
import '../design_system/aurora_scene.dart';
import '../features/home/domain/template_catalog.dart';
import '../design_system/creative_components.dart';
import '../features/editor/presentation/canvas.dart';
import '../features/backgrounds/presentation/background_surface.dart';
import 'providers.dart';
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
      onCreate: () => context.push('/editor/new'),
      labels: [
        context.strings.home,
        context.strings.library,
        context.strings.settings,
      ],
      createLabel: context.strings.newDrawing,
    );
    return Scaffold(
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
          child: TutorialGate(
            enabled: widget.showWelcome,
            child: child ?? const SizedBox(),
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

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  bool _heroVisible = true, _entered = false;
  final _heroKey = GlobalKey();
  final _auroraKey = GlobalKey(debugLabel: 'home-aurora');
  late final AnimationController _entry = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 720),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _entry.value = 1;
      _entered = true;
    } else if (!_entered) {
      _entered = true;
      _entry.forward();
    }
  }

  @override
  void dispose() {
    _entry.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final large = prefersExpandedTextLayout(context);
    final recent = ref.watch(libraryProvider).asData?.value.projects;
    final saved = recent != null && recent.isNotEmpty;
    final template = originalTemplates[2];
    final artwork = saved ? recent.first : template.create();
    final destination = saved ? artwork.id : template.id;
    final headerText =
        TextPainter(
          text: TextSpan(
            text: AppBrand.displayName,
            style: type.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 2,
        )..layout(
          maxWidth: (MediaQuery.sizeOf(context).width - 142)
              .clamp(1, double.infinity)
              .toDouble(),
        );
    final headerHeight = (headerText.height + 24)
        .clamp(68.0, double.infinity)
        .toDouble();
    headerText.dispose();
    void openArtwork() => context.push('/editor/$destination');
    final create = PrismAction(
      key: const ValueKey('home-start'),
      label: context.strings.startDrawing,
      icon: const DoodimoIcon(DoodimoGlyph.add, color: DoodimoColors.ink),
      onPressed: () => context.push('/editor/new'),
    );
    final preview = Semantics(
      key: const ValueKey('home-artwork'),
      button: true,
      label: artwork.title,
      onTap: openArtwork,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: openArtwork,
          borderRadius: BorderRadius.circular(20),
          child: ImmersiveSurface(
            padding: const EdgeInsets.all(5),
            radius: 18,
            glow: true,
            accent: DoodimoColors.cyan,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 4 / 5,
                child: RepaintBoundary(
                  key: const ValueKey('home-artwork-paint'),
                  child: BackgroundSurface(
                    paper: artwork.effectiveBackground,
                    maxWidth: 320,
                    maxHeight: 400,
                    child: CustomPaint(painter: DrawingPainter(artwork)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    Widget caption(bool flowing) => Semantics(
      key: const ValueKey('home-continue'),
      button: true,
      label: artwork.title,
      onTap: openArtwork,
      child: ImmersiveSurface(
        padding: EdgeInsets.zero,
        radius: 16,
        child: InkWell(
          onTap: openArtwork,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  saved
                      ? context.strings.keepDrawing
                      : context.strings.tryAStartingPoint,
                  maxLines: flowing ? null : 1,
                  overflow: flowing ? null : TextOverflow.ellipsis,
                  style: type.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  artwork.title,
                  maxLines: flowing ? null : 2,
                  overflow: flowing ? null : TextOverflow.ellipsis,
                  style: type.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                DoodimoIcon(
                  DoodimoGlyph.arrowUpRight,
                  color: colors.secondary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    final scene = LayoutBuilder(
      builder: (context, constraints) {
        final headline =
            TextPainter(
              text: TextSpan(
                text: context.strings.aLittleLineALittleMusic,
                style: type.headlineMedium,
              ),
              textDirection: Directionality.of(context),
              textScaler: MediaQuery.textScalerOf(context),
            )..layout(
              maxWidth: (constraints.maxWidth - 44)
                  .clamp(1, double.infinity)
                  .toDouble(),
            );
        // Preserve the floating composition while there is an actual safe gap.
        // A 16dp decorative margin unnecessarily rejected the normal phone
        // heading even though its foreground bounds were disjoint.
        final foregroundWouldOverlap = 24 + headline.height + 4 > 108;
        headline.dispose();
        final flowing =
            large || constraints.maxWidth < 340 || foregroundWouldOverlap;
        return ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? const [Color(0xff171a38), Color(0xff0c1126)]
                    : const [Color(0xffe3e5ff), Color(0xffe7f8ff)],
              ),
              border: Border.all(color: colors.primary.withValues(alpha: .22)),
              borderRadius: BorderRadius.circular(30),
            ),
            child: flowing
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        create,
                        const SizedBox(height: 20),
                        Text(
                          context.strings.drawYourMelody,
                          key: const ValueKey('home-headline'),
                          style: type.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 230,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: TickerMode(
                                  enabled: _heroVisible,
                                  child: AuroraScene(key: _auroraKey),
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerEnd,
                                child: Padding(
                                  padding: const EdgeInsetsDirectional.only(
                                    end: 12,
                                  ),
                                  child: SizedBox(width: 132, child: preview),
                                ),
                              ),
                            ],
                          ),
                        ),
                        caption(true),
                      ],
                    ),
                  )
                : SizedBox(
                    height: 390,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: TickerMode(
                            enabled: _heroVisible,
                            child: AuroraScene(key: _auroraKey),
                          ),
                        ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    colors.surface.withValues(alpha: .94),
                                    colors.surface.withValues(alpha: .82),
                                    colors.surface.withValues(alpha: 0),
                                  ],
                                  stops: const [0, .26, .55],
                                ),
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          start: 22,
                          end: 22,
                          top: 24,
                          child: FadeTransition(
                            opacity: _entry.drive(
                              CurveTween(
                                curve: const Interval(
                                  0,
                                  .65,
                                  curve: Curves.easeOut,
                                ),
                              ),
                            ),
                            child: Text(
                              context.strings.aLittleLineALittleMusic,
                              key: const ValueKey('home-headline'),
                              style: type.headlineMedium?.copyWith(
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: 22,
                          top: 108,
                          child: SizedBox(
                            width: 154,
                            child: AnimatedBuilder(
                              animation: _entry,
                              child: preview,
                              builder: (context, child) => Transform.translate(
                                offset: Offset(
                                  0,
                                  (1 - Curves.easeOut.transform(_entry.value)) *
                                      10,
                                ),
                                child: child,
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          start: 22,
                          end: 176,
                          top: 190,
                          child: caption(false),
                        ),
                        PositionedDirectional(
                          start: 20,
                          end: 20,
                          bottom: 20,
                          child: create,
                        ),
                      ],
                    ),
                  ),
          ),
        );
      },
    );
    return SceneBackdrop(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          toolbarHeight: headerHeight,
          title: Row(
            children: [
              const SketchMark(size: 42),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  AppBrand.displayName,
                  maxLines: 2,
                  style: type.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: context.strings.replayCreationGuide,
              onPressed: () => context.push('/help'),
              icon: const DoodimoIcon(DoodimoGlyph.help),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            if (notification.depth == 0) {
              final box =
                  _heroKey.currentContext?.findRenderObject() as RenderBox?;
              if (box != null && box.hasSize) {
                final visible =
                    box.localToGlobal(Offset(0, box.size.height)).dy >
                    MediaQuery.paddingOf(context).top + headerHeight;
                if (visible != _heroVisible) {
                  setState(() => _heroVisible = visible);
                }
              }
            }
            return false;
          },
          child: CustomScrollView(
            key: const PageStorageKey('home-scroll'),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                sliver: SliverMainAxisGroup(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: KeyedSubtree(key: _heroKey, child: scene),
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
