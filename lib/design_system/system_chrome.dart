import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Transparent edge-to-edge chrome with icon contrast owned by the app theme.
/// iOS uses statusBarBrightness to describe the background; Android uses the
/// opposite statusBarIconBrightness to describe the foreground icons.
SystemUiOverlayStyle systemChromeFor(Brightness brightness) =>
    (brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark)
        .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
        );
