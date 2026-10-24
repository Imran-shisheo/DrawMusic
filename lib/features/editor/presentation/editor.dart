import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../creative_document/document.dart';
import '../../composition/domain/score.dart';
import '../../export/presentation/export_sheet.dart';
import '../../transport/domain/audio_engine.dart';
import '../../composition/domain/audio_renderer.dart';
import '../application/editor_controller.dart';
import 'canvas.dart';

class EditorPage extends ConsumerWidget {
  const EditorPage({super.key, required this.projectId});
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
          overrides: [initialDocumentProvider.overrideWithValue(doc)],
          child: const EditorWorkspace(),
        ),
      );
}

class EditorWorkspace extends ConsumerStatefulWidget {
  const EditorWorkspace({super.key});
  @override
  ConsumerState<EditorWorkspace> createState() => _EditorWorkspaceState();
}

class _EditorWorkspaceState extends ConsumerState<EditorWorkspace>
    with WidgetsBindingObserver {
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
  int _audioGeneration = 0;
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
    _poll?.cancel();
    try {
      await ref.read(audioEngineProvider).pause();
    } catch (_) {
      /* No active engine is safe on first launch. */
    }
    if (mounted) setState(() => _playing = false);
  }

  void _edit(ProjectDocument next) {
    // Interim policy: pause on committed edits so preview never plays stale notes.
    _audioGeneration++;
    unawaited(_pause());
    _prepared = false;
    _cursor.value = null;
    ref.read(editorProvider.notifier).commit(next);
  }

  Future<void> _play({bool replay = false}) async {
    if (_preparing) return;
    _canvas.currentState?.finish();
    if (_playing && !replay) {
      await _pause();
      return;
    }
    final token = ++_audioGeneration;
    setState(() => _preparing = true);
    try {
      final document = ref.read(editorProvider).document;
      final score = compileScore(document);
      if (score.notes.isEmpty) return;
      final engine = ref.read(audioEngineProvider);
      if (!_prepared || replay) {
        final pcm = await compute(
          (ScoreSnapshot s) => renderPcm(s, loop: true),
          score,
        );
        if (!mounted || token != _audioGeneration) return;
        await engine.prepare(pcm);
        _prepared = true;
      }
      if (!mounted || token != _audioGeneration) return;
      await engine.play();
      if (!mounted || token != _audioGeneration) {
        await engine.pause();
        return;
      }
      setState(() => _playing = true);
      _poll?.cancel();
      _poll = Timer.periodic(const Duration(milliseconds: 50), (_) async {
        try {
          if (!await engine.isPlaying()) {
            await _pause();
            return;
          }
          final seconds = await engine.positionSeconds();
          if (mounted && _playing) _cursor.value = seconds / score.loopSeconds;
        } catch (_) {
          unawaited(_pause());
        }
      });
    } catch (e) {
      _prepared = false;
      _message('Could not play. $e');
    } finally {
      if (mounted) setState(() => _preparing = false);
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

  Future<void> _rename() async {
    final text = TextEditingController(
      text: ref.read(editorProvider).document.title,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Name your drawing'),
        content: TextField(
          controller: text,
          autofocus: true,
          maxLength: 60,
          decoration: const InputDecoration(labelText: 'Title'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, text.text.trim()),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
    // The route transition may still refer to its controller until the next frame.
    Future<void>.delayed(const Duration(milliseconds: 400), text.dispose);
    if (value != null && value.isNotEmpty && mounted) {
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

  void _describe() {
    try {
      final doc = ref.read(editorProvider).document;
      final score = compileScore(doc);
      showDialog<void>(
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
      _message(e.toString());
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
                    IconButton(
                      tooltip: 'Slower',
                      onPressed: doc.tempo > 60
                          ? () => _edit(doc.copyWith(tempo: doc.tempo - 1))
                          : null,
                      icon: const Icon(Icons.remove),
                    ),
                    Text('${doc.tempo} BPM'),
                    IconButton(
                      tooltip: 'Faster',
                      onPressed: doc.tempo < 200
                          ? () => _edit(doc.copyWith(tempo: doc.tempo + 1))
                          : null,
                      icon: const Icon(Icons.add),
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
                        onPressed: _describe,
                        icon: const Icon(Icons.list_alt),
                      ),
                      DropdownButton<MusicalScale>(
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
                          if (scale != null) _edit(doc.copyWith(scale: scale));
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
                        onCommit: (strokes) =>
                            _edit(doc.copyWith(strokes: strokes)),
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
                              unawaited(_pause());
                              _prepared = false;
                              controller.undo();
                            }
                          : null,
                      icon: const Icon(Icons.undo),
                    ),
                    IconButton(
                      tooltip: 'Redo',
                      onPressed: controller.canRedo
                          ? () {
                              unawaited(_pause());
                              _prepared = false;
                              controller.redo();
                            }
                          : null,
                      icon: const Icon(Icons.redo),
                    ),
                    IconButton.filled(
                      tooltip: _playing ? 'Pause' : 'Play',
                      onPressed: doc.strokes.isEmpty || _preparing
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
                            avatar: Icon(
                              instrumentIcons[instrument.index],
                              color: instrumentColors[instrument.index],
                            ),
                            label: Text(instrumentNames[instrument.index]),
                            selected: _instrument == instrument,
                            onSelected: (_) => setState(() {
                              _instrument = instrument;
                              _eraser = false;
                            }),
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
