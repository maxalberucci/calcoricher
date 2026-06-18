import 'package:flutter/material.dart';

/// Luxuriöses Dunkel-Gold-Theme für den Reichen-Rechner.
class AppTheme {
  AppTheme._();

  // Gold-Palette
  static const Color gold = Color(0xFFD4AF37);
  static const Color goldLight = Color(0xFFFFE89A);
  static const Color goldDark = Color(0xFF9A7B1A);

  // Dunkle Palette
  static const Color background = Color(0xFF0A0A0B);
  static const Color surface = Color(0xFF161618);
  static const Color card = Color(0xFF1F1F22);
  static const Color cardHigh = Color(0xFF2A2A2E);
  static const Color divider = Color(0xFF323236);

  // Text
  static const Color textPrimary = Color(0xFFF6F4EE);
  static const Color textSecondary = Color(0xFF9A968B);

  // Medaillen
  static const Color silver = Color(0xFFC0C0C0);
  static const Color bronze = Color(0xFFCD7F32);

  /// Goldverlauf für edle Buttons und Akzente.
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [goldLight, gold, goldDark],
  );

  /// Tiefer Hintergrundverlauf (oben minimal heller).
  static const RadialGradient backgroundGradient = RadialGradient(
    center: Alignment(0, -0.7),
    radius: 1.3,
    colors: [Color(0xFF1A1A1E), background],
  );

  /// Weicher Schatten mit Goldschimmer für hervorgehobene Elemente.
  static List<BoxShadow> goldGlow({double opacity = 0.25, double blur = 18}) =>
      [
        BoxShadow(
          color: gold.withValues(alpha: opacity),
          blurRadius: blur,
          spreadRadius: -2,
        ),
      ];

  static final ThemeData darkGoldTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    colorScheme: const ColorScheme.dark(
      primary: gold,
      secondary: goldLight,
      surface: surface,
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      onSurface: textPrimary,
      error: Color(0xFFE05A5A),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: gold,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: gold,
        fontSize: 20,
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
    ),
    cardTheme: CardThemeData(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: goldDark, width: 0.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: gold,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1.2,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: gold),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: gold, fontWeight: FontWeight.bold),
      displayMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
      headlineMedium: TextStyle(color: gold, fontWeight: FontWeight.w600),
      bodyLarge: TextStyle(color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary),
      labelLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cardHigh,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: goldDark),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: goldDark),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: gold, width: 2),
      ),
      labelStyle: const TextStyle(color: textSecondary),
      hintStyle: const TextStyle(color: textSecondary),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: cardHigh,
      contentTextStyle: TextStyle(color: textPrimary),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: surface,
      selectedItemColor: gold,
      unselectedItemColor: textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    dividerColor: divider,
  );
}
