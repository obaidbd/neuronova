import 'package:flutter/material.dart';

class NovaColors {
  static const background = Color(0xFF0B1426);
  static const surface = Color(0xFF15243B);
  static const emerald = Color(0xFF56DFC3);
  static const gold = Color(0xFFFFD27A);
  static const blue = Color(0xFF7AA9FF);
  static const text = Color(0xFFF5F8FF);
  static const textSecondary = Color(0xFFADBED4);
  static const danger = Color(0xFFFF8D9B);
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
    appBarTheme: const AppBarTheme(
      backgroundColor: NovaColors.background,
      foregroundColor: NovaColors.text,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: DividerThemeData(
      color: NovaColors.textSecondary.withValues(alpha: .15),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: NovaColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    textTheme: ThemeData.dark().textTheme.apply(
      bodyColor: NovaColors.text,
      displayColor: NovaColors.text,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, 52),
        backgroundColor: NovaColors.emerald,
        foregroundColor: NovaColors.background,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        enableFeedback: true,
      ),
    ),
  );
}
