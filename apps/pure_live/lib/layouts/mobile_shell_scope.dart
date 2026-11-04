import 'package:flutter/widgets.dart';

/// Says whether a page is hosted by the phone shell, whose top bar carries the
/// page's verbs (search, refresh, more).
///
/// A hosted page keeps its tabs alone at any width and leaves the verbs to the
/// bar; a desktop window (which this shell never hosts) keeps drawing its own
/// verb row. Deciding by the shell rather than by the page's own toolbar
/// breakpoint is what keeps the two from disagreeing about a width between
/// their thresholds.
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
