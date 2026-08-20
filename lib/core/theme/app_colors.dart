import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF1D4ED8);

  // Secondary
  static const Color secondary = Color(0xFF3B82F6);

  // Status
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // On-light status text — the base status colors fail WCAG AA contrast on
  // white (green ≈2.3:1, amber ≈2.1:1, red ≈3.6:1). These darker variants
  // are for text/icon use on light backgrounds; the vivid colors stay for
  // fills, chips and dark-mode text.
  static const Color successText = Color(0xFF15803D);
  static const Color warningText = Color(0xFFB45309);
  static const Color dangerText = Color(0xFFB91C1C);

  /// Resolves a status color for text use on the current surface: the vivid
  /// brand color in dark mode, the darker AA-compliant variant on light.
  static Color statusText(Color color, bool dark) {
    if (dark) return color;
    if (color == success) return successText;
    if (color == warning) return warningText;
    if (color == danger) return dangerText;
    return color;
  }

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFF1F5F9);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color surface2Dark = Color(0xFF16203A);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFF1F5F9);
  static const Color textDarkSecondary = Color(0xFF94A3B8);

  // Borders
  static const Color borderLight = Color(0xFFE2E8F0);
  static const Color borderDark = Color(0xFF334155);

  /// Theme-aware dim text colour (secondary text on the current surface).
  /// Hardcoded `textSecondary` on a dark surface reads muddy — always route
  /// secondary text through this so light/dark both stay readable.
  static Color dim(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? textDarkSecondary
          : textSecondary;

  /// Theme-aware border/line colour for dividers, grids and outlines.
  static Color line(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? borderDark
          : borderLight;

  /// Theme-aware elevated surface (card fill).
  static Color surface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? surfaceDark
          : surfaceLight;

  // Sidebar
  static const Color sidebarLight = Color(0xFFFFFFFF);
  static const Color sidebarDark = Color(0xFF0F172A);
  static const Color sidebarItemHover = Color(0xFFF1F5F9);
  static const Color sidebarItemActive = Color(0xFFEFF6FF);
  static const Color sidebarItemActiveDark = Color(0xFF1E3A5F);

  // Chart colors
  static const List<Color> chartColors = [
    Color(0xFF2563EB),
    Color(0xFF22C55E),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFF06B6D4),
    Color(0xFF84CC16),
  ];

  // KPI card colors
  static const Color kpiEnergy = Color(0xFF2563EB);
  static const Color kpiPower = Color(0xFF8B5CF6);
  static const Color kpiDemand = Color(0xFFF59E0B);
  static const Color kpiCost = Color(0xFF22C55E);
  static const Color kpiSavings = Color(0xFF06B6D4);
  static const Color kpiEfficiency = Color(0xFFEC4899);
  static const Color kpiCO2 = Color(0xFF84CC16);
}
