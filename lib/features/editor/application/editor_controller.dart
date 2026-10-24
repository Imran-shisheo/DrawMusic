import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../creative_document/document.dart';
import '../../library/domain/project_repository.dart';
import '../domain/history.dart';

class EditorState {
  const EditorState(
    this.document, {
    this.saving = false,
    this.savedRevision = -1,
    this.error,
  });
  final ProjectDocument document;
  final bool saving;
  final int savedRevision;
  final String? error;
  bool get dirty => savedRevision != document.revision;
}

final editorProvider =
    NotifierProvider.autoDispose<EditorController, EditorState>(
      EditorController.new,
      dependencies: [initialDocumentProvider],
    );

class EditorController extends Notifier<EditorState> {
  late DocumentHistory history;
  Timer? _debounce;
  ProjectRepository? _repository;
  bool _alive = true;
  Future<void> _pending = Future.value();
  @override
  EditorState build() {
    final doc = ref.watch(initialDocumentProvider);
    history = DocumentHistory(doc);
    ref.onDispose(() {
      _alive = false;
      _debounce?.cancel();
    });
    return EditorState(doc, savedRevision: -1);
  }

  bool get canUndo => history.canUndo;
  bool get canRedo => history.canRedo;
  void attachRepository(ProjectRepository repository) {
    _repository = repository;
    _schedule();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () => save());
  }

  void commit(ProjectDocument next) {
    history.commit(next);
    _publish();
  }

  void undo() {
    history.undo();
    _publish();
  }

  void redo() {
    history.redo();
    _publish();
  }

  void _publish() {
    state = EditorState(history.document, savedRevision: state.savedRevision);
    _schedule();
  }

  Future<bool> save() async {
    _debounce?.cancel();
    final repository = _repository;
    if (repository == null) return false;
    final snapshot = state.document;
    state = EditorState(
      state.document,
      saving: true,
      savedRevision: state.savedRevision,
    );
    var success = false;
    final operation = _pending.then((_) async {
      try {
        await repository.save(snapshot);
        success = true;
        if (_alive) {
          state = EditorState(state.document, savedRevision: snapshot.revision);
          ref.invalidate(libraryProvider);
        }
      } catch (_) {
        if (_alive) {
          state = EditorState(
            state.document,
            savedRevision: state.savedRevision,
            error: 'Could not save this drawing. Check device storage, then retry.',
          );
        }
      }
    });
    _pending = operation;
    await operation;
    return success;
  }
}
