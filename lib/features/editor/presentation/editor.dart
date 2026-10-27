import 'package:scribblesong/l10n/strings.dart';

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../l10n/operation_messages.dart';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../settings/application/settings_controller.dart';
import '../../../creative_document/document.dart';
import 'accompaniment_panel.dart';
import 'responsive_workspace.dart';
import 'editor_voice_panel.dart';
import 'editor_music_panel.dart';
import 'editor_tools_panel.dart';
import '../../../design_system/motion.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/brand_colors.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../design_system/creative_panel.dart';
import 'studio_control.dart';
import 'instrument_glyph.dart';
import '../../rating/application/rating_provider.dart';
import '../../rating/presentation/rating_offer.dart';
import '../../../design_system/paper_panel.dart';
import '../../../design_system/name_dialog.dart';
import '../../../design_system/style_panel.dart';
import '../../../design_system/repeating_icon_button.dart';
import '../../composition/domain/score.dart';
import '../../export/presentation/export_sheet.dart';
import '../../transport/domain/audio_engine.dart';
import '../../composition/domain/audio_renderer.dart';
import '../application/editor_controller.dart';
import 'canvas.dart';
import '../../onboarding/presentation/editor_tips.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({
    super.key,
    required this.projectId,
    this.offerTips = false,
    this.replayTips = false,
  });
  final bool offerTips, replayTips;
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(openedDocumentProvider(projectId))
      .when(
        loading: () =>
            Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: Text(context.strings.drawingUnavailable)),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context
                      .strings
                      .couldNotOpenThisDrawingTheOriginalFileIsPreserved,
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(openedDocumentProvider(projectId)),
                  child: Text(context.strings.retry),
                ),
                TextButton(
                  onPressed: () => context.go('/drafts'),
                  child: Text(context.strings.backToDrafts),
                ),
              ],
            ),
          ),
        ),
        data: (doc) => ProviderScope(
          overrides: [initialDocumentProvider.overrideWithValue(doc.document)],
          child: EditorWorkspace(
            recovered: doc.recovered,
            offerTips: offerTips,
            replayTips: replayTips,
          ),
        ),
      );
}

