import 'package:flutter/material.dart';
import 'package:pure_live/app/preferences/app_preferences.dart';
import 'package:pure_live/l10n/generated/strings.g.dart';
import 'package:pure_uikit/pure_uikit.dart';

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

  /// The followed streamers' live grid — the reference's first tab, the
  /// favorites (3.x `HomeMenu.favorites`, heart glyph).
  follow(1, Icons.favorite),

  /// The watch history.
  history(2, Icons.history);

  new(this.branchIndex, this.icon);

  /// The position inside the stateful shell — what `goBranch` takes.
  final int branchIndex;

  /// The icon every chrome renders for this branch.
  final IconData icon;

  /// The localized label. The favorites branch carries the reference's
  /// favorites tab label (3.x `favorites_title`).
  String label(BuildContext context) => switch (this) {
    ShellBranch.home => context.t.tabs.home,
    ShellBranch.follow => context.t.tabs.favorites,
    ShellBranch.history => context.t.tabs.history,
  };

  /// The route location this branch's root answers — what the router starts
  /// on when the launch preference names this branch.
  String get location => switch (this) {
    ShellBranch.home => '/',
    ShellBranch.follow => '/follow',
    ShellBranch.history => '/history',
  };

  /// The branch a destination widget's position stands for: the chromes
  /// hand selected indexes over, this turns one back into a branch.
  static ShellBranch at(int index) => values[index];

  /// The branch a shell destination's id stands for, null for an unknown id
  /// (a stored document written by a newer or older build).
  static ShellBranch? maybeFromId(String id) {
    for (final branch in values) {
      if (branch.name == id) {
        return branch;
      }
    }
    return null;
  }

  /// The branch a shell destination's id stands for.
  static ShellBranch fromId(String id) => maybeFromId(id) ?? ShellBranch.home;
}

/// The shell branches the user's page settings keep visible, in the order
/// they arranged them.
///
/// An id the enum does not know is dropped; an empty or unknown document
/// falls back to every branch in table order — a shell with no destination
/// cannot be walked, so this never returns an empty list.
List<ShellBranch> visibleShellBranches(AppPreferences preferences) {
  final seen = <ShellBranch>{};
  final result = <ShellBranch>[];
  for (final id in preferences.shellBranches) {
    final branch = ShellBranch.maybeFromId(id);
    if (branch != null && seen.add(branch)) {
      result.add(branch);
    }
  }
  if (result.isEmpty) {
    result.addAll(ShellBranch.values);
  }
  return result;
}

/// The location the router starts on: the last visited branch when the
/// navigation preference asks for it and that branch is still visible, else
/// the configured launch branch, else the first visible one.
String launchLocationFor(AppPreferences preferences) {
  final visible = visibleShellBranches(preferences);
  if (preferences.restoreLastTab) {
    final last = ShellBranch.maybeFromId(preferences.lastBranchId ?? '');
    if (last != null && visible.contains(last)) {
      return last.location;
    }
  }
  for (final branch in visible) {
    if (branch.name == preferences.launchBranch.id) {
      return branch.location;
    }
  }
  return visible.first.location;
}

/// Every branch as a shell destination, in display order — the one list the
/// dispatched shell renders from, whichever library draws it.
///
/// The id is the branch's own name, so the shell reports a choice as something
/// the router layer can map back without relying on positions surviving a change
/// to the table.
List<PureShellDestination> shellDestinations(BuildContext context, {List<ShellBranch>? branches}) => [
  for (final branch in branches ?? ShellBranch.values)
    PureShellDestination(id: branch.name, label: branch.label(context), icon: branch.icon),
];
