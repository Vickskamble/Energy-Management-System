import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTypography {
  AppTypography._();

  static TextTheme get light => TextTheme(
        displayLarge: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w700, letterSpacing: -1.5),
        displayMedium: GoogleFonts.inter(fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -1),
        displaySmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -0.5),
        headlineLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.25),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600),
        headlineSmall: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600),
        titleLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
        titleMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
        titleSmall: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
        bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5),
        bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, height: 1.5),
        bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.1),
        labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.1),
      );

  static TextTheme get dark => light;

  static TextStyle mono({double size = 14, FontWeight weight = FontWeight.w600, Color color = AppColors.textPrimary}) {
    return GoogleFonts.jetBrainsMono(fontSize: size, fontWeight: weight, color: color);
  }
}