class EditorWorkspace extends ConsumerStatefulWidget {
  const EditorWorkspace({
    super.key,
    this.recovered = false,
    this.offerTips = false,
    this.replayTips = false,
  });
  final bool offerTips, replayTips;
  final bool recovered;
  @override
  ConsumerState<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends ConsumerState<EditorWorkspace>
    with WidgetsBindingObserver {
  final _playTarget = GlobalKey(),
      _voiceTarget = GlobalKey(),
      _tempoTarget = GlobalKey(),
      _scaleTarget = GlobalKey();
  bool _tipsOffered = false, _tipsShowing = false;
  Future<void> _showTips() async {
    if (_tipsShowing) return;
    _tipsShowing = true;
    _canvas.currentState?.finish();
    await _pause();
    if (!mounted) return;
    final completed = await showEditorTips(context, [
      EditorTip(
        context.strings.drawAMelody,
        context
            .strings
            .leftToRightFollowsEightBeatsHigherMarksMakeHigherNotesVert,
        _canvas,
      ),
      EditorTip(
        context.strings.listenAndPause,
        context
            .strings
            .playRepeatsYourDrawingTapPauseToKeepYourPlaceOrReplayToSta,
        _playTarget,
      ),
      EditorTip(
        context.strings.chooseAVoice,
        context
            .strings
            .cloudKeysWoodDropsAndGlassStarsAreNamedOriginalInstruments,
        _voiceTarget,
      ),
      EditorTip(
        context.strings.setThePace,
        context
            .strings
            .tapTheBpmNumberForTheTempoSliderHoldMinusOrPlusToRepeatFro,
        _tempoTarget,
      ),
      EditorTip(
        context.strings.keyAndScale,
        context
            .strings
            .thisVersionUsesTheKeyOfCChooseMajorOrMinorPentatonicHereTo,
        _scaleTarget,
      ),
    ]);
    _tipsShowing = false;
    if (completed == true && mounted) {
      final controller = ref.read(settingsProvider.notifier);
      final saved = await controller.save(
        ref
            .read(settingsProvider)
            .preferences
            .copyWith(editorTipsCompleted: true),
      );
      if (!saved && mounted) {
        _message(context.strings.tipsSaveFailed);
      }
    }
  }

  Instrument _instrument = Instrument.keys;
  bool _eraser = false,
      _playing = false,
      _preparing = false,
      _prepared = false,
      _leaving = false,
      _allowPop = false;
  final _cursor = ValueNotifier<double?>(null);
  final _canvas = GlobalKey<DrawingCanvasState>();
  Timer? _poll;
  int _audioGeneration = 0, _renderGeneration = 0;
  int _wantedRevision = -1, _queuedRevision = -1, _heardRevision = -1;
  UpdateBoundary? _pendingBoundary;
  Timer? _updateDebounce;
  bool _pollInFlight = false;
  Future<void>? _updateRenderTask;
  bool _renderLatestAgain = false;
  late final AudioEngine _engine;
  @override
  void initState() {
    super.initState();
    _engine = ref.read(audioEngineProvider);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _audioGeneration++;
    _renderGeneration++;
    _updateDebounce?.cancel();
    unawaited(_engine.stop());
    _cursor.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      _canvas.currentState?.finish();
      unawaited(_pause());
      unawaited(ref.read(editorProvider.notifier).save());
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _pause() async {
    _audioGeneration++;
    _renderGeneration++;
    _updateDebounce?.cancel();
    _poll?.cancel();
    try {
      await ref.read(audioEngineProvider).pause();
    } catch (_) {
      /* No active engine is safe on first launch. */
    }
    if (mounted) setState(() => _playing = false);
  }

  bool get _safeForRating =>
      mounted &&
      !_playing &&
      !_preparing &&
      !_leaving &&
      !_tipsShowing &&
      !_panelShowing &&
      !ref.read(editorProvider).saving &&
      _canvas.currentState?.hasActiveGesture != true &&
      ModalRoute.of(context)?.isCurrent == true;
  Future<void> _offerRating({bool recordTask = false}) async {
    try {
      final coordinator = await ref.read(ratingCoordinatorProvider.future);
      if (recordTask) await coordinator.recordSuccessfulTask();
      await coordinator.offerIfEligible(
        isSafe: () => _safeForRating,
        confirm: () => showRatingOffer(context),
      );
    } catch (_) {
      /* Optional platform review never changes creative task success. */
    }
  }

  Future<void> _explicitSave() async {
    _canvas.currentState?.finish();
    if (await ref.read(editorProvider.notifier).save() && mounted) {
      await _offerRating(recordTask: true);
    }
  }

  void _edit(ProjectDocument next) {
    final previous = ref.read(editorProvider).document;
    if (next.revision <= previous.revision) {
      next = next.copyWith(revision: previous.revision + 1);
    }
    if (ref.read(editorProvider.notifier).commit(next)) {
      _documentChanged(previous, next);
    }
  }

  void _historyEdit({required bool redo}) {
    final previous = ref.read(editorProvider).document;
    final controller = ref.read(editorProvider.notifier);
    if (redo) {
      controller.redo();
    } else {
      controller.undo();
    }
    _documentChanged(previous, ref.read(editorProvider).document);
  }

  void _documentChanged(ProjectDocument previous, ProjectDocument next) {
    final geometry =
        !listEquals(previous.strokes, next.strokes) ||
        previous.scale != next.scale ||
        previous.expressionMode != next.expressionMode ||
        previous.root != next.root ||
        !identical(previous.mix, next.mix);
    final tempo = previous.tempo != next.tempo;
    if (!geometry && !tempo) return;
    _wantedRevision = next.revision;
    _renderGeneration++;
    if (geometry || _pendingBoundary == UpdateBoundary.loop) {
      _pendingBoundary = UpdateBoundary.loop;
    } else {
      _pendingBoundary = UpdateBoundary.beat;
    }
    if (_preparing) {
      _updateDebounce?.cancel();
      return;
    }
    if (!_prepared) {
      _audioGeneration++;
      _cursor.value = null;
      return;
    }
    _updateDebounce?.cancel();
    _updateDebounce = Timer(
      const Duration(milliseconds: 100),
      () => unawaited(_renderAndQueue()),
    );
  }

  Future<void> _renderAndQueue() {
    if (!mounted || !_prepared || _queuedRevision == _wantedRevision) {
      return Future.value();
    }
    final current = _updateRenderTask;
    if (current != null) {
      _renderLatestAgain = true;
      return current;
    }
    final task = _renderQueuedSnapshot().whenComplete(() {
      _updateRenderTask = null;
      final again = _renderLatestAgain;
      _renderLatestAgain = false;
      if (again &&
          mounted &&
          !_preparing &&
          _prepared &&
          _queuedRevision != _wantedRevision) {
        unawaited(_renderAndQueue());
      }
    });
    _updateRenderTask = task;
    return task;
  }

  Future<void> _renderQueuedSnapshot() async {
    final strings = context.strings;
    final generation = ++_renderGeneration;
    final session = _audioGeneration;
    final document = ref.read(editorProvider).document;
    final boundary = _pendingBoundary ?? UpdateBoundary.loop;
    final revision = _wantedRevision;
    try {
      final pcm = await compute(_renderLoop, document);
      if (!mounted ||
          generation != _renderGeneration ||
          session != _audioGeneration ||
          !_prepared) {
        return;
      }
      await _engine.queue(
        pcm,
        revision: revision,
        tempo: document.tempo,
        boundary: boundary,
      );
      if (mounted && generation == _renderGeneration) {
        _queuedRevision = revision;
      }
    } catch (error) {
      if (mounted && generation == _renderGeneration) {
        await _pause();
        _prepared = false;
        _message(playbackFailureMessage(strings, error, updating: true));
      }
    }
  }

  Future<void> _play({bool replay = false}) async {
    final strings = context.strings;
    if (_preparing) return;
    _canvas.currentState?.finish();
    if (_playing && !replay) {
      await _pause();
      return;
    }
    final token = ++_audioGeneration;
    _renderGeneration++;
    _renderLatestAgain = false;
    _updateDebounce?.cancel();
    _poll?.cancel();
    setState(() {
      _preparing = true;
      _playing = false;
    });
    try {
      final engine = ref.read(audioEngineProvider);
      if (!_prepared || replay) {
        _prepared = false;
        _cursor.value = null;
        await engine.pause();
        final update = _updateRenderTask;
        if (update != null) await update;
        while (mounted && token == _audioGeneration) {
          final document = ref.read(editorProvider).document;
          final pcm = await compute(_renderNonemptyLoop, document);
          if (pcm == null) return;
          if (!mounted || token != _audioGeneration) return;
          if (document.revision != ref.read(editorProvider).document.revision) {
            continue;
          }
          await engine.prepare(
            pcm,
            revision: document.revision,
            tempo: document.tempo,
          );
          if (!mounted || token != _audioGeneration) {
            await engine.stop();
            _prepared = false;
            return;
          }
          if (document.revision != ref.read(editorProvider).document.revision) {
            continue;
          }
          _prepared = true;
          _wantedRevision = _queuedRevision = _heardRevision =
              document.revision;
          _pendingBoundary = null;
          break;
        }
      } else {
        while (mounted &&
            token == _audioGeneration &&
            _wantedRevision != _queuedRevision) {
          await _renderAndQueue();
        }
      }
      if (!mounted || token != _audioGeneration || !_prepared) return;
      await engine.setVolume(
        ref.read(settingsProvider).preferences.previewVolume,
      );
      await engine.play();
      if (!mounted || token != _audioGeneration) {
        await engine.pause();
        return;
      }
      setState(() => _playing = true);
      _poll = Timer.periodic(const Duration(milliseconds: 50), (_) async {
        if (_pollInFlight) return;
        _pollInFlight = true;
        try {
          final status = await engine.status();
          if (!mounted || token != _audioGeneration || !_playing) return;
          if (!status.playing) {
            await _pause();
            return;
          }
          _cursor.value = status.fraction;
          if (_heardRevision != status.revision) {
            setState(() {
              _heardRevision = status.revision;
              if (_heardRevision == _wantedRevision) _pendingBoundary = null;
            });
          }
        } catch (error) {
          if (mounted && token == _audioGeneration) {
            await _pause();
            _prepared = false;
            _message(strings.playbackStopped);
          }
        } finally {
          _pollInFlight = false;
        }
      });
    } catch (error) {
      _prepared = false;
      _message(playbackFailureMessage(strings, error));
    } finally {
      if (mounted) {
        setState(() => _preparing = false);
        if (_playing && _prepared && _wantedRevision != _queuedRevision) {
          _updateDebounce?.cancel();
          _updateDebounce = Timer(
            const Duration(milliseconds: 100),
            () => unawaited(_renderAndQueue()),
          );
        }
      }
    }
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _canvas.currentState?.finish();
    await _pause();
    if (!mounted) return;
    setState(() => _leaving = true);
    final saved = await ref.read(editorProvider.notifier).save();
    if (!mounted) return;
    setState(() => _leaving = false);
    if (saved) {
      setState(() => _allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/drafts');
      }
    } else {
      _message(context.strings.leaveSaveFailed);
    }
  }

  void _selectionFeedback() {
    if (ref.read(settingsProvider).preferences.haptics) {
      unawaited(HapticFeedback.selectionClick());
    }
  }

  void _changeTempo(int delta) {
    final document = ref.read(editorProvider).document;
    final tempo = (document.tempo + delta).clamp(60, 200);
    if (tempo != document.tempo) {
      _selectionFeedback();
      _edit(document.copyWith(tempo: tempo));
    }
  }

  bool _panelShowing = false;

  Future<void> _chooseVoice() async {
    if (_panelShowing) return;
    _panelShowing = true;
    _canvas.currentState?.finish();
    try {
      final chosen = await showEditorVoicePanel(context, _instrument);
      if (chosen != null && mounted) {
        _selectionFeedback();
        setState(() {
          _instrument = chosen;
          _eraser = false;
        });
      }
    } finally {
      _panelShowing = false;
    }
  }

  Future<void> _musicSettings() async {
    if (_panelShowing) return;
    _panelShowing = true;
    _canvas.currentState?.finish();
    try {
      final chosen = await showEditorMusicPanel(
        context,
        ref.read(editorProvider).document,
      );
      if (chosen != null && mounted) {
        _edit(
          ref
              .read(editorProvider)
              .document
              .copyWith(
                tempo: chosen.tempo,
                root: chosen.rootChanged ? chosen.root : null,
                scale: chosen.scaleChanged ? chosen.scale : null,
                expressionMode: chosen.expression,
                mix: chosen.mix,
              ),
        );
      }
    } finally {
      _panelShowing = false;
    }
  }

  Future<void> _tools() async {
    if (_panelShowing) return;
    _panelShowing = true;
    _canvas.currentState?.finish();
    try {
      final action = await showEditorToolsPanel(
        context,
        ref.read(editorProvider).document,
      );
      if (!mounted || action == null) return;
      switch (action) {
        case EditorToolAction.paper:
          await _background();
        case EditorToolAction.style:
          await _drawingStyle();
        case EditorToolAction.mix:
          final mix = await showAccompanimentPanel(
            context,
            ref.read(editorProvider).document.mix,
          );
          if (mix != null && mounted) {
            _edit(ref.read(editorProvider).document.copyWith(mix: mix));
          }
        case EditorToolAction.score:
          await _describe();
        case EditorToolAction.clear:
          await _clear();
        case EditorToolAction.tips:
          await _showTips();
      }
    } finally {
      _panelShowing = false;
    }
  }

  Future<void> _rename() async {
    final value = await askDrawingName(
      context,
      ref.read(editorProvider).document.title,
    );
    if (value != null && mounted) {
      _edit(ref.read(editorProvider).document.copyWith(title: value));
    }
  }

  Future<void> _drawingStyle() async {
    _canvas.currentState?.finish();
    final value = await showStylePanel(
      context,
      ref.read(editorProvider).document.style,
    );
    if (value != null && mounted) {
      _edit(ref.read(editorProvider).document.copyWith(style: value));
      if (mounted) {
        await SemanticsService.sendAnnouncement(
          View.of(context),
          value == DrawingStyle.smooth
              ? context.strings.smoothStyleSelected
              : context.strings.pixelStyleSelected,
          Directionality.of(context),
        );
      }
    }
  }

  Future<void> _background() async {
    _canvas.currentState?.finish();
    final value = await showBackgroundPanel(
      context,
      ref.read(editorProvider).document.effectiveBackground,
    );
    if (value != null && mounted) {
      _edit(ref.read(editorProvider).document.copyWith(paper: value));
    }
  }

  bool _describing = false;
  Future<void> _describe() async {
    if (_describing) return;
    setState(() => _describing = true);
    try {
      final doc = ref.read(editorProvider).document;
      final score = await compute(compileScore, doc);
      if (!mounted) return;
      await showCreativePanel<void>(
        context: context,
        builder: (context) => CreativePanel(
          title: context.strings.yourLoopInNotes,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strings.close),
            ),
          ],
          child: ImmersiveSurface(
            accent: DoodimoColors.cyan,
            child: SelectionArea(
              child: Text(
                '${context.strings.scoreSummary(doc.root.label, context.formatNumber(score.notes.length), context.formatNumber(doc.tempo), scaleName(context, doc.scale))}\n\n${score.notes.take(80).map((n) => context.strings.scoreEvent(n.percussion ? switch (n.pitch) {
                        36 => context.strings.kick,
                        38 => context.strings.snare,
                        39 => context.strings.clap,
                        _ => context.strings.hiHat,
                      } : instrumentName(context, n.instrument), context.formatNumber(n.pitch), context.formatDecimal(n.startBeat + 1), context.formatDecimal(n.durationBeat))).join('\n')}${score.notes.length > 80 ? '\n${context.strings.showingFirst80Events}' : ''}',
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _message(
          e is ScoreComplexityException
              ? context.strings.scoreTooComplex
              : context.strings.scoreDescriptionFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _describing = false);
    }
  }

