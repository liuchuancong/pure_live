import 'package:flutter/material.dart';

import 'package:pure_live/l10n/generated/strings.g.dart';

/// The shell's branches in one table: the display order, each branch's
/// icon and localized label, and the position `goBranch` addresses.
///
/// The declaration order must stay in lockstep with the branch order of
/// the `@TypedStatefulShellRoute` table in `app_router.dart` — go_router
/// addresses branches by position, and this enum is the single place that
/// position is written beside the destinations the chromes render from it.
enum ShellBranch {
  /// The home feed — the first destination and the launch default.
  home(0, Icons.home_outlined),

  /// The followed streamers' live grid.
  follow(1, Icons.favorite_border),

  /// The watch history.
  history(2, Icons.history);

  new(this.branchIndex, this.icon);

  /// The position inside the stateful shell — what `goBranch` takes.
  final int branchIndex;

  /// The icon every chrome renders for this branch.
  final IconData icon;

  /// The localized label.
  String label(BuildContext context) => switch (this) {
    ShellBranch.home => context.t.tabs.home,
    ShellBranch.follow => context.t.tabs.follow,
    ShellBranch.history => context.t.tabs.history,
  };

  /// The branch a destination widget's position stands for: the chromes
  /// hand selected indexes over, this turns one back into a branch.
  static ShellBranch at(int index) => values[index];
}

/// Every branch as its chrome destination, in display order — the one
/// list the bottom bars and the rails all render from.
List<({String label, IconData icon})> shellDestinations(BuildContext context) =>
    [for (final branch in ShellBranch.values) (label: branch.label(context), icon: branch.icon)];
