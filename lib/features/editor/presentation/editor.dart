import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../settings/application/settings_controller.dart';
import '../../../creative_document/document.dart';
import '../../../design_system/name_dialog.dart';
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
            const Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => Scaffold(
          appBar: AppBar(title: const Text('Drawing unavailable')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Could not open this drawing. The original file is preserved.',
                ),
                TextButton(
                  onPressed: () =>
                      ref.invalidate(openedDocumentProvider(projectId)),
                  child: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => context.go('/drafts'),
                  child: const Text('Back to drafts'),
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
        'Draw a melody',
        'Left to right follows eight beats. Higher marks make higher notes; vertical marks can form chords. Erase and Undo let you explore safely.',
        _canvas,
      ),
      EditorTip(
        'Listen and pause',
        'Play repeats your drawing. Tap Pause to keep your place, or Replay to start over. Music pauses when you leave the app.',
        _playTarget,
      ),
      EditorTip(
        'Choose a voice',
        'Cloud keys, Wood drops and Glass stars are named original instruments. Each new stroke uses the selected voice; existing strokes keep theirs.',
        _voiceTarget,
      ),
      EditorTip(
        'Set the pace',
        'Tap the BPM number for the tempo slider. Hold minus or plus to repeat, from 60 to 200 BPM. Tempo updates arrive on a beat; drawing updates arrive on a loop.',
        _tempoTarget,
      ),
      EditorTip(
        'Key and scale',
        'This version uses the key of C. Choose major or minor pentatonic here to change the mood. The same score drives preview and exports.',
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
        _message(
          'Tips closed for now. Completion could not be saved; retry from Settings or replay Editor tips.',
        );
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
        previous.scale != next.scale;
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
        _message('Could not update playback. $error');
      }
    }
  }

  Future<void> _play({bool replay = false}) async {
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
            _message('Playback stopped. Please retry.');
          }
        } finally {
          _pollInFlight = false;
        }
      });
    } on PlatformException catch (e) {
      _prepared = false;
      _message(
        'Could not play. ${e.message ?? 'Audio output could not start. Please retry.'}',
      );
    } catch (e) {
      _prepared = false;
      _message('Could not play. $e');
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
      _message(
        'Save did not complete. Stay here and retry Save before leaving.',
      );
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
          title: const Text('Loop tempo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$tempo BPM'),
              Slider(
                min: 60,
                max: 200,
                divisions: 140,
                value: tempo.toDouble(),
                label: '$tempo BPM',
                onChanged: (value) => setDialog(() => tempo = value.round()),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, tempo),
              child: const Text('Apply'),
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

  Future<void> _background() async {
    var selected = ref.read(editorProvider).document.background;
    final value = await showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Paper color'),
          content: Wrap(
            spacing: 8,
            children: [0xfff7f5eb, 0xffeef5f1, 0xfff3eef9, 0xffffeeee]
                .map(
                  (color) => IconButton(
                    tooltip: color == selected
                        ? 'Selected paper'
                        : 'Choose paper',
                    onPressed: () => setDialog(() => selected = color),
                    style: IconButton.styleFrom(backgroundColor: Color(color)),
                    icon: Icon(
                      color == selected ? Icons.check : Icons.circle_outlined,
                    ),
                  ),
                )
                .toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
    if (value != null && mounted) {
      _edit(ref.read(editorProvider).document.copyWith(background: value));
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
          title: const Text('Your loop in notes'),
          content: SingleChildScrollView(
            child: Text(
              '${score.notes.length} note events · ${doc.tempo} BPM · C ${doc.scale.name} pentatonic.\n\n${score.notes.take(80).map((n) => '${instrumentNames[n.instrument.index]}: MIDI pitch ${n.pitch}, beat ${(n.startBeat + 1).toStringAsFixed(2)}, lasts ${n.durationBeat.toStringAsFixed(2)} beats.').join('\n')}${score.notes.length > 80 ? '\nShowing the first 80 events.' : ''}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _message(e.toString());
    } finally {
      if (mounted) setState(() => _describing = false);
    }
  }

  Future<void> _clear() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear this drawing?'),
        content: const Text('You can restore it with Undo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep drawing'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
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
      if (!state.saving && state.savedRevision < 0) {
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
            tooltip: 'Back to gallery',
            onPressed: _leaving ? null : _leave,
            icon: const Icon(Icons.arrow_back),
          ),
          title: InkWell(
            onTap: _rename,
            child: Text(
              doc.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          actions: [
            IconButton(
              tooltip: 'Editor tips',
              onPressed: _showTips,
              icon: const Icon(Icons.help_outline),
            ),
            IconButton(
              tooltip: 'Export loop',
              onPressed: doc.strokes.isEmpty
                  ? null
                  : () async {
                      _canvas.currentState?.finish();
                      await _pause();
                      if (context.mounted) {
                        await showExportSheet(
                          context,
                          ref.read(editorProvider).document,
                        );
                      }
                    },
              icon: const Icon(Icons.ios_share),
            ),
            IconButton(
              tooltip: 'Save drawing',
              onPressed: state.saving ? null : () => controller.save(),
              icon: const Icon(Icons.save_outlined),
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Column(
              children: [
                if (widget.recovered)
                  const Text(
                    'Recovered the previous complete revision. The damaged file is preserved.',
                  ),
                if (repo.hasError)
                  const Text(
                    'Storage unavailable. Retry from Drafts before leaving.',
                    style: TextStyle(color: Colors.red),
                  ),
                if (state.error != null)
                  TextButton(
                    onPressed: () => controller.save(),
                    child: Text('${state.error} Retry'),
                  ),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    RepeatingIconButton(
                      tooltip: 'Slower',
                      onStep: doc.tempo > 60 ? () => _changeTempo(-1) : null,
                      icon: Icons.remove,
                    ),
                    TextButton(
                      key: _tempoTarget,
                      onPressed: _tempoPanel,
                      child: Text('${doc.tempo} BPM'),
                    ),
                    RepeatingIconButton(
                      tooltip: 'Faster',
                      onStep: doc.tempo < 200 ? () => _changeTempo(1) : null,
                      icon: Icons.add,
                    ),
                    IconButton(
                      tooltip: 'Paper color',
                      onPressed: _background,
                      icon: const Icon(Icons.palette_outlined),
                    ),
                    IconButton(
                      tooltip: 'Clear drawing',
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
                        label: const Text('Draw'),
                        selected: !_eraser,
                        onSelected: (_) => setState(() => _eraser = false),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Erase'),
                        selected: _eraser,
                        onSelected: (_) => setState(() => _eraser = true),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: 'Describe score',
                        onPressed: _describing ? null : _describe,
                        icon: const Icon(Icons.list_alt),
                      ),
                      DropdownButton<MusicalScale>(
                        key: _scaleTarget,
                        value: doc.scale,
                        items: const [
                          DropdownMenuItem(
                            value: MusicalScale.major,
                            child: Text('C major pentatonic'),
                          ),
                          DropdownMenuItem(
                            value: MusicalScale.minor,
                            child: Text('C minor pentatonic'),
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
                        onLimit: () => _message(
                          '100,000 point limit reached. Save this drawing and start a new one.',
                        ),
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Undo',
                      onPressed: controller.canUndo
                          ? () {
                              _historyEdit(redo: false);
                            }
                          : null,
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      onPressed: controller.canRedo
                          ? () {
                              _historyEdit(redo: true);
                            }
                          : null,
                      icon: const Icon(Icons.redo),
                    ),
                    IconButton.filled(
                      key: _playTarget,
                      tooltip: _playing ? 'Pause' : 'Play',
                      onPressed:
                          (!_playing && doc.strokes.isEmpty) || _preparing
                          ? null
                          : () => _play(),
                      icon: _preparing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(),
                            )
                          : Icon(_playing ? Icons.pause : Icons.play_arrow),
                      iconSize: 36,
                    ),
                    IconButton(
                      tooltip: 'Replay',
                      onPressed: doc.strokes.isEmpty
                          ? null
                          : () => _play(replay: true),
                      icon: const Icon(Icons.replay),
                    ),
                  ],
                ),
                if (_prepared && _wantedRevision != _heardRevision)
                  Text(
                    _pendingBoundary == UpdateBoundary.beat
                        ? 'Updates next beat'
                        : 'Updates next loop',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  doc.strokes.isEmpty
                      ? 'Draw something to hear it.'
                      : state.saving
                      ? 'Saving…'
                      : state.dirty
                      ? 'Changes pending'
                      : 'Saved on this device',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final instrument in Instrument.values)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            key: instrument == Instrument.keys
                                ? _voiceTarget
                                : null,
                            avatar: Icon(
                              instrumentIcons[instrument.index],
                              color: instrumentColors[instrument.index],
                            ),
                            label: Text(instrumentNames[instrument.index]),
                            selected: _instrument == instrument,
                            onSelected: (_) {
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
