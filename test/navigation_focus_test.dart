import 'package:flutter/material.dart';
import 'package:scribblesong/design_system/creative_dock.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:scribblesong/app/providers.dart';
import 'package:scribblesong/design_system/creative_panel.dart';
import 'package:scribblesong/features/library/domain/project_repository.dart';
import 'package:scribblesong/features/settings/application/settings_controller.dart';
import 'package:scribblesong/features/settings/domain/preferences.dart';
import 'package:scribblesong/features/settings/presentation/settings_page.dart';

import 'support/memory_preferences.dart';

import 'package:scribblesong/app/app.dart';

void main() {
  testWidgets(
    'hidden retained branch cannot receive keyboard edits and remains usable on return',
    (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      var index = 0, value = .5;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return RetainedBranchContainer(
                  index: index,
                  children: [
                    Center(
                      child: Slider(
                        focusNode: focus,
                        value: value,
                        onChanged: (v) => setState(() => value = v),
                      ),
                    ),
                    const Center(child: Text('Visible second branch')),
                  ],
                );
              },
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, greaterThan(.5));
      update(() => index = 1);
      await tester.pumpAndSettle();
      final before = value;
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        value,
        before,
        reason: 'Hidden settings-like slider must not process keyboard input.',
      );
      expect(focus.hasFocus, isFalse);
      update(() => index = 0);
      await tester.pumpAndSettle();
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(value, closeTo(before + .05, .000001));
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'a branch creative panel owns the global barrier and Back restores its originating branch',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(
                const UserPreferences(reduceMotion: true),
              ),
            ),
            libraryProvider.overrideWith(
              (ref) async => const ProjectListing([], []),
            ),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final origin = tester.state(find.byType(SettingsPage));
      final context = tester.element(find.byType(SettingsPage));
      final closed = showCreativePanel<void>(
        context: context,
        isDismissible: false,
        builder: (_) => const CreativePanel(
          title: 'Modal creative panel',
          child: Text('Bounded owned content'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Modal creative panel').hitTestable(), findsOneWidget);
      await tester.tapAt(tester.getCenter(find.text('Home')));
      await tester.pumpAndSettle();
      expect(
        find.text('Modal creative panel').hitTestable(),
        findsOneWidget,
        reason: 'A modal must absorb dock taps instead of disappearing with a hidden branch.',
      );
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      await closed;
      expect(find.text('Modal creative panel'), findsNothing);
      expect(tester.state(find.byType(SettingsPage)), same(origin));
      expect(
        tester.widget<CreativeDock>(find.byType(CreativeDock)).selectedIndex,
        2,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'dismissible root panel absorbs a dock tap as dismissal without switching branches',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            preferencesStoreProvider.overrideWith(
              (ref) async => MemoryPreferencesStore(
                const UserPreferences(reduceMotion: true),
              ),
            ),
            libraryProvider.overrideWith(
              (ref) async => const ProjectListing([], []),
            ),
          ],
          child: const ScribbleSongApp(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      final origin = tester.state(find.byType(SettingsPage));
      final closed = showCreativePanel<void>(
        context: tester.element(find.byType(SettingsPage)),
        builder: (_) => const CreativePanel(
          title: 'Dismissible creative panel',
          child: Text('Owned modal state'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('Home')));
      await tester.pumpAndSettle();
      await closed;
      expect(find.text('Dismissible creative panel'), findsNothing);
      expect(tester.state(find.byType(SettingsPage)), same(origin));
      expect(
        tester.widget<CreativeDock>(find.byType(CreativeDock)).selectedIndex,
        2,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
