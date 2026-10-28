import 'package:flutter/material.dart';

import '../../../design_system/immersive_surface.dart';
import 'library_tabs.dart';

class LibraryChromeScope extends InheritedWidget {
  const LibraryChromeScope({
    super.key,
    required this.shared,
    required super.child,
  });
  final bool shared;
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LibraryChromeScope>()
          ?.shared ??
      false;
  @override
  bool updateShouldNotify(LibraryChromeScope oldWidget) =>
      oldWidget.shared != shared;
}

/// Keep navigation pinned when it leaves a usable gallery. During short local
/// constraints (including IME/rail transitions), the whole navigation and content
/// scroll together so neither text nor 48 dp actions can overflow the viewport.
class LibraryGalleryLayout extends StatelessWidget {
  const LibraryGalleryLayout({
    super.key,
    required this.exports,
    required this.scrollKey,
    required this.children,
  });
  final bool exports;
  final String scrollKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (LibraryChromeScope.of(context)) {
      return ListView(
        key: PageStorageKey(scrollKey),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        children: children,
      );
    }
    return SceneBackdrop(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final short = constraints.maxHeight < 260;
            final tabs = Padding(
              padding: EdgeInsets.fromLTRB(20, short ? 8 : 16, 20, 0),
              child: LibraryTabs(exports: exports),
            );
            final content = ListView(
              key: PageStorageKey(scrollKey),
              padding: EdgeInsets.fromLTRB(
                short ? 0 : 20,
                short ? 0 : 20,
                short ? 0 : 20,
                140,
              ),
              children: short
                  ? [
                      tabs,
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: children,
                        ),
                      ),
                    ]
                  : children,
            );
            return short
                ? content
                : Column(
                    children: [
                      tabs,
                      Expanded(child: content),
                    ],
                  );
          },
        ),
      ),
    );
  }
}
