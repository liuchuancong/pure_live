import 'package:flutter/widgets.dart';

/// Says whether a page is hosted by the phone shell, whose top bar carries the
/// page's verbs (search, refresh, more).
///
/// A page hides its own verb row on a narrow window only when the shell really
/// hosts it: the shell appears below the navigation breakpoint, while a page
/// goes narrow earlier (its toolbar stacks). Between the two widths a desktop
/// window still draws the page's own row, and it must keep its verbs.
final class MobileShellScope extends InheritedWidget {
  /// Marks the subtree as hosted (true) by the phone shell.
  const MobileShellScope({required this.hosted, required super.child, super.key});

  /// Whether the phone shell hosts this subtree.
  final bool hosted;

  /// Whether the page under [context] is hosted by the phone shell.
  static bool isHosted(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MobileShellScope>()?.hosted ?? false;

  @override
  bool updateShouldNotify(MobileShellScope oldWidget) => oldWidget.hosted != hosted;
}
