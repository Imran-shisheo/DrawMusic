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
import '../../../design_system/artwork_flight.dart';
import '../../../design_system/doodimo_icon.dart';
import '../../../design_system/brand_colors.dart';
import '../../../design_system/immersive_surface.dart';
import '../../../design_system/creative_panel.dart';
import 'studio_control.dart';
import '../../rating/application/rating_provider.dart';
import '../../rating/presentation/rating_offer.dart';
import '../../../design_system/paper_panel.dart';
import '../../../design_system/name_dialog.dart';
import '../../../design_system/style_panel.dart';
import '../../composition/domain/score.dart';
import '../../export/presentation/export_sheet.dart';
import '../../transport/domain/audio_engine.dart';
import '../../composition/domain/audio_renderer.dart';
import '../application/editor_controller.dart';
import 'canvas.dart';
import '../../onboarding/presentation/editor_tips.dart';

// The provider shares one platform adapter across retained/overlapping routes.
// A fading workspace must never tear down or command its successor's session.
final _editorEngineOwners = Expando<Object>('editor-audio-owner');

class EditorPage extends ConsumerWidget {
  const EditorPage({
    super.key,
    required this.projectId,
    this.offerTips = false,
    this.replayTips = false,
    this.flightIntent,
    this.loadSessionId,
  });
  final bool offerTips, replayTips;
  final ArtworkFlightIntent? flightIntent;
  final String? loadSessionId;
  final String projectId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = loadSessionId == null
        ? openedDocumentProvider(projectId)
        : editorLoadProvider(
            EditorLoadRequest(projectId: projectId, sessionId: loadSessionId!),
          );
    return ref
        .watch(provider)
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
                    onPressed: () => ref.invalidate(provider),
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
            overrides: [
              initialDocumentProvider.overrideWithValue(doc.document),
            ],
            child: EditorWorkspace(
              recovered: doc.recovered,
              offerTips: offerTips,
              replayTips: replayTips,
              flightIntent: flightIntent,
            ),
          ),
        );
  }
}

