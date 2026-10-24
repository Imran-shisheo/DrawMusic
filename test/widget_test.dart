import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/app/app.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/features/editor/presentation/canvas.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/transport/domain/audio_engine.dart';

class MemoryRepository implements ProjectRepository {
  final documents = <String, ProjectDocument>{};
  bool fail = false;
  @override
  Future<void> save(ProjectDocument doc) async {
    if (fail) throw StateError('Disk full');
    documents[doc.id] = doc;
  }

  @override
  Future<ProjectDocument> load(String id) async => documents[id]!;
  @override
  Future<ProjectListing> list() async =>
      ProjectListing(documents.values.toList(), []);
}

class TestAudio implements AudioEngine {
  int prepares = 0;
  bool playing = false;
  @override
  Future<void> prepare(Int16List pcm) async {
    prepares++;
    expect(pcm.any((n) => n != 0), isTrue);
  }

  @override
  Future<void> play() async {
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
  Future<void> setVolume(double value) async {}
}

class PreparationFailureAudio extends TestAudio {
  @override
  Future<void> prepare(Int16List pcm) async {
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
    await tester.tap(find.byTooltip('Pause'));
    await tester.pump();
    expect(audio.playing, isFalse);
    await tester.tap(find.byTooltip('Save drawing'));
    await tester.pumpAndSettle();
    expect(repo.documents.values.single.strokes.length, 1);
    expect(find.text('Saved on this device'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Drafts'));
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
}
