import 'package:flutter/material.dart';

/// Central colour tokens. Feature code must reference these, never raw hex.
abstract final class AppColors {
  // Brand
  static const Color primary = Color(
    0xFF0F172A,
  ); // matches React active-nav slate
  static const Color primaryHover = Color(0xFF1E293B);
  static const Color onPrimary = Colors.white;
  static const Color accent = Color(0xFFB8892B); // bullion gold
  static const Color accentSoft = Color(0xFFFBF3E0);

  // Dark chrome (sidebar, brand panel)
  static const Color sidebar = Color(0xFF0B1220);
  static const Color sidebarRaised = Color(0xFF131C2E);
  static const Color sidebarBorder = Color(0xFF1F2A3F);
  static const Color sidebarText = Color(0xFF94A3B8);
  static const Color gradientEnd = Color(0xFF1B2740);

  // Surfaces
  static const Color background = Color(0xFFF6F7F9);
  static const Color surface = Colors.white;
  static const Color surfaceMuted = Color(0xFFF1F5F9);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderStrong = Color(0xFFCBD5E1);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textDisabled = Color(0xFF94A3B8);

  // Semantic
  static const Color success = Color(0xFF15803D);
  static const Color successSoft = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFB45309);
  static const Color warningSoft = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFB91C1C);
  static const Color errorSoft = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoSoft = Color(0xFFDBEAFE);
}
