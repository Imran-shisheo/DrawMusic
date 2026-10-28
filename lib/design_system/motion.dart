import 'package:flutter/material.dart';

abstract final class CreativeMotion {
  static const press = Duration(milliseconds: 120);
  static const selection = Duration(milliseconds: 180);
  static const branch = Duration(milliseconds: 260);
  static const forward = Duration(milliseconds: 320);
  static const reverse = Duration(milliseconds: 240);
  static const sheet = Duration(milliseconds: 300);
  static const ambient = Duration(seconds: 16);
  static const curve = Curves.easeOutCubic;

  static Duration duration(BuildContext context, Duration value) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;
}
