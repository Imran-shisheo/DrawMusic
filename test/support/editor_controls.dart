import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/creative_document/document.dart';

Future<void> openEditorMusic(WidgetTester tester) async {
  final control = find.byKey(const ValueKey('music-settings'));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
}

Future<void> chooseEditorVoice(WidgetTester tester, Instrument voice) async {
  final control = find.byKey(const ValueKey('current-voice'));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('voice-${voice.name}'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}

Future<void> openEditorTool(WidgetTester tester, String tool) async {
  final control = find.byKey(const ValueKey('editor-tools'));
  await tester.ensureVisible(control);
  await tester.tap(control);
  await tester.pumpAndSettle();
  final tile = find.byKey(ValueKey('editor-tool-$tool'));
  await tester.ensureVisible(tile);
  await tester.tap(tile);
  await tester.pumpAndSettle();
}
