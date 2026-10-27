import 'package:scribblesong/l10n/strings.dart';

import 'dart:async';
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

  Future<void> _tempoPanel() async {
    var tempo = ref.read(editorProvider).document.tempo;
    final chosen = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: Text(context.strings.loopTempo),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(context.strings.tempoValue(context.formatNumber(tempo))),
              Slider(
                min: 60,
                max: 200,
                divisions: 140,
                value: tempo.toDouble(),
                label: context.strings.tempoValue(context.formatNumber(tempo)),
                onChanged: (value) => setDialog(() => tempo = value.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strings.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tempo),
              child: Text(context.strings.apply),
            ),
          ],
        ),
      ),
    );
    if (chosen != null && mounted) {
      _edit(ref.read(editorProvider).document.copyWith(tempo: chosen));
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
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(context.strings.yourLoopInNotes),
          content: SingleChildScrollView(
            child: Text(
              '${context.strings.scoreSummary(doc.root.label, context.formatNumber(score.notes.length), context.formatNumber(doc.tempo), scaleName(context, doc.scale))}\n\n${score.notes.take(80).map((n) => context.strings.scoreEvent(n.percussion ? switch (n.pitch) {
                      36 => context.strings.kick,
                      38 => context.strings.snare,
                      39 => context.strings.clap,
                      _ => context.strings.hiHat,
                    } : instrumentName(context, n.instrument), context.formatNumber(n.pitch), context.formatDecimal(n.startBeat + 1), context.formatDecimal(n.durationBeat))).join('\n')}${score.notes.length > 80 ? '\n${context.strings.showingFirst80Events}' : ''}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.strings.close),
            ),
          ],
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
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.strings.clearThisDrawing),
        content: Text(context.strings.youCanRestoreItWithUndo),
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
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_leave());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: context.strings.backToGallery,
            onPressed: _leaving ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: Semantics(
            button: true,
            label: context.strings.renameDrawingLabel(doc.title),
            child: ExcludeSemantics(
              child: InkWell(
                onTap: _rename,
                child: Text(
                  doc.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
          actions: [
            IconButton(
              tooltip: context.strings.editorTips,
              onPressed: _showTips,
              icon: const Icon(Icons.help_outline),
            ),
            IconButton(
              tooltip: context.strings.exportLoop,
              onPressed: _leaving
                  ? null
                  : () async {
                      _canvas.currentState?.finish();
                      await _pause();
                      if (context.mounted) {
                        await showExportSheet(
                          context,
                          ref.read(editorProvider).document,
                        );
                        if (mounted) await _offerRating();
                      }
                    },
              icon: const Icon(Icons.ios_share),
            ),
            IconButton(
              tooltip: context.strings.saveDrawing,
              onPressed: state.saving ? null : _explicitSave,
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: LayoutBuilder(
              builder: (context, constraints) => ResponsiveEditorLayout(
                width: constraints.maxWidth,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * .32,
                    ),
                    child: SingleChildScrollView(
                      key: const ValueKey('editor-tools-scroll'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
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
                              context
                                  .strings
                                  .storageUnavailableRetryFromDraftsBeforeLeaving,
                              style: TextStyle(color: Colors.red),
                            ),
                          if (state.error != null)
                            TextButton(
                              onPressed: () => controller.save(),
                              child: Text(context.strings.drawingSaveRetry),
                            ),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              RepeatingIconButton(
                                tooltip: context.strings.slower,
                                onStep: doc.tempo > 60
                                    ? () => _changeTempo(-1)
                                    : null,
                                icon: Icons.remove,
                              ),
                              TextButton(
                                key: _tempoTarget,
                                onPressed: _tempoPanel,
                                child: Text(
                                  context.strings.tempoValue(
                                    context.formatNumber(doc.tempo),
                                  ),
                                ),
                              ),
                              RepeatingIconButton(
                                tooltip: context.strings.faster,
                                onStep: doc.tempo < 200
                                    ? () => _changeTempo(1)
                                    : null,
                                icon: Icons.add,
                              ),
                              IconButton(
                                tooltip: context.strings.drawingStyle,
                                onPressed: _drawingStyle,
                                icon: Icon(
                                  doc.style == DrawingStyle.smooth
                                      ? Icons.gesture
                                      : Icons.grid_on,
                                ),
                              ),
                              IconButton(
                                tooltip: context.strings.paperColor,
                                onPressed: _background,
                                icon: const Icon(Icons.palette_outlined),
                              ),
                              Tooltip(
                                message: context.strings.expressiveModeHelp,
                                child: FilterChip(
                                  label: Text(context.strings.expressiveMode),
                                  selected:
                                      doc.expressionMode ==
                                      ExpressionMode.expressive,
                                  onSelected: (enabled) {
                                    _canvas.currentState?.finish();
                                    _edit(
                                      ref
                                          .read(editorProvider)
                                          .document
                                          .copyWith(
                                            expressionMode: enabled
                                                ? ExpressionMode.expressive
                                                : ExpressionMode.geometry,
                                          ),
                                    );
                                  },
                                ),
                              ),
                              IconButton(
                                tooltip: context.strings.clearDrawing,
                                onPressed: doc.strokes.isEmpty ? null : _clear,
                                icon: const Icon(Icons.delete_sweep_outlined),
                              ),
                            ],
                          ),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: Text(context.strings.draw),
                                  selected: !_eraser,
                                  onSelected: (_) {
                                    _canvas.currentState?.finish();
                                    setState(() => _eraser = false);
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: Text(context.strings.erase),
                                  selected: _eraser,
                                  onSelected: (_) {
                                    _canvas.currentState?.finish();
                                    setState(() => _eraser = true);
                                  },
                                ),
                                const SizedBox(width: 12),
                                IconButton(
                                  tooltip: context.strings.describeScore,
                                  onPressed: _describing ? null : _describe,
                                  icon: const Icon(Icons.list_alt),
                                ),
                                Semantics(
                                  label: context.strings.rootKey,
                                  child: DropdownButton<RootKey>(
                                    value: doc.root,
                                    items: [
                                      for (final root in RootKey.values)
                                        DropdownMenuItem(
                                          value: root,
                                          child: Text(root.label),
                                        ),
                                    ],
                                    onChanged: (root) {
                                      if (root != null) {
                                        _canvas.currentState?.finish();
                                        _edit(
                                          ref
                                              .read(editorProvider)
                                              .document
                                              .copyWith(root: root),
                                        );
                                      }
                                    },
                                  ),
                                ),
                                IconButton(
                                  tooltip: context.strings.accompaniment,
                                  icon: const Icon(Icons.queue_music),
                                  onPressed: () async {
                                    _canvas.currentState?.finish();
                                    final mix = await showAccompanimentPanel(
                                      context,
                                      ref.read(editorProvider).document.mix,
                                    );
                                    if (mix != null && mounted) {
                                      _edit(
                                        ref
                                            .read(editorProvider)
                                            .document
                                            .copyWith(mix: mix),
                                      );
                                    }
                                  },
                                ),
                                DropdownButton<MusicalScale>(
                                  key: _scaleTarget,
                                  value: doc.scale,
                                  items: [
                                    for (final scale in MusicalScale.values)
                                      DropdownMenuItem(
                                        value: scale,
                                        child: Text(
                                          doc.root == RootKey.c &&
                                                  scale == MusicalScale.major
                                              ? context.strings.cMajorPentatonic
                                              : doc.root == RootKey.c &&
                                                    scale == MusicalScale.minor
                                              ? context.strings.cMinorPentatonic
                                              : '${doc.root.label} ${scaleName(context, scale)}',
                                        ),
                                      ),
                                  ],
                                  onChanged: (scale) {
                                    if (scale != null) {
                                      _edit(
                                        ref
                                            .read(editorProvider)
                                            .document
                                            .copyWith(scale: scale),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: .8,
                        child: DrawingCanvas(
                          key: _canvas,
                          document: doc,
                          instrument: _instrument,
                          eraser: _eraser,
                          cursor: _cursor,
                          onCommit: (strokes) => _edit(
                            ref
                                .read(editorProvider)
                                .document
                                .copyWith(strokes: strokes),
                          ),
                          onSimplified: (before, after) =>
                              _message(context.strings.geometrySimplified),
                          onLimit: () =>
                              _message(context.strings.drawingPointLimit),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * .32,
                    ),
                    child: SingleChildScrollView(
                      key: const ValueKey('editor-transport-scroll'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(
                                tooltip: context.strings.undo,
                                onPressed: controller.canUndo
                                    ? () {
                                        _historyEdit(redo: false);
                                      }
                                    : null,
                                icon: const Icon(Icons.undo),
                              ),
                              IconButton(
                                tooltip: context.strings.redo,
                                onPressed: controller.canRedo
                                    ? () {
                                        _historyEdit(redo: true);
                                      }
                                    : null,
                                icon: const Icon(Icons.redo),
                              ),
                              IconButton.filled(
                                key: _playTarget,
                                tooltip: _playing
                                    ? context.strings.pause
                                    : context.strings.play,
                                onPressed:
                                    (!_playing &&
                                            doc.strokes.isEmpty &&
                                            !doc.mix.isActive) ||
                                        _preparing
                                    ? null
                                    : () => _play(),
                                icon: _preparing
                                    ? const SizedBox(
                                        width: 24,
                                        height: 24,
                                        child: CircularProgressIndicator(),
                                      )
                                    : Icon(
                                        _playing
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                      ),
                                iconSize: 36,
                              ),
                              IconButton(
                                tooltip: context.strings.replay,
                                onPressed:
                                    doc.strokes.isEmpty && !doc.mix.isActive
                                    ? null
                                    : () => _play(replay: true),
                                icon: const Icon(Icons.replay),
                              ),
                            ],
                          ),
                          if (_prepared && _wantedRevision != _heardRevision)
                            Text(
                              _pendingBoundary == UpdateBoundary.beat
                                  ? context.strings.updatesNextBeat
                                  : context.strings.updatesNextLoop,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          Text(
                            doc.strokes.isEmpty && !doc.mix.isActive
                                ? context.strings.drawSomethingToHearIt
                                : state.saving
                                ? context.strings.saving
                                : state.dirty
                                ? context.strings.changesPending
                                : context.strings.savedOnThisDevice,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 4),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (final instrument in Instrument.values)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: ChoiceChip(
                                      key: instrument == Instrument.keys
                                          ? _voiceTarget
                                          : null,
                                      avatar: Icon(
                                        instrumentIcons[instrument.index],
                                        color:
                                            instrumentColors[instrument.index],
                                      ),
                                      label: Text(
                                        instrumentName(context, instrument),
                                      ),
                                      selected: _instrument == instrument,
                                      onSelected: (_) {
                                        _canvas.currentState?.finish();
                                        _selectionFeedback();
                                        setState(() {
                                          _instrument = instrument;
                                          _eraser = false;
                                        });
                                      },
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
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
