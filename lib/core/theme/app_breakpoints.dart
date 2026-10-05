import 'package:flutter/widgets.dart';

enum ScreenSize { compact, medium, expanded }

/// The single source of truth for responsive decisions.
abstract final class AppBreakpoints {
  static const double compactMax = 600;
  static const double mediumMax = 1024;

  static ScreenSize of(double width) {
    if (width < compactMax) return ScreenSize.compact;
    if (width < mediumMax) return ScreenSize.medium;
    return ScreenSize.expanded;
  }

  static ScreenSize ofContext(BuildContext context) =>
      of(MediaQuery.sizeOf(context).width);
}

/// Builds different layouts per [ScreenSize] using the available width.
class ResponsiveBuilder extends StatelessWidget {
  const ResponsiveBuilder({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenSize size) builder;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) => builder(context, AppBreakpoints.of(c.maxWidth)),
  );
}
