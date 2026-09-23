import 'package:flutter/material.dart';
import '../models/app_models.dart';

class ThemeColors {
  const ThemeColors({required this.primary, required this.secondary, required this.accent, required this.glow});
  final Color primary;
  final Color secondary;
  final Color accent;
  final Color glow;
}

ThemeColors colorsFor(AppThemeChoice choice) => switch (choice) {
      AppThemeChoice.turquoise => const ThemeColors(primary: Color(0xFF19E0CE), secondary: Color(0xFF0A9FCE), accent: Color(0xFF8BFFFF), glow: Color(0xFF11DCC9)),
      AppThemeChoice.sky => const ThemeColors(primary: Color(0xFF61C8FF), secondary: Color(0xFF4778FF), accent: Color(0xFFB9EAFF), glow: Color(0xFF61C8FF)),
      AppThemeChoice.red => const ThemeColors(primary: Color(0xFFFF4D67), secondary: Color(0xFFB91F52), accent: Color(0xFFFFA0AB), glow: Color(0xFFFF4163)),
      AppThemeChoice.blue => const ThemeColors(primary: Color(0xFF4E8CFF), secondary: Color(0xFF1E48D8), accent: Color(0xFFA6C8FF), glow: Color(0xFF508BFF)),
    };

class AppPalette { static const page = Color(0xFF05070C); static const surface = Color(0xFF0A101A); static const surface2 = Color(0xFF0D1522); static const card = Color(0xFF0B121D); }

ThemeData buildDarkTheme(AppThemeChoice choice) {
  final c = colorsFor(choice);
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppPalette.page,
    canvasColor: AppPalette.page,
    cardColor: AppPalette.card,
    colorScheme: ColorScheme.dark(
      primary: c.primary,
      secondary: c.secondary,
      surface: AppPalette.surface,
    ).copyWith(
      surfaceContainerLowest: AppPalette.page,
      surfaceContainerLow: AppPalette.surface,
      surfaceContainer: AppPalette.surface2,
      surfaceContainerHigh: AppPalette.card,
      surfaceContainerHighest: AppPalette.card,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: AppPalette.page,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      elevation: 0,
      foregroundColor: Colors.white,
      iconTheme: const IconThemeData(color: Colors.white),
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppPalette.surface,
      surfaceTintColor: Colors.transparent,
    ),
    splashFactory: InkSparkle.splashFactory,
    navigationBarTheme: NavigationBarThemeData(
      height: 76,
      backgroundColor: const Color(0xFF03060A),
      indicatorColor: c.primary.withValues(alpha: .18),
      labelTextStyle: WidgetStatePropertyAll(const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      iconTheme: WidgetStatePropertyAll(IconThemeData(color: Colors.white.withValues(alpha: .8))),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppPalette.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: Colors.white.withValues(alpha: .05))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide(color: c.primary.withValues(alpha: .7), width: 1.4)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    cardTheme: const CardThemeData(color: AppPalette.card, margin: EdgeInsets.zero),
  );
}
