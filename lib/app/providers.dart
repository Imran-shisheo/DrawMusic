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
final openedDocumentProvider = FutureProvider.autoDispose
    .family<ProjectLoad, String>((ref, id) async {
      if (id == 'new') return ProjectLoad(ProjectDocument(id: newId()));
      if (id.startsWith('template-')) return ProjectLoad(makeTemplate(id));
      return (await ref.watch(repositoryProvider.future)).open(id);
    });

ProjectDocument makeTemplate(String id) => templateById(id).create();
