import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';
import 'package:scribblesong/design_system/theme.dart';
import 'package:scribblesong/features/composition/domain/score.dart';
import 'package:scribblesong/features/editor/presentation/playback_intersections.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';

void main() {
  ProjectDocument timed(
    int ms, {
    ExpressionMode mode = ExpressionMode.geometry,
  }) => ProjectDocument(
    id: 'dynamic',
    expressionMode: mode,
    strokes: [
      Stroke(
        id: 'line',
        instrument: Instrument.keys,
        points: [InkPoint(.1, .5, 0), InkPoint(.9, .5, ms)],
      ),
    ],
  );
  test('speed affects only explicitly enabled dynamics; all exports consume velocities', () {
    expect(
      compileScore(timed(200)).notes.map((n) => n.velocity),
      compileScore(timed(2000)).notes.map((n) => n.velocity),
    );
    final fast = compileScore(timed(200, mode: ExpressionMode.expressive));
    final slow = compileScore(timed(2000, mode: ExpressionMode.expressive));
    expect(fast.notes.single.velocity, 110);
    expect(slow.notes.single.velocity, 77);
    expect(fast.notes.single.fixture, slow.notes.single.fixture);
    final stylus = timed(200).copyWith(
      expressionMode: ExpressionMode.expressive,
      strokes: [
        Stroke(
          id: 'pen',
          instrument: Instrument.keys,
          points: [
            InkPoint.input(.1, .5, pressure: 0, kind: InputKind.stylus),
            InkPoint.input(
              .9,
              .5,
              ms: 200,
              pressure: 1,
              kind: InputKind.stylus,
            ),
          ],
        ),
      ],
    );
    expect(compileScore(stylus).notes.single.velocity, 83);
    expect(
      ProjectDocument.decode(stylus.encode()).expressionMode,
      ExpressionMode.expressive,
    );
  });
  test('dark preference persists and dark text meets contrast target', () {
    final p = UserPreferences.fromJson(
      const UserPreferences(darkTheme: true).toJson(),
    );
    expect(p.darkTheme, isTrue);
    final colors = buildTheme(brightness: Brightness.dark).colorScheme;
    final contrast =
        (colors.onSurface.computeLuminance() + .05) /
        (colors.surface.computeLuminance() + .05);
    expect(contrast, greaterThan(4.5));
  });
  test(
    'intersection visual index preserves verticals dots and bounds output',
    () {
      final doc = ProjectDocument(
        id: 'index',
        strokes: [
          Stroke(
            id: 'chord',
            instrument: Instrument.bell,
            points: [InkPoint(.25, .2), InkPoint(.25, .8)],
          ),
          Stroke(
            id: 'dot',
            instrument: Instrument.keys,
            points: [InkPoint(.75, .5)],
          ),
        ],
      );
      final index = indexIntersections(doc);
      expect(index.length, 96);
      expect(index[24].length, 2);
      expect(index[72].single.$2, .5);
      expect(index.every((b) => b.length <= 32), isTrue);
    },
  );
}
