import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const bg = Color(0xff07121C);
  static const card = Color(0xff0B1927);
  static const surfaceHover = Color(0xff0E2030);
  static const border = Color(0xff263B4E);
  static const borderStrong = Color(0xff355068);
  static const divider = Color(0xff1B3042);
  static const track = Color(0xff203749);

  static const text = Color(0xffF2F6FA);
  static const secondary = Color(0xff9AAFC0);
  static const muted = Color(0xff6F8598);

  static const cyan = Color(0xff22D3E6);
  static const cyanMuted = Color(0xff123D4A);
  static const purple = Color(0xffA78BFA);
  static const green = Color(0xff4FD39A);
  static const warning = Color(0xffD9A85A);
  static const error = Color(0xffE87886);
}

abstract final class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double radius = 16;
}

abstract final class AppText {
  static const String mono = 'Roboto Mono';
}

ThemeData monitorTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.bg,
  colorScheme: const ColorScheme.dark(
    primary: AppColors.cyan,
    surface: AppColors.card,
  ),
  useMaterial3: true,
  dividerColor: AppColors.divider,
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.text),
    bodyMedium: TextStyle(color: AppColors.text),
    bodySmall: TextStyle(color: AppColors.muted),
  ),
);
