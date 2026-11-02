import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../creative_document/document.dart';
import '../features/home/domain/template_catalog.dart';
import '../features/library/data/file_project_repository.dart';
import '../features/library/domain/project_repository.dart';
import '../features/transport/data/android_audio_engine.dart';
import '../features/transport/data/ios_audio_engine.dart';
import '../features/transport/domain/audio_engine.dart';

final repositoryProvider = FutureProvider<ProjectRepository>((ref) async {
  final root = await getApplicationSupportDirectory();
  return FileProjectRepository(Directory('${root.path}/projects'));
});
final libraryProvider = FutureProvider<ProjectListing>(
  (ref) async => (await ref.watch(repositoryProvider.future)).list(),
);
final audioEngineProvider = Provider<AudioEngine>(
  (ref) => Platform.isIOS ? IosAudioEngine() : AndroidAudioEngine(),
);
final initialDocumentProvider = Provider<ProjectDocument>(
  (ref) => throw StateError('Editor document not supplied'),
  dependencies: [],
);

/// A transient navigation identity, never a document ID or persisted schema.
/// Separate requests cannot reuse a popping editor's initial load snapshot.
class EditorLoadRequest {
  const EditorLoadRequest({required this.projectId, required this.sessionId});
  final String projectId, sessionId;
  @override
  bool operator ==(Object other) =>
      other is EditorLoadRequest &&
      other.projectId == projectId &&
      other.sessionId == sessionId;
  @override
  int get hashCode => Object.hash(projectId, sessionId);
}

Future<ProjectLoad> _readEditorDocument(Ref ref, String id) async {
  if (id == 'new') return ProjectLoad(ProjectDocument(id: newId()));
  if (id.startsWith('template-')) return ProjectLoad(makeTemplate(id));
  return (await ref.watch(repositoryProvider.future)).open(id);
}

// Retained for direct/legacy callers and existing domain fixtures.
final openedDocumentProvider = FutureProvider.autoDispose
    .family<ProjectLoad, String>((ref, id) => _readEditorDocument(ref, id));

final editorLoadProvider = FutureProvider.autoDispose
    .family<ProjectLoad, EditorLoadRequest>(
      (ref, request) => _readEditorDocument(ref, request.projectId),
    );

ProjectDocument makeTemplate(String id) => templateById(id).create();
