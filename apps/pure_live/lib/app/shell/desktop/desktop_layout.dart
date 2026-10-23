import 'package:flutter/widgets.dart' show EdgeInsets;

/// The desktop layout's measurements, in one place: the rail widths and the
/// paddings the shell and the pages agree on, so a dragged window changes
/// only the numbers here.
abstract final class DesktopLayout {
  /// The expanded rail's width.
  static const double railWidth = 220;

  /// The folded rail's width.
  static const double railFoldedWidth = 64;

  /// The horizontal padding a page keeps inside the shell.
  static const EdgeInsets pagePadding = EdgeInsets.symmetric(horizontal: 20, vertical: 16);
}
