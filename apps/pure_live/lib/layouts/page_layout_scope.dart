import 'package:flutter/widgets.dart';

/// What the shell knows about the room a page gets, so the page and the shell
/// never disagree about it.
///
/// The shell measures the page's usable width once — the content area minus
/// the page's own insets — and publishes the decision here: whether the page's
/// toolbar stacks, and with it whether the page keeps its verbs (refresh, the
/// platform wall, the layout switch) or hands them to the shell's head line.
/// A page reads this instead of measuring the window, which includes a sidebar
/// the page does not have.
final class PageLayoutScope extends InheritedWidget {
  /// Publishes [narrow] to the page below.
  const PageLayoutScope({required this.narrow, required super.child, super.key});

  /// Whether the page's usable width is under the toolbar breakpoint.
  final bool narrow;

  /// Whether the page under [context] keeps a stacked toolbar.
  static bool isNarrow(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PageLayoutScope>()?.narrow ?? false;

  @override
  bool updateShouldNotify(PageLayoutScope oldWidget) => oldWidget.narrow != narrow;
}
