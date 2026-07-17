import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PowerTheme {
  // Colors
  static const Color lime = Color(0xFFC3D809);
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F9E4);
  static const Color border = Color(0xFFE4E6D0);
  static const Color textPrimary = Color(0xFF3A3A32);
  static const Color textMuted = Color(0xFF8A8C7E);
  static const Color danger = Color(0xFFD64545);
  static const Color onLime = Color(0xFF565A3E);

  static ThemeData get theme => _lightTheme;

  static final ThemeData _lightTheme = _buildTheme(Brightness.light);
  static final ThemeData _darkTheme = _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: isDark ? const Color(0xFF1A1A18) : white,
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: lime,
        onPrimary: onLime,
        secondary: isDark ? const Color(0xFF9DAF00) : const Color(0xFF9DAF00),
        onSecondary: onLime,
        surface: isDark ? const Color(0xFF242422) : white,
        error: danger,
        onError: white,
        onSurface: isDark ? const Color(0xFFE8E8DC) : textPrimary,
      ),
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: TextTheme(
        headlineLarge: GoogleFonts.sora(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFE8E8DC) : textPrimary,
        ),
        headlineMedium: GoogleFonts.sora(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFFE8E8DC) : textPrimary,
        ),
        titleLarge: GoogleFonts.sora(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE8E8DC) : textPrimary,
        ),
        titleMedium: GoogleFonts.sora(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE8E8DC) : textPrimary,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: isDark ? const Color(0xFFD0D0C4) : textPrimary,
        ),
        bodyMedium: GoogleFonts.inter(
          fontSize: 14,
          color: isDark ? const Color(0xFFD0D0C4) : textPrimary,
        ),
        labelLarge: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? const Color(0xFFE8E8DC) : textPrimary,
        ),
        labelSmall: GoogleFonts.inter(
          fontSize: 12,
          color: isDark ? const Color(0xFF8A8C7E) : textMuted,
        ),
      ),
    );
  }

  static ThemeData get darkTheme => _darkTheme;
}

class PowerTextStyles {
  static TextStyle mono({
    double size = 14,
    FontWeight weight = FontWeight.w600,
    Color color = PowerTheme.textPrimary,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle heading({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = PowerTheme.textPrimary,
  }) {
    return GoogleFonts.sora(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.normal,
    Color color = PowerTheme.textPrimary,
  }) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color,
    );
  }
}
