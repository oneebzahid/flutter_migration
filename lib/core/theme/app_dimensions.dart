/// Fixed sizes shared across screens (touch targets, shell, tables).
abstract final class AppDimensions {
  // Interaction
  static const double minTapTarget = 44;
  static const double fieldHeight = 48;

  // Shell
  static const double sidebarWidth = 256;
  static const double sidebarCollapsedWidth = 72;
  static const double topBarHeight = 60;
  static const double maxContentWidth = 1440;

  // Tables
  static const double tableHeaderHeight = 44;
  static const double tableRowHeight = 56;
  static const double tableFooterHeight = 48;
  static const double tableScrollbarHeight = 14;
  static const double checkboxColumn = 44;

  // Icons
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
}
