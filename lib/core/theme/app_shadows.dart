import 'package:flutter/painting.dart';

/// Elevation. ERP screens stay flat: borders do most of the separation, shadows
/// are reserved for floating surfaces (menus, dialogs).
abstract final class AppShadows {
  static const List<BoxShadow> none = [];

  /// Raised form panels (see FormCard): soft, wide, low-contrast.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x140F172A), blurRadius: 14, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0A0F172A), blurRadius: 3, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> floating = [
    BoxShadow(color: Color(0x1A0F172A), blurRadius: 16, offset: Offset(0, 6)),
  ];
}
