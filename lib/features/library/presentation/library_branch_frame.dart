import 'package:flutter/material.dart';

import '../../../design_system/immersive_surface.dart';
import '../../../design_system/creative_components.dart';
import '../../../design_system/retained_transition.dart';
import 'library_gallery_layout.dart';
import 'library_tabs.dart';

/// One persistent selector surrounds both retained library navigators.
class LibraryBranchFrame extends StatefulWidget {
  const LibraryBranchFrame({
    super.key,
    required this.section,
    required this.children,
  });

  final int? section;
  final List<Widget> children;

  @override
  State<LibraryBranchFrame> createState() => _LibraryBranchFrameState();
}

class _LibraryBranchFrameState extends State<LibraryBranchFrame> {
  late int _section = widget.section ?? 0;

  @override
  void didUpdateWidget(LibraryBranchFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.section != null) _section = widget.section!;
  }

  @override
  Widget build(BuildContext context) => SceneBackdrop(
    child: SafeArea(
      bottom: false,
      child: LayoutBuilder(
        builder: (context, bounds) {
          // Preserve the existing all-content-scrolls fallback for IME/short
          // windows; never impose a fixed-height header on large translated text.
          final shared = bounds.maxHeight >= 260;
          final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
          // Optional branding never consumes the compact large-text gallery.
          // Settings/help remain reachable through the retained root dock.
          final showBrand =
              !(largeText && bounds.maxWidth < 600) &&
              bounds.maxHeight >= (largeText ? 480 : 360);
          return Column(
            children: [
              if (shared && showBrand)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: StudioHeader(),
                ),
              if (shared)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: LibraryTabs(exports: _section == 1),
                ),
              Expanded(
                child: LibraryChromeScope(
                  shared: shared,
                  child: RetainedBranchContainer(
                    index: _section,
                    opaquePages: !shared,
                    children: widget.children,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );
}
