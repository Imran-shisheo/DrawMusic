import 'package:flutter/material.dart';

const ink = Color(0xff243b35);
const paper = Color(0xfff7f5eb);
const accent = Color(0xff007e73);

ThemeData buildTheme() => ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xfffffdf5),
  colorScheme: ColorScheme.fromSeed(
    seedColor: accent,
    primary: accent,
    onSurface: ink,
    surface: const Color(0xfffffdf5),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xfffffdf5),
    foregroundColor: ink,
  ),
  cardTheme: const CardThemeData(
    elevation: 0,
    color: Colors.white,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(20)),
    ),
  ),
);
