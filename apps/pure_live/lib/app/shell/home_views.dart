import 'package:flutter/widgets.dart';
import 'package:pure_live/app/shell/shell_destinations.dart' show ShellBranch;

/// The width from which the shell draws a navigation column instead of the
/// bottom bar — the reference's `homeTabletBreakpoint` (600; the old build
/// switched above 680).
///
/// The decision is width-only, exactly as the reference: a landscape phone
/// crosses onto the column, a narrow desktop window drops to the bottom bar.
/// Which column — the labelled sidebar or the icon rail — is the shell's own
/// decision on top of this one.
const double homeRailBreakpoint = 600;

/// Whether a home of [width] uses the navigation column.
bool isHomeRailWidth(double width) => width >= homeRailBreakpoint;

/// Whether the shell draws the phone chrome at [width]: under the breakpoint
/// always, and above it when a phone-shaped wide screen (a tablet, an unfolded
/// foldable) was told to keep the bottom bar. A desktop keeps its column.
bool usesHomeBottomBar(double width, {required bool bottomBarOnWide, required bool mobile}) =>
    !isHomeRailWidth(width) || (bottomBarOnWide && mobile);

/// Tells the home tabs which layout the shell chose (the reference's
/// `HomeLayoutScope`): a page shows its own menu/search buttons only in the
/// phone layout, because the navigation column already carries them.
class HomeLayoutScope extends InheritedWidget {
  /// Marks [child] as laid out with the bottom bar ([phone]) or the column.
  const new({required this.phone, required super.child, this.activateBranch, super.key});

  /// Whether the bottom bar layout is used.
  final bool phone;

  /// Activates a menu branch the way the shell's own chrome does — the
  /// content pane shows it. Null above the shell, where a caller pushes the
  /// branch's page instead.
  final void Function(ShellBranch branch)? activateBranch;

  /// The scope above [context], or null outside the home shell.
  static HomeLayoutScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeLayoutScope>();

  @override
  bool updateShouldNotify(HomeLayoutScope oldWidget) => oldWidget.phone != phone;
}
