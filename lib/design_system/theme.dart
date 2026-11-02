import 'package:flutter/material.dart';

import 'motion.dart';
import 'layout.dart';
import 'typography.dart';
import 'brand_colors.dart';
import 'system_chrome.dart';

// Document paper/instrument colors are defined by the document, not this theme.
const ink = DoodimoColors.ink;
const paper = Color(
  0xfff7f5eb,
); // Legacy document paper, independent of chrome.
const accent = DoodimoColors.violet;

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: DoodimoColors.orange,
    brightness: brightness,
    primary: dark ? const Color(0xffffa465) : const Color(0xff9b400b),
    onPrimary: dark ? const Color(0xff25180e) : const Color(0xfffff8f0),
    primaryContainer: dark ? const Color(0xff5d351e) : const Color(0xffffdcc2),
    onPrimaryContainer: dark
        ? const Color(0xffffd7b6)
        : const Color(0xff3b210f),
    secondary: dark ? const Color(0xffd6b599) : const Color(0xff65513f),
    onSecondary: dark ? const Color(0xff231b14) : Colors.white,
    secondaryContainer: dark
        ? const Color(0xff3b3730)
        : const Color(0xffe8dccb),
    onSecondaryContainer: dark
        ? const Color(0xfff1e7da)
        : const Color(0xff30291f),
    tertiary: dark ? const Color(0xffc4d0c4) : const Color(0xff405a47),
    surface: dark ? DoodimoColors.ink : const Color(0xffeeeee7),
    onSurface: dark ? const Color(0xfff4f3ed) : const Color(0xff202624),
    onSurfaceVariant: dark ? const Color(0xffc4c7c0) : const Color(0xff4d5650),
    surfaceContainerLow: dark
        ? const Color(0xff1c2121)
        : const Color(0xfffaf9f2),
    surfaceContainerHigh: dark
        ? const Color(0xff2d3332)
        : const Color(0xffe2e5dd),
    surfaceContainerHighest: dark
        ? const Color(0xff3a403e)
        : const Color(0xffd7dcd3),
    outline: dark ? const Color(0xff959e97) : const Color(0xff6b766e),
    outlineVariant: dark ? const Color(0xff424b46) : const Color(0xffb8c1b6),
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: AppTypography.fontFamily,
    fontFamilyFallback: AppTypography.fallbacks,
    brightness: brightness,
  );
  final text = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge?.copyWith(
      fontFamily: AppTypography.displayFamily,
      fontFamilyFallback: [
        AppTypography.fontFamily,
        ...AppTypography.fallbacks,
      ],
      fontSize: 40,
      height: 1.08,
      fontWeight: FontWeight.w700,
      letterSpacing: -1,
    ),
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
      fontFamily: AppTypography.displayFamily,
      fontFamilyFallback: [
        AppTypography.fontFamily,
        ...AppTypography.fallbacks,
      ],
      fontSize: 32,
      height: 1.12,
      fontWeight: FontWeight.w700,
      letterSpacing: -.6,
    ),
    titleLarge: base.textTheme.titleLarge?.copyWith(
      fontFamily: AppTypography.displayFamily,
      fontFamilyFallback: [
        AppTypography.fontFamily,
        ...AppTypography.fallbacks,
      ],
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w600,
    ),
    titleMedium: base.textTheme.titleMedium?.copyWith(
      fontSize: 16,
      height: 1.35,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: base.textTheme.bodyLarge?.copyWith(fontSize: 16, height: 1.5),
    bodyMedium: base.textTheme.bodyMedium?.copyWith(fontSize: 14, height: 1.45),
    labelLarge: base.textTheme.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w600,
    ),
  );
  return base.copyWith(
    textTheme: text,
    scaffoldBackgroundColor: scheme.surface,
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: AccessiblePageTransitions(),
        TargetPlatform.iOS: AccessiblePageTransitions(),
      },
    ),
    appBarTheme: AppBarTheme(
      systemOverlayStyle: systemChromeFor(brightness),
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface),
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CreativeRadius.card),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(
          CreativeSize.touchTarget,
          CreativeSize.touchTarget,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CreativeRadius.control),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(
          CreativeSize.touchTarget,
          CreativeSize.touchTarget,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        foregroundColor: scheme.onSurface,
        shape: CircleBorder(side: BorderSide(color: scheme.outlineVariant)),
        minimumSize: const Size(
          CreativeSize.touchTarget,
          CreativeSize.touchTarget,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CreativeRadius.control),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CreativeRadius.panel),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CreativeRadius.panel),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => text.labelMedium?.copyWith(
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w700
              : FontWeight.w500,
        ),
      ),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: scheme.outlineVariant),
    ),
  );
}

class AccessiblePageTransitions extends PageTransitionsBuilder {
  const AccessiblePageTransitions();
  @override
  Duration get transitionDuration => CreativeMotion.forward;
  @override
  Duration get reverseTransitionDuration => CreativeMotion.reverse;
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final eased = animation.drive(CurveTween(curve: CreativeMotion.curve));
    return FadeTransition(opacity: eased, child: child);
  }
}