class EditorWorkspace extends ConsumerStatefulWidget {
  const EditorWorkspace({
    super.key,
    this.recovered = false,
    this.offerTips = false,
    this.replayTips = false,
    this.flightIntent,
  });
  final bool offerTips, replayTips;
  final ArtworkFlightIntent? flightIntent;
  final bool recovered;
  @override
  ConsumerState<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends ConsumerState<EditorWorkspace>
    with WidgetsBindingObserver {
  final _toolsTarget = GlobalKey(), _backgroundTarget = GlobalKey();
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
  final Object _engineOwnerToken = Object();
  bool get _ownsEngine => _editorEngineOwners[_engine] == _engineOwnerToken;
  bool _audioSessionCurrent(int token) =>
      mounted && _ownsEngine && token == _audioGeneration;
  @override
  void initState() {
    super.initState();
    _engine = ref.read(audioEngineProvider);
    _editorEngineOwners[_engine] = _engineOwnerToken;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _audioGeneration++;
    _renderGeneration++;
    _updateDebounce?.cancel();
    if (_ownsEngine) {
      _editorEngineOwners[_engine] = null;
      unawaited(_engine.stop());
    }
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
      if (_ownsEngine) await _engine.pause();
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
    if (!mounted ||
        !_ownsEngine ||
        !_prepared ||
        _queuedRevision == _wantedRevision) {
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
          _ownsEngine &&
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
          !_ownsEngine ||
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
      if (mounted && _ownsEngine && generation == _renderGeneration) {
        _queuedRevision = revision;
      }
    } catch (error) {
      if (mounted && _ownsEngine && generation == _renderGeneration) {
        await _pause();
        _prepared = false;
        _message(playbackFailureMessage(strings, error, updating: true));
      }
    }
  }

  Future<void> _play({bool replay = false}) async {
    final strings = context.strings;
    if (_preparing || !_ownsEngine) return;
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
      final engine = _engine;
      if (!_prepared || replay) {
        _prepared = false;
        _cursor.value = null;
        await engine.pause();
        if (!_audioSessionCurrent(token)) return;
        final update = _updateRenderTask;
        if (update != null) await update;
        while (_audioSessionCurrent(token)) {
          final document = ref.read(editorProvider).document;
          final pcm = await compute(_renderNonemptyLoop, document);
          if (pcm == null) return;
          if (!_audioSessionCurrent(token)) return;
          if (document.revision != ref.read(editorProvider).document.revision) {
            continue;
          }
          await engine.prepare(
            pcm,
            revision: document.revision,
            tempo: document.tempo,
          );
          if (!_audioSessionCurrent(token)) {
            if (_ownsEngine) await engine.stop();
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
        while (_audioSessionCurrent(token) &&
            _wantedRevision != _queuedRevision) {
          await _renderAndQueue();
        }
      }
      if (!_audioSessionCurrent(token) || !_prepared) return;
      await engine.setVolume(
        ref.read(settingsProvider).preferences.previewVolume,
      );
      if (!_audioSessionCurrent(token)) return;
      await engine.play();
      if (!_audioSessionCurrent(token)) {
        if (_ownsEngine) await engine.pause();
        return;
      }
      setState(() => _playing = true);
      _poll = Timer.periodic(const Duration(milliseconds: 50), (_) async {
        if (!_audioSessionCurrent(token)) {
          _poll?.cancel();
          return;
        }
        if (_pollInFlight) return;
        _pollInFlight = true;
        try {
          final status = await engine.status();
          if (!_audioSessionCurrent(token) || !_playing) return;
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
          if (_audioSessionCurrent(token)) {
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
      if (_audioSessionCurrent(token)) {
        _message(playbackFailureMessage(strings, error));
      }
    } finally {
      if (mounted && _ownsEngine) {
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
      final chosen = await showEditorVoicePanel(
        context,
        _instrument,
        sourceBounds: _triggerBounds(_voiceTarget),
      );
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
        sourceBounds: _triggerBounds(_tempoTarget),
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
        sourceBounds: _triggerBounds(_toolsTarget),
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

  Rect? _triggerBounds(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final bounds = box.localToGlobal(Offset.zero) & box.size;
    return bounds.overlaps(Offset.zero & MediaQuery.sizeOf(context))
        ? bounds
        : null;
  }

  Future<void> _openBackground() async {
    if (_panelShowing) return;
    _panelShowing = true;
    try {
      await _background();
    } finally {
      _panelShowing = false;
    }
  }

  Future<void> _background() async {
    _canvas.currentState?.finish();
    final value = await showBackgroundPanel(
      context,
      ref.read(editorProvider).document.effectiveBackground,
      sourceBounds: _triggerBounds(_backgroundTarget),
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
    final voiceLabel = instrumentName(context, _instrument);
    final musicLabel =
        '${context.strings.tempoValue(context.formatNumber(doc.tempo))} · ${doc.root.label} ${scaleName(context, doc.scale)}';
    final modeStyle = type.labelLarge;
    final longestToolWord =
        [context.strings.draw, context.strings.erase, voiceLabel, musicLabel]
            .map((label) => _labelWordMetrics(context, label, modeStyle).width)
            .fold(0.0, math.max);
    final paletteWidth = rail ? 300.0 : bodyWidth;
    final toolColumns = largeText
        ? (paletteWidth >= longestToolWord * 2 + 64 ? 2 : 1)
        : paletteWidth >= math.max(74, longestToolWord + 20) * 4
        ? 4
        : 2;
    final stackedToolbarHeight = largeText ? 150.0 : 0.0;
    final voice = _InstrumentTool(
      key: _voiceTarget,
      interactionKey: const ValueKey('current-voice'),
      label: voiceLabel,
      semanticLabel: '${context.strings.chooseAVoice}: $voiceLabel',
      glyph: DoodimoGlyph.sound,
      onPressed: _chooseVoice,
      horizontal: largeText && toolColumns == 1,
      marker: instrumentColors[_instrument.index],
    );
    final summary = _InstrumentTool(
      interactionKey: const ValueKey('music-settings'),
      label: rail && bodyHeight < 440 && largeText
          ? context.strings.tempoValue(context.formatNumber(doc.tempo))
          : musicLabel,
      semanticLabel: '${context.strings.musicSettings}: $musicLabel',
      glyph: DoodimoGlyph.tempo,
      onPressed: _musicSettings,
      horizontal: largeText && toolColumns == 1,
      labelKey: _tempoTarget,
      iconKey: _scaleTarget,
    );
    final toolbar = ImmersiveSurface(
      padding: const EdgeInsets.all(6),
      radius: 24,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final width = (bounds.maxWidth - (toolColumns - 1) * 4) / toolColumns;
          final modes = <Widget>[
            _InstrumentTool(
              label: context.strings.draw,
              glyph: DoodimoGlyph.draw,
              selected: !_eraser,
              horizontal: largeText && toolColumns == 1,
              onPressed: () {
                _canvas.currentState?.finish();
                setState(() => _eraser = false);
              },
            ),
            _InstrumentTool(
              label: context.strings.erase,
              glyph: DoodimoGlyph.erase,
              selected: _eraser,
              horizontal: largeText && toolColumns == 1,
              onPressed: () {
                _canvas.currentState?.finish();
                setState(() => _eraser = true);
              },
            ),
          ];
          final controls = rail && bodyHeight < 440 && !largeText
              ? [voice, summary, ...modes]
              : [...modes, voice, summary];
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final control in controls)
                    SizedBox(width: width, child: control),
                ],
              ),
              const SizedBox(height: 8),
              Divider(height: 1, color: colors.outlineVariant),
              const SizedBox(height: 6),
              Flex(
                direction: largeText ? Axis.vertical : Axis.horizontal,
                crossAxisAlignment: largeText
                    ? CrossAxisAlignment.stretch
                    : CrossAxisAlignment.center,
                children: [
                  _ModeSlot(
                    stacked: largeText,
                    child: StudioControl(
                      key: _toolsTarget,
                      interactionKey: const ValueKey('editor-tools'),
                      label: context.strings.editorTools,
                      onPressed: _tools,
                      fill: colors.surfaceContainerHigh,
                      foreground: colors.onSurface,
                      radius: 15,
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const DoodimoIcon(DoodimoGlyph.more, size: 22),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(context.strings.editorToolsShort),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: largeText ? 0 : 8, height: largeText ? 6 : 0),
                  _ModeSlot(
                    stacked: largeText,
                    child: StudioControl(
                      key: _backgroundTarget,
                      interactionKey: const ValueKey('editor-background'),
                      label: context.strings.paperColor,
                      onPressed: _openBackground,
                      fill: colors.surfaceContainerHigh,
                      foreground: colors.onSurface,
                      radius: 15,
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const DoodimoIcon(DoodimoGlyph.paper, size: 22),
                          const SizedBox(width: 8),
                          Flexible(child: Text(context.strings.paperColor)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    final play = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: hasMusic
                  ? [
                      Color.lerp(colors.primary, Colors.white, .18)!,
                      colors.primary,
                      Color.lerp(colors.primary, Colors.black, .22)!,
                    ]
                  : [
                      colors.surfaceContainerHighest,
                      colors.surfaceContainerHigh,
                      colors.surfaceContainerHigh,
                    ],
              stops: const [0, .55, 1],
            ),
            border: Border.all(
              color: hasMusic
                  ? Color.lerp(colors.primary, Colors.white, .52)!
                  : colors.outline,
              width: 1.3,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.shadow.withValues(alpha: dark ? .45 : .16),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: SizedBox.square(
            dimension: 64,
            child: IconButton(
              key: _playTarget,
              style: IconButton.styleFrom(
                foregroundColor: colors.onPrimary,
                disabledForegroundColor: colors.onSurfaceVariant,
              ),
              tooltip: _playing ? context.strings.pause : context.strings.play,
              onPressed: (!_playing && !hasMusic) || _preparing
                  ? null
                  : () => _play(),
              icon: _preparing
                  ? SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(
                        color: colors.onPrimary,
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
                        size: 28,
                        color: hasMusic
                            ? colors.onPrimary
                            : colors.onSurfaceVariant,
                      ),
                    ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _playing ? context.strings.pause : context.strings.play,
          textAlign: TextAlign.center,
          style: type.labelLarge,
        ),
      ],
    );
    final transport = ImmersiveSurface(
      key: const ValueKey('editor-instrument-console'),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      radius: 26,
      child: LayoutBuilder(
        builder: (context, bounds) {
          final metrics = _transportMetrics(
            context,
            bounds.maxWidth,
            large: largeText,
          );
          final columns = metrics.columns;
          final width = metrics.width;
          final keys = <Widget>[
            _HistoryControl(
              label: context.strings.undo,
              glyph: DoodimoGlyph.undo,
              onPressed: controller.canUndo
                  ? () => _historyEdit(redo: false)
                  : null,
            ),
            _HistoryControl(
              label: context.strings.redo,
              glyph: DoodimoGlyph.redo,
              onPressed: controller.canRedo
                  ? () => _historyEdit(redo: true)
                  : null,
            ),
            play,
            _HistoryControl(
              label: context.strings.replay,
              glyph: DoodimoGlyph.replay,
              onPressed: hasMusic ? () => _play(replay: true) : null,
            ),
            _HistoryControl(
              label: context.strings.slower,
              glyph: DoodimoGlyph.tempo,
              icon: Icons.remove_rounded,
              onPressed: doc.tempo > 60 ? () => _changeTempo(-1) : null,
            ),
            _HistoryControl(
              label: context.strings.faster,
              glyph: DoodimoGlyph.tempo,
              icon: Icons.add_rounded,
              onPressed: doc.tempo < 200 ? () => _changeTempo(1) : null,
            ),
          ];
          final order = columns == 1
              ? const [2, 0, 1, 3, 4, 5]
              : columns == 2
              ? const [0, 2, 1, 3, 4, 5]
              : const [0, 1, 2, 3, 4, 5];
          return Wrap(
            spacing: 4,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final index in order)
                SizedBox(width: width, child: keys[index]),
            ],
          );
        },
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
      child: ImmersiveSurface(
        padding: const EdgeInsets.all(8),
        radius: 25,
        child: AspectRatio(
          aspectRatio: .8,
          child: ArtworkFlightDestination(
            intent: widget.flightIntent,
            document: doc,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: colors.shadow.withValues(alpha: dark ? .38 : .14),
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
        ),
      ),
    );
    final exportAction = Tooltip(
      message: context.strings.exportLoop,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          minimumSize: const Size(48, 48),
        ),
        label: Text(
          context.strings.exportLoop,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: type.labelLarge?.copyWith(
            height: 1.15,
            color: colors.onPrimary,
          ),
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
        // Modal panels own keyboard avoidance. Resizing the live workspace
        // behind them can reparent its GlobalKey canvas at compact thresholds.
        resizeToAvoidBottomInset: false,
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
                transportFirstRowHeightForWidth: (width) => _transportMetrics(
                  context,
                  math.max(1, width - 12),
                  large: largeText,
                ).firstRowHeight,
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

/// Pure layout geometry shared by the transport and its parent reservation.
/// Both labels are measured even when idle, so Play→Pause never moves paper.
({int columns, double width, double firstRowHeight}) _transportMetrics(
  BuildContext context,
  double availableWidth, {
  required bool large,
}) {
  final strings = context.strings;
  final style = Theme.of(context).textTheme.labelLarge;
  final captions = [
    strings.undo,
    strings.redo,
    strings.play,
    strings.replay,
    strings.slower,
    strings.faster,
  ];
  final longestCaption = [...captions, strings.pause]
      .map((label) => _labelWordMetrics(context, label, style).width)
      .fold(0.0, math.max);
  final minimumWidth = math.max(56.0, longestCaption + 8);
  bool fits(int count) =>
      availableWidth >= count * minimumWidth + (count - 1) * 4;
  final columns = !large && fits(6)
      ? 6
      : !large && fits(4)
      ? 4
      : fits(2)
      ? 2
      : 1;
  final width = (availableWidth - (columns - 1) * 4) / columns;
  double textHeight(String label, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    )..layout(maxWidth: math.max(1, maxWidth));
    final height = painter.height;
    painter.dispose();
    return height;
  }

  final firstRow = columns == 1
      ? const [2]
      : columns == 2
      ? const [0, 2]
      : columns == 4
      ? const [0, 1, 2, 3]
      : const [0, 1, 2, 3, 4, 5];
  var height = 0.0;
  for (final index in firstRow) {
    final natural = index == 2
        ? 64.0 +
              6 +
              math.max(
                textHeight(strings.play, width),
                textHeight(strings.pause, width),
              )
        : 48.0 + 6 + 12 + textHeight(captions[index], width - 8);
    height = math.max(height, natural);
  }
  // Existing plate vertical padding plus one logical-pixel rounding allowance.
  return (
    columns: columns,
    width: width,
    firstRowHeight: (height + 20).ceilToDouble() + 1,
  );
}

class _ModeSlot extends StatelessWidget {
  const _ModeSlot({required this.stacked, required this.child});
  final bool stacked;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      stacked ? child : Expanded(child: child);
}

class _InstrumentTool extends StatelessWidget {
  const _InstrumentTool({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.semanticLabel,
    this.interactionKey,
    this.labelKey,
    this.iconKey,
    this.selected,
    this.horizontal = false,
    this.marker,
  });
  final String label;
  final String? semanticLabel;
  final DoodimoGlyph glyph;
  final VoidCallback onPressed;
  final Key? interactionKey, labelKey, iconKey;
  final bool? selected;
  final bool horizontal;
  final Color? marker;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final active = selected == true;
    final icon = Container(
      key: iconKey,
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.surfaceContainerHighest, colors.surfaceContainerLow],
        ),
        border: Border.all(
          color: active ? colors.primary : colors.outline,
          width: active ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: .2),
            offset: const Offset(0, 2),
            blurRadius: 3,
          ),
        ],
      ),
      child: Center(
        child: DoodimoIcon(
          glyph,
          size: 24,
          color: active ? colors.primary : colors.onSurface,
        ),
      ),
    );
    final caption = Text(
      label,
      key: labelKey,
      textAlign: horizontal ? TextAlign.start : TextAlign.center,
      style: Theme.of(context).textTheme.labelLarge
          ?.copyWith(color: active ? colors.primary : colors.onSurface),
    );
    return StudioControl(
      interactionKey: interactionKey,
      label: semanticLabel ?? label,
      selected: selected,
      onPressed: onPressed,
      fill: Colors.transparent,
      foreground: colors.onSurface,
      padding: EdgeInsets.symmetric(
        horizontal: 6,
        vertical: horizontal ? 4 : 8,
      ),
      radius: 18,
      child: horizontal
          ? Row(
              children: [
                icon,
                const SizedBox(width: 12),
                Expanded(child: caption),
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                icon,
                const SizedBox(height: 7),
                caption,
                if (marker != null) ...[
                  const SizedBox(height: 5),
                  Container(width: 22, height: 2, color: marker),
                ],
              ],
            ),
    );
  }
}

class _HistoryControl extends StatelessWidget {
  const _HistoryControl({
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.icon,
  });
  final String label;
  final DoodimoGlyph glyph;
  final IconData? icon;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return StudioControl(
      label: label,
      onPressed: onPressed,
      fill: Colors.transparent,
      foreground: colors.onSurface,
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      radius: 18,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colors.surfaceContainerHigh,
              border: Border.all(
                color: onPressed == null
                    ? colors.outlineVariant
                    : colors.outline,
              ),
            ),
            child: Center(
              child: icon != null
                  ? Icon(
                      icon,
                      size: 23,
                      color: onPressed == null
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    )
                  : DoodimoIcon(
                      glyph,
                      size: 23,
                      color: onPressed == null
                          ? colors.onSurfaceVariant
                          : colors.onSurface,
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: onPressed == null
                  ? colors.onSurfaceVariant
                  : colors.onSurface,
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
