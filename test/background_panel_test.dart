import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scribblesong/design_system/paper_panel.dart';
import 'package:scribblesong/features/backgrounds/domain/background.dart';

void main() {
  const channel = MethodChannel('scribblesong/backgrounds');
  Future<void> open(
    WidgetTester tester,
    ValueChanged<BackgroundDefinition?> result,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => result(
                await showBackgroundPanel(
                  context,
                  BackgroundDefinition.solid(0xfff7f5eb),
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'recover') return null;
          if (call.method == 'capture') {
            throw PlatformException(code: 'camera_unavailable');
          }
          return {'cancelled': true};
        });
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null),
  );
  testWidgets(
    'background preview Cancel preserves document and Apply returns original gradient transaction',
    (tester) async {
      BackgroundDefinition? result;
      await open(tester, (value) => result = value);
      await tester.tap(find.byKey(const ValueKey('background-mode-gradient')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('background-mode-gradient')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('background-gradient-radial')),
      );
      await tester.tap(
        find.byKey(const ValueKey('background-gradient-radial')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.kind, BackgroundKind.radial);
      expect(result!.colors.length, 2);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'camera unavailable and canceled picker keep the editable paper and reachable actions',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      BackgroundDefinition? result;
      await open(tester, (value) => result = value);
      await tester.ensureVisible(
        find.byKey(const ValueKey('background-mode-photo')),
      );
      await tester.tap(find.byKey(const ValueKey('background-mode-photo')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Take photo'));
      await tester.tap(find.text('Take photo'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No camera app is available. You can choose a photo instead.',
        ),
        findsOneWidget,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('background-mode-photo')),
      );
      await tester.tap(find.byKey(const ValueKey('background-mode-photo')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Choose photo'));
      await tester.tap(find.text('Choose photo'));
      await tester.pumpAndSettle();
      expect(find.text('Apply').hitTestable(), findsOneWidget);
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(result!.kind, BackgroundKind.solid);
      expect(result!.opacity, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
