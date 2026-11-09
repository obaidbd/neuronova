import 'package:flutter/material.dart';

class NovaColors {
  static const background = Color(0xFF101F35);
  static const surface = Color(0xFF182D48);
  static const emerald = Color(0xFF36C9A1);
  static const gold = Color(0xFFF2C66D);
  static const blue = Color(0xFF5D9CFF);
  static const text = Color(0xFFF7F9FF);
  static const textSecondary = Color(0xFFACBED3);
  static const danger = Color(0xFFF4767F);
}

ThemeData novaTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: NovaColors.emerald,
    brightness: Brightness.dark,
    surface: NovaColors.surface,
  );
  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: NovaColors.background,
    useMaterial3: true,
    textTheme: ThemeData.dark().textTheme.apply(
          bodyColor: NovaColors.text,
          displayColor: NovaColors.text,
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, 52),
        backgroundColor: NovaColors.emerald,
        foregroundColor: NovaColors.background,
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
  );
}
