import 'package:flutter/material.dart';

import 'motion.dart';
import 'layout.dart';
import 'typography.dart';
import 'brand_colors.dart';

// Document paper/instrument colors are defined by the document, not this theme.
const ink = Color(0xff223c35);
const paper = Color(0xfff7f5eb);
const accent = Color(0xff167d73);

ThemeData buildTheme({Brightness brightness = Brightness.light}) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: DoodimoColors.ink,
    brightness: brightness,
    primary: dark ? DoodimoColors.lime : DoodimoColors.ink,
    onPrimary: dark ? DoodimoColors.ink : DoodimoColors.paper,
    surface: dark ? const Color(0xff172622) : const Color(0xfff8f7f3),
    onSurface: dark ? const Color(0xfff1f3eb) : ink,
    onSurfaceVariant: dark ? const Color(0xffbbc9bf) : const Color(0xff50645c),
    surfaceContainerLow: dark
        ? const Color(0xff22372d)
        : const Color(0xffefeee8),
    surfaceContainerHighest: dark
        ? const Color(0xff30443b)
        : const Color(0xffe8e8df),
    primaryContainer: dark ? const Color(0xff324b38) : DoodimoColors.lime,
    onPrimaryContainer: dark ? DoodimoColors.lime : DoodimoColors.ink,
    secondaryContainer: dark ? const Color(0xff353c49) : DoodimoColors.lavender,
    onSecondaryContainer: dark
        ? const Color(0xffe8e2f3)
        : const Color(0xff49405f),
    tertiary: dark ? const Color(0xffe8ad99) : const Color(0xff9b4d39),
    outline: dark ? const Color(0xff8c9f94) : const Color(0xff73877b),
    outlineVariant: dark ? const Color(0xff3f5148) : const Color(0xffd7dfd6),
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
      color: dark ? const Color(0xff21342c) : const Color(0xfffffefb),
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
        minimumSize: const Size(
          CreativeSize.touchTarget,
          CreativeSize.touchTarget,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xff21342c) : const Color(0xfffffefb),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(CreativeRadius.control),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dark ? const Color(0xff21342c) : const Color(0xfffffefb),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(CreativeRadius.panel),
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dark ? const Color(0xff21342c) : const Color(0xfffffefb),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(CreativeRadius.panel),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: dark ? const Color(0xff21342c) : const Color(0xfffffefb),
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
    return FadeTransition(
      opacity: eased,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(.025, .015),
          end: Offset.zero,
        ).animate(eased),
        child: child,
      ),
    );
  }
}
