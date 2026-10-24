import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';

import 'support/memory_preferences.dart';

import 'package:scribblesong/features/settings/domain/preferences.dart';

import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/transport/domain/audio_engine.dart';

class MemoryRepository implements ProjectRepository {
  final documents = <String, ProjectDocument>{};
  bool fail = false;
  final deleted = <String>{};
  @override
  Future<ProjectLoad> open(String id) async => ProjectLoad(await load(id));
  @override
  Future<void> rename(String id, String title) async =>
      save((await load(id)).copyWith(title: title));
  @override
  Future<ProjectDocument> duplicate(String id) async {
    final doc = (await load(id)).copyWith(
      id: newId(),
      title: '${(await load(id)).title} copy',
      revision: 0,
    );
    await save(doc);
    return doc;
  }

  @override
  Future<void> softDelete(String id) async {
    deleted.add(id);
  }

  @override
  Future<void> restore(String id) async {
    deleted.remove(id);
  }

  @override
  Future<void> save(ProjectDocument doc) async {
    if (fail) throw StateError('Disk full');
    documents[doc.id] = doc;
  }

  @override
  Future<ProjectDocument> load(String id) async => documents[id]!;
  @override
  Future<ProjectListing> list() async => ProjectListing(
    documents.values.where((d) => !deleted.contains(d.id)).toList(),
    [],
  );
}

class TestAudio implements AudioEngine {
  double volume = 1;
  int prepares = 0, plays = 0;
  bool playing = false;
  int revision = 0, tempo = 120;
  final queued = <({int revision, int tempo, UpdateBoundary boundary})>[];
  @override
  Future<void> prepare(
    Int16List pcm, {
    int revision = 0,
    int tempo = 120,
  }) async {
    prepares++;
    this.revision = revision;
    this.tempo = tempo;
    expect(pcm.any((n) => n != 0), isTrue);
  }

  @override
  Future<void> queue(
    Int16List pcm, {
    required int revision,
    required int tempo,
    required UpdateBoundary boundary,
  }) async {
    queued.add((revision: revision, tempo: tempo, boundary: boundary));
  }

  @override
  Future<TransportStatus> status() async => TransportStatus(
    playing: playing,
    revision: revision,
    targetRevision: queued.isEmpty ? revision : queued.last.revision,
    fraction: .125,
    tempo: tempo,
  );
  @override
  Future<void> play() async {
    plays++;
    playing = true;
  }

  @override
  Future<void> pause() async {
    playing = false;
  }

  @override
  Future<void> stop() async {
    playing = false;
  }

  @override
  Future<double> positionSeconds() async => .5;
  @override
  Future<bool> isPlaying() async => playing;
  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }
}

class DelayedPreparationAudio extends TestAudio {
  final firstPreparation = Completer<void>();
  int starts = 0;
  @override
  Future<void> prepare(
    Int16List pcm, {
    int revision = 0,
    int tempo = 120,
  }) async {
    starts++;
    if (starts == 1) await firstPreparation.future;
    await super.prepare(pcm, revision: revision, tempo: tempo);
  }
}

class PreparationFailureAudio extends TestAudio {
  @override
  Future<void> prepare(
    Int16List pcm, {
    int revision = 0,
    int tempo = 120,
  }) async {
    prepares++;
    throw PlatformException(
      code: 'audio_unavailable',
      message: 'Audio output unavailable. Please retry.',
    );
  }
}

