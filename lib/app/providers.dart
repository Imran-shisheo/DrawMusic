import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../creative_document/document.dart';
import '../features/library/data/file_project_repository.dart';
import '../features/library/domain/project_repository.dart';
import '../features/transport/data/android_audio_engine.dart';
import '../features/transport/domain/audio_engine.dart';

final repositoryProvider = FutureProvider<ProjectRepository>((ref) async {
  final root = await getApplicationSupportDirectory();
  return FileProjectRepository(Directory('${root.path}/projects'));
});
final libraryProvider = FutureProvider<ProjectListing>(
  (ref) async => (await ref.watch(repositoryProvider.future)).list(),
);
final audioEngineProvider = Provider<AudioEngine>(
  (ref) => AndroidAudioEngine(),
);
final initialDocumentProvider = Provider<ProjectDocument>(
  (ref) => throw StateError('Editor document not supplied'),
  dependencies: [],
);
final openedDocumentProvider = FutureProvider.autoDispose
    .family<ProjectDocument, String>((ref, id) async {
      if (id == 'new') return ProjectDocument(id: newId());
      if (id.startsWith('template-')) return makeTemplate(id);
      return (await ref.watch(repositoryProvider.future)).load(id);
    });

ProjectDocument makeTemplate(String id) {
  final points = switch (id) {
    'template-rain' => [
      InkPoint(.15, .2),
      InkPoint(.15, .35),
      InkPoint(.35, .25),
      InkPoint(.35, .5),
      InkPoint(.6, .3),
      InkPoint(.6, .6),
      InkPoint(.85, .2),
      InkPoint(.85, .45),
    ],
    _ => [
      InkPoint(.08, .65),
      InkPoint(.25, .3),
      InkPoint(.42, .65),
      InkPoint(.6, .3),
      InkPoint(.78, .65),
      InkPoint(.92, .45),
    ],
  };
  return ProjectDocument(
    id: newId(),
    title: id == 'template-rain' ? 'Little rain' : 'Paper hills',
    strokes: [
      Stroke(
        id: 'original-template-v1',
        instrument: id == 'template-rain' ? Instrument.bell : Instrument.mallet,
        points: points,
      ),
    ],
  );
}
