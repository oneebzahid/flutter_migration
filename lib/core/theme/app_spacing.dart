import 'package:flutter/material.dart';

// Layout tokens live in focused files; this barrel keeps one import for screens.
export 'app_dimensions.dart';
export 'app_radius.dart';
export 'app_shadows.dart';

/// Spacing scale (4-pt grid).
abstract final class AppSpacing {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  static const EdgeInsets pagePadding = EdgeInsets.all(lg);
  static const EdgeInsets pagePaddingWide = EdgeInsets.all(xl);
}