void main() {
  testWidgets('Draw, undo, redo, save, Back, reopen and tabs', (tester) async {
    final repo = MemoryRepository();
    final audio = TestAudio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(
              const UserPreferences(previewVolume: .25),
            ),
          ),
          repositoryProvider.overrideWith((ref) async => repo),
          audioEngineProvider.overrideWithValue(audio),
        ],
        child: const ScribbleSongApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New drawing'));
    await tester.pumpAndSettle();
    expect(find.text('Untitled drawing'), findsOneWidget);
    final canvas = find.byKey(const ValueKey('drawing-canvas'));
    final bounds = tester.getRect(canvas);
    final gesture = await tester.startGesture(
      Offset(bounds.left + bounds.width * .2, bounds.center.dy),
    );
    await gesture.moveTo(
      Offset(bounds.left + bounds.width * .8, bounds.center.dy),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('Undo'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byTooltip('Undo'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find
                .ancestor(
                  of: find.byTooltip('Play'),
                  matching: find.byType(IconButton),
                )
                .first,
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Redo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play'));
    for (var i = 0; i < 100 && !audio.playing; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(audio.prepares, 1);
    expect(audio.playing, isTrue);
    expect(audio.volume, .25);
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(audio.playing, isFalse);
    await tester.tap(find.byTooltip('Save drawing'));
    await tester.pumpAndSettle();
    expect(repo.documents.values.single.strokes.length, 1);
    expect(find.text('Saved on this device'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Untitled drawing'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DrawingCanvas>(find.byType(DrawingCanvas))
          .document
          .strokes
          .length,
      1,
    );
    await tester.tap(find.byTooltip('Back to gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Settings & help'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('Failed save keeps editor and artwork available for retry', (
    tester,
  ) async {
    final repo = MemoryRepository()..fail = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(),
          ),
          repositoryProvider.overrideWith((ref) async => repo),
          audioEngineProvider.overrideWithValue(TestAudio()),
        ],
        child: const ScribbleSongApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('New drawing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawing-canvas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to gallery'));
    await tester.pumpAndSettle();
    expect(find.byType(DrawingCanvas), findsOneWidget);
    expect(find.textContaining('Could not save this drawing.'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byTooltip('Save drawing'));
    await tester.pumpAndSettle();
    expect(repo.documents.values.single.strokes.length, 1);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('320 dp and 200 percent text keep editor controls operable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(),
          ),
          repositoryProvider.overrideWith((ref) async => MemoryRepository()),
          audioEngineProvider.overrideWithValue(TestAudio()),
        ],
        child: const ScribbleSongApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New drawing'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('drawing-canvas')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('drawing-canvas'))).height,
      greaterThan(50),
    );
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Native preparation failure leaves Play retryable and shows readable error',
    (tester) async {
      final audio = PreparationFailureAudio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            audioEngineProvider.overrideWithValue(audio),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('drawing-canvas')));
      await tester.pumpAndSettle();
      for (var attempt = 1; attempt <= 2; attempt++) {
        await tester.tap(find.byTooltip('Play'));
        for (var i = 0; i < 100 && audio.prepares < attempt; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
        }
        await tester.pump();
        expect(audio.prepares, attempt);
        expect(audio.playing, isFalse);
        expect(
          find.textContaining(
            'Could not play. Audio output unavailable. Please retry.',
          ),
          findsOneWidget,
        );
        expect(find.textContaining('PlatformException'), findsNothing);
        expect(find.byTooltip('Pause'), findsNothing);
        expect(
          tester
              .widget<IconButton>(
                find
                    .ancestor(
                      of: find.byTooltip('Play'),
                      matching: find.byType(IconButton),
                    )
                    .first,
              )
              .onPressed,
          isNotNull,
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'Drawing and tempo updates keep transport playing until native boundary acknowledgement',
    (tester) async {
      final audio = TestAudio();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            repositoryProvider.overrideWith((ref) async => MemoryRepository()),
            audioEngineProvider.overrideWithValue(audio),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('New drawing'));
      await tester.pumpAndSettle();
      final canvas = find.byKey(const ValueKey('drawing-canvas'));
      await tester.tap(canvas);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Play'));
      for (var i = 0; i < 100 && !audio.playing; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(audio.playing, isTrue);
      await tester.tapAt(tester.getTopLeft(canvas) + const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 150));
      for (var i = 0; i < 100 && audio.queued.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(audio.queued.last.boundary, UpdateBoundary.loop);
      expect(audio.playing, isTrue);
      expect(audio.prepares, 1);
      expect(find.text('Updates next loop'), findsOneWidget);
      audio.revision = audio.queued.last.revision;
      await tester.pump(const Duration(milliseconds: 60));
      await tester.pump();
      expect(find.text('Updates next loop'), findsNothing);
      await tester.tap(find.byTooltip('Faster'));
      await tester.pump(const Duration(milliseconds: 150));
      for (var i = 0; i < 100 && audio.queued.length < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(audio.queued.last.boundary, UpdateBoundary.beat);
      expect(audio.queued.last.tempo, 121);
      expect(audio.playing, isTrue);
      expect(audio.prepares, 1);
      expect(find.text('Updates next beat'), findsOneWidget);
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byTooltip('Faster'));
      }
      await tester.pump(const Duration(milliseconds: 150));
      for (var i = 0; i < 100 && audio.queued.length < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(audio.queued.length, 3);
      expect(audio.queued.last.tempo, 124);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      expect(audio.playing, isFalse);
      await tester.tap(find.byTooltip('Play'));
      await tester.pump();
      expect(audio.playing, isTrue);
      expect(audio.prepares, 1);
      await tester.tap(find.byTooltip('Pause'));
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('Multiple strokes within one frame are retained', (tester) async {
    final repository = MemoryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(),
          ),
          repositoryProvider.overrideWith((ref) async => repository),
          audioEngineProvider.overrideWithValue(TestAudio()),
        ],
        child: const ScribbleSongApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New drawing'));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(
      find.byKey(const ValueKey('drawing-canvas')),
    );
    for (var i = 0; i < 3; i++) {
      await tester.tapAt(origin + Offset(10 + i * 10, 10));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save drawing'));
    await tester.pumpAndSettle();
    expect(repository.documents.values.single.strokes.length, 3);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets(
    'Draft rename, duplicate, delete and Undo preserve original identity',
    (tester) async {
      final repository = MemoryRepository();
      await repository.save(
        ProjectDocument(id: 'library-test', title: 'Original song'),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(),
            ),
            repositoryProvider.overrideWith((ref) async => repository),
            audioEngineProvider.overrideWithValue(TestAudio()),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Library'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Manage Original song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rename'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Renamed song');
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(repository.documents['library-test']!.title, 'Renamed song');
      await tester.tap(find.byTooltip('Manage Renamed song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duplicate'));
      await tester.pumpAndSettle();
      expect(repository.documents.length, 2);
      expect(find.text('Renamed song copy'), findsOneWidget);
      await tester.tap(find.byTooltip('Manage Renamed song'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(repository.deleted, contains('library-test'));
      expect(find.text('Renamed song'), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(repository.deleted, isEmpty);
      expect(find.text('Renamed song'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('edits during native preparation start only the latest score', (
    tester,
  ) async {
    final audio = DelayedPreparationAudio();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          preferencesStoreProvider.overrideWith(
            (ref) async => MemoryPreferencesStore(),
          ),
          repositoryProvider.overrideWith((ref) async => MemoryRepository()),
          audioEngineProvider.overrideWithValue(audio),
        ],
        child: const ScribbleSongApp(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('New drawing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawing-canvas')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Play'));
    for (var i = 0; i < 100 && audio.starts == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(audio.starts, 1);
    await tester.tap(find.byTooltip('Faster'));
    await tester.pump();
    audio.firstPreparation.complete();
    for (var i = 0; i < 100 && !audio.playing; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(audio.playing, isTrue);
    expect(audio.starts, 2);
    expect(audio.plays, 1);
    final document = tester
        .widget<DrawingCanvas>(find.byType(DrawingCanvas))
        .document;
    expect(audio.revision, document.revision);
    expect(audio.tempo, 121);
    await tester.pumpWidget(const SizedBox());
  });
}