  Future<void> _clear() async {
    final yes = await showCreativePanel<bool>(
      context: context,
      builder: (context) => CreativePanel(
        title: context.strings.clearThisDrawing,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.strings.keepDrawing),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.strings.clear),
          ),
        ],
        child: ImmersiveSurface(
          accent: DoodimoColors.pink,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const DoodimoIcon(DoodimoGlyph.erase, size: 36),
              const SizedBox(height: 16),
              Text(context.strings.youCanRestoreItWithUndo),
            ],
          ),
        ),
      ),
    );
    if (yes == true && mounted) {
      _edit(ref.read(editorProvider).document.copyWith(strokes: []));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(editorProvider), doc = state.document;
    final controller = ref.read(editorProvider.notifier);
    final preferences = ref.watch(settingsProvider);
    if (!_tipsOffered &&
        !preferences.loading &&
        !preferences.saving &&
        (widget.replayTips ||
            (widget.offerTips &&
                !preferences.preferences.editorTipsCompleted))) {
      _tipsOffered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ModalRoute.of(context)?.isCurrent == true) {
          unawaited(_showTips());
        }
      });
    }
    ref.listen(
      repositoryProvider,
      (_, next) => next.whenData(controller.attachRepository),
    );
    final repo = ref.watch(repositoryProvider);
    repo.whenData((repository) {
      if (!state.saving && state.savedRevision < 0 && state.error == null) {
        Future.microtask(
          () => mounted ? controller.attachRepository(repository) : null,
        );
      }
    });
    final colors = Theme.of(context).colorScheme;
    final type = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context);
    final largeText = textScale.scale(14) > 21;
    final media = MediaQuery.of(context);
    final viewport = media.size;
    final bodyWidth =
        viewport.width -
        math.max(media.padding.left, media.viewPadding.left) -
        math.max(media.padding.right, media.viewPadding.right) -
        32;
    final bodyHeight =
        viewport.height -
        media.viewPadding.vertical -
        (largeText ? 160 : 64) -
        10;
    final rail = bodyWidth >= 900 || (bodyWidth >= 520 && bodyHeight < 440);
    final paletteWidth = rail
        ? (bodyHeight < 440 ? 330.0 : 304.0) - 4
        : bodyWidth;
    final modeStyle = type.labelLarge?.copyWith(fontWeight: FontWeight.w600);
    final drawMetrics = _labelWordMetrics(
      context,
      context.strings.draw,
      modeStyle,
    );
    final eraseMetrics = _labelWordMetrics(
      context,
      context.strings.erase,
      modeStyle,
    );
    final twoColumnTextWidth =
        (paletteWidth - (largeText ? 0 : 104) - 20) / 2 -
        20 -
        (!largeText && viewport.width >= 380 ? 24 : 0);
    final stackModes =
        math.max(drawMetrics.width, eraseMetrics.width) > twoColumnTextWidth;
    final stackedToolbarHeight = stackModes
        ? 2.0 *
                  math.max(
                    48.0,
                    math.max(drawMetrics.height, eraseMetrics.height) + 20,
                  ) +
              20
        : 0.0;
    final fullWidthTools =
        _labelWordMetrics(
              context,
              context.strings.editorToolsShort,
              type.labelLarge,
            ).width +
            50 >
        paletteWidth - 96;
    final saveStatus = state.saving
        ? context.strings.saving
        : state.dirty
        ? context.strings.changesPending
        : context.strings.savedOnThisDevice;
    final hasMusic = doc.strokes.isNotEmpty || doc.mix.isActive;
    final pending = _prepared && _wantedRevision != _heardRevision;
    final pendingStatus = pending
        ? (_pendingBoundary == UpdateBoundary.beat
              ? context.strings.updatesNextBeat
              : context.strings.updatesNextLoop)
        : (!hasMusic ? context.strings.drawSomethingToHearIt : '');

    final dark = Theme.of(context).brightness == Brightness.dark;
    final showModeGlyph = !largeText && MediaQuery.sizeOf(context).width >= 380;
    final toolbar = ImmersiveSurface(
      padding: const EdgeInsets.all(4),
      radius: 22,
      accent: DoodimoColors.cyan,
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Flex(
                  direction: stackModes ? Axis.vertical : Axis.horizontal,
                  crossAxisAlignment: stackModes
                      ? CrossAxisAlignment.stretch
                      : CrossAxisAlignment.center,
                  children: [
                    _ModeSlot(
                      stacked: stackModes,
                      child: _EditorModeButton(
                        label: context.strings.draw,
                        glyph: DoodimoGlyph.draw,
                        showGlyph: showModeGlyph,
                        selected: !_eraser,
                        onPressed: () {
                          _canvas.currentState?.finish();
                          setState(() => _eraser = false);
                        },
                      ),
                    ),
                    SizedBox(
                      width: stackModes ? 0 : 4,
                      height: stackModes ? 4 : 0,
                    ),
                    _ModeSlot(
                      stacked: stackModes,
                      child: _EditorModeButton(
                        label: context.strings.erase,
                        glyph: DoodimoGlyph.erase,
                        showGlyph: showModeGlyph,
                        selected: _eraser,
                        onPressed: () {
                          _canvas.currentState?.finish();
                          setState(() => _eraser = true);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!largeText) ...[
            const SizedBox(width: 8),
            IconButton(
              tooltip: context.strings.undo,
              onPressed: controller.canUndo
                  ? () => _historyEdit(redo: false)
                  : null,
              icon: const DoodimoIcon(DoodimoGlyph.undo),
            ),
            IconButton(
              tooltip: context.strings.redo,
              onPressed: controller.canRedo
                  ? () => _historyEdit(redo: true)
                  : null,
              icon: const DoodimoIcon(DoodimoGlyph.redo),
            ),
          ],
        ],
      ),
    );
    final voice = StudioControl(
      key: _voiceTarget,
      interactionKey: const ValueKey('current-voice'),
      label:
          '${context.strings.chooseAVoice}: ${instrumentName(context, _instrument)}',
      onPressed: _chooseVoice,
      fill: Colors.transparent,
      foreground: colors.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      radius: 22,
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: instrumentColors[_instrument.index],
                  width: 3,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: InstrumentGlyph(_instrument, size: largeText ? 32 : 42),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              instrumentName(context, _instrument),
              style: type.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 6),
          const DoodimoIcon(DoodimoGlyph.chevronDown, size: 18),
        ],
      ),
    );
    final summary = LayoutBuilder(
      builder: (context, constraints) {
        if (!largeText && constraints.maxWidth < 200) {
          return StudioControl(
            key: const ValueKey('music-settings'),
            label:
                '${context.strings.musicSettings}: ${context.strings.tempoValue(context.formatNumber(doc.tempo))}, ${doc.root.label} ${scaleName(context, doc.scale)}',
            onPressed: _musicSettings,
            fill: Colors.transparent,
            foreground: colors.onSurface,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    key: _scaleTarget,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.strings.tempoValue(context.formatNumber(doc.tempo))} · ${doc.root.label} ${scaleName(context, doc.scale)}',
                        key: _tempoTarget,
                        style: type.labelMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const DoodimoIcon(DoodimoGlyph.chevronDown, size: 18),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              if (!largeText)
                RepeatingIconButton(
                  tooltip: context.strings.slower,
                  onStep: doc.tempo > 60 ? () => _changeTempo(-1) : null,
                  icon: Icons.remove_rounded,
                ),
              Expanded(
                child: StudioControl(
                  key: const ValueKey('music-settings'),
                  label:
                      '${context.strings.musicSettings}: ${context.strings.tempoValue(context.formatNumber(doc.tempo))}, ${doc.root.label} ${scaleName(context, doc.scale)}',
                  onPressed: _musicSettings,
                  fill: Colors.transparent,
                  foreground: colors.onSurface,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                  radius: 16,
                  child: Row(
                    children: [
                      if (largeText)
                        Expanded(
                          key: _scaleTarget,
                          child: Text(
                            '${context.strings.tempoValue(context.formatNumber(doc.tempo))} · ${doc.root.label} ${scaleName(context, doc.scale)}',
                            key: _tempoTarget,
                            style: type.labelMedium?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        )
                      else ...[
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.strings.tempoValue(
                                  context.formatNumber(doc.tempo),
                                ),
                                key: _tempoTarget,
                                style: type.labelLarge?.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                              Text(
                                '${doc.root.label} ${scaleName(context, doc.scale)}',
                                key: _scaleTarget,
                                style: type.labelSmall?.copyWith(
                                  color: colors.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        DoodimoIcon(
                          DoodimoGlyph.chevronDown,
                          color: colors.onSurface,
                          size: 18,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (!largeText)
                RepeatingIconButton(
                  tooltip: context.strings.faster,
                  onStep: doc.tempo < 200 ? () => _changeTempo(1) : null,
                  icon: Icons.add_rounded,
                ),
            ],
          ),
        );
      },
    );
    final play = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasMusic
              ? const [Color(0xffb9a1ff), Color(0xff71e2f5)]
              : const [Color(0xff606d94), Color(0xff46577e)],
        ),
        border: Border.all(
          color: const Color(0xffd1d9ff).withValues(alpha: .7),
        ),
        boxShadow: hasMusic
            ? [
                BoxShadow(
                  color: DoodimoColors.violet.withValues(
                    alpha: dark ? .24 : .12,
                  ),
                  blurRadius: 22,
                  offset: const Offset(0, 6),
                ),
              ]
            : const [],
      ),
      child: SizedBox.square(
        dimension: 72,
        child: IconButton(
          key: _playTarget,
          style: IconButton.styleFrom(
            foregroundColor: DoodimoColors.ink,
            disabledForegroundColor: const Color(0xffd6def6),
          ),
          tooltip: _playing ? context.strings.pause : context.strings.play,
          onPressed: (!_playing && !hasMusic) || _preparing
              ? null
              : () => _play(),
          icon: SizedBox.square(
            dimension: 32,
            child: _preparing
                ? const Padding(
                    padding: EdgeInsets.all(3),
                    child: CircularProgressIndicator(
                      color: DoodimoColors.ink,
                      strokeWidth: 2.5,
                    ),
                  )
                : AnimatedSwitcher(
                    duration: CreativeMotion.duration(
                      context,
                      CreativeMotion.selection,
                    ),
                    child: DoodimoIcon(
                      _playing ? DoodimoGlyph.pause : DoodimoGlyph.play,
                      key: ValueKey(_playing),
                      size: 32,
                      color: hasMusic
                          ? DoodimoColors.ink
                          : const Color(0xffd6def6),
                    ),
                  ),
          ),
        ),
      ),
    );
    final replay = IconButton(
      tooltip: context.strings.replay,
      onPressed: hasMusic ? () => _play(replay: true) : null,
      icon: const DoodimoIcon(DoodimoGlyph.replay),
    );
    final tools = StudioControl(
      interactionKey: const ValueKey('editor-tools'),
      label: context.strings.editorTools,
      onPressed: _tools,
      fill: colors.surfaceContainerHighest,
      foreground: colors.onSurface,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DoodimoIcon(DoodimoGlyph.more, size: 20),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              context.strings.editorToolsShort,
              style: type.labelLarge,
            ),
          ),
        ],
      ),
    );
    final history = <Widget>[
      if (largeText) ...[
        IconButton(
          tooltip: context.strings.undo,
          onPressed: controller.canUndo
              ? () => _historyEdit(redo: false)
              : null,
          icon: const DoodimoIcon(DoodimoGlyph.undo),
        ),
        IconButton(
          tooltip: context.strings.redo,
          onPressed: controller.canRedo ? () => _historyEdit(redo: true) : null,
          icon: const DoodimoIcon(DoodimoGlyph.redo),
        ),
      ],
      replay,
    ];
    final compactDeck =
        largeText || viewport.width < 380 || viewport.width >= 900;
    final transport = ImmersiveSurface(
      key: const ValueKey('editor-instrument-console'),
      padding: const EdgeInsets.all(8),
      radius: 28,
      accent: DoodimoColors.violet,
      glow: true,
      child: compactDeck
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                voice,
                const SizedBox(height: 4),
                Row(
                  children: [
                    play,
                    const SizedBox(width: 8),
                    Expanded(
                      child: Wrap(
                        alignment: WrapAlignment.end,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 4,
                        runSpacing: 4,
                        children: [...history, if (!fullWidthTools) tools],
                      ),
                    ),
                  ],
                ),
                if (fullWidthTools) ...[const SizedBox(height: 4), tools],
                const SizedBox(height: 4),
                summary,
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: voice),
                    const SizedBox(width: 4),
                    tools,
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    play,
                    const SizedBox(width: 8),
                    Expanded(child: summary),
                    replay,
                  ],
                ),
              ],
            ),
    );
    final alerts = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (doc.hasCompatibilityFallbacks)
          Text(context.strings.compatibilityFallback),
        if (widget.recovered)
          Text(
            context
                .strings
                .recoveredThePreviousCompleteRevisionTheDamagedFileIsPreser,
          ),
        if (repo.hasError)
          Text(
            context.strings.storageUnavailableRetryFromDraftsBeforeLeaving,
            style: TextStyle(color: colors.error),
          ),
        if (state.error != null)
          TextButton(
            onPressed: () => controller.save(),
            child: Text(context.strings.drawingSaveRetry),
          ),
      ],
    );
    final canvas = Center(
      child: AspectRatio(
        aspectRatio: .8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: DoodimoColors.violet.withValues(alpha: dark ? .13 : .07),
                blurRadius: 20,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: DrawingCanvas(
            key: _canvas,
            document: doc,
            instrument: _instrument,
            eraser: _eraser,
            cursor: _cursor,
            onCommit: (strokes) => _edit(
              ref.read(editorProvider).document.copyWith(strokes: strokes),
            ),
            onSimplified: (before, after) =>
                _message(context.strings.geometrySimplified),
            onLimit: () => _message(context.strings.drawingPointLimit),
            onEraseRejected: () =>
                _message(context.strings.erasureLimitRejected),
          ),
        ),
      ),
    );
    final exportAction = Tooltip(
      message: context.strings.exportLoop,
      child: TextButton.icon(
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(48, 48),
        ),
        label: Text(
          context.strings.exportLoop,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: type.labelLarge?.copyWith(height: 1.15),
        ),
        onPressed: () async {
          _canvas.currentState?.finish();
          await _pause();
          if (context.mounted) {
            await showExportSheet(context, ref.read(editorProvider).document);
            if (mounted) await _offerRating();
          }
        },
        icon: const DoodimoIcon(DoodimoGlyph.export),
      ),
    );
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: textScale.scale(14) > 21 ? 80 : 64,
          leading: IconButton(
            tooltip: context.strings.backToGallery,
            onPressed: _leaving ? null : _leave,
            icon: const DoodimoIcon(DoodimoGlyph.back),
          ),
          titleSpacing: 0,
          bottom: largeText
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(80),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: exportAction,
                    ),
                  ),
                )
              : null,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                button: true,
                label: context.strings.renameDrawingLabel(doc.title),
                onTap: _rename,
                child: ExcludeSemantics(
                  child: InkWell(
                    onTap: _rename,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          doc.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: type.titleMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                pending ? pendingStatus : saveStatus,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: type.labelSmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              tooltip: context.strings.saveDrawing,
              onPressed: state.saving ? null : _explicitSave,
              icon: const DoodimoIcon(DoodimoGlyph.save),
            ),
            if (!largeText) exportAction,
          ],
        ),
        body: SceneBackdrop(
          child: SafeArea(
            minimum: EdgeInsets.only(
              left: MediaQuery.viewPaddingOf(context).left,
              right: MediaQuery.viewPaddingOf(context).right,
              bottom: MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: ResponsiveEditorLayout(
                toolbar: toolbar,
                toolbarNaturalHeight: stackedToolbarHeight,
                summary: const SizedBox.shrink(),
                transport: transport,
                canvas: canvas,
                alerts: alerts,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Size _labelWordMetrics(BuildContext context, String label, TextStyle? style) {
  var width = 0.0, height = 0.0;
  for (final word
      in label.split(RegExp(r'\s+')).where((word) => word.isNotEmpty)) {
    final painter = TextPainter(
      text: TextSpan(text: word, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout();
    width = math.max(width, painter.width);
    height = math.max(height, painter.height);
    painter.dispose();
  }
  return Size(width, height);
}

class _ModeSlot extends StatelessWidget {
  const _ModeSlot({required this.stacked, required this.child});
  final bool stacked;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      stacked ? child : Expanded(child: child);
}

class _EditorModeButton extends StatelessWidget {
  const _EditorModeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.glyph,
    required this.showGlyph,
  });
  final String label;
  final bool selected, showGlyph;
  final VoidCallback onPressed;
  final DoodimoGlyph glyph;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StudioControl(
      label: label,
      selected: selected,
      onPressed: onPressed,
      fill: selected ? colors.primary : Colors.transparent,
      foreground: selected ? colors.onPrimary : colors.onSurface,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (showGlyph) ...[
            DoodimoIcon(
              glyph,
              size: 18,
              color: selected ? colors.onPrimary : colors.onSurface,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? colors.onPrimary : colors.onSurface,
                fontWeight: FontWeight.w600,
                decoration: selected
                    ? TextDecoration.underline
                    : TextDecoration.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Compile geometry and synthesize away from the UI isolate, from one immutable
// document. Top-level callbacks avoid capturing widget/native state.
Int16List _renderLoop(ProjectDocument document) =>
    renderPcm(compileScore(document), loop: true);
Int16List? _renderNonemptyLoop(ProjectDocument document) {
  final score = compileScore(document);
  return score.notes.isEmpty ? null : renderPcm(score, loop: true);
}
