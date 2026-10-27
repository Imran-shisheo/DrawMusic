import 'package:flutter/material.dart';

const ink = Color(0xff243b35);
const paper = Color(0xfff7f5eb);
const accent = Color(0xff007e73);

ThemeData buildTheme({Brightness brightness = Brightness.light}) => ThemeData(
  brightness: brightness,
  useMaterial3: true,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: {
      TargetPlatform.android: AccessiblePageTransitions(),
      TargetPlatform.iOS: AccessiblePageTransitions(),
    },
  ),
  scaffoldBackgroundColor: brightness == Brightness.dark
      ? const Color(0xff151f1d)
      : const Color(0xfffffdf5),
  colorScheme: ColorScheme.fromSeed(
    seedColor: accent,
    brightness: brightness,
    primary: brightness == Brightness.dark ? const Color(0xff70d5c5) : accent,
    onSurface: brightness == Brightness.dark ? const Color(0xffecf4ef) : ink,
    surface: brightness == Brightness.dark
        ? const Color(0xff151f1d)
        : const Color(0xfffffdf5),
  ),
  appBarTheme: AppBarTheme(
    backgroundColor: brightness == Brightness.dark
        ? const Color(0xff151f1d)
        : const Color(0xfffffdf5),
    foregroundColor: brightness == Brightness.dark
        ? const Color(0xffecf4ef)
        : ink,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: brightness == Brightness.dark
        ? const Color(0xff24332f)
        : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
  ),
);

class AccessiblePageTransitions extends PageTransitionsBuilder {
  const AccessiblePageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return const FadeUpwardsPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
